import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

/// Talks to our own UPI collection server (see the separate
/// upi-payment-gateway repo, deployed on Netlify) — it generates a
/// unique-amount UPI deep link per order and confirms payment once a
/// forwarded bank SMS matches it. The server's base URL is admin-set in
/// Firestore (`settings/paymentGateway.baseUrl`) so it can be changed
/// (e.g. after redeploying) without an app rebuild — same pattern the
/// live-call feature uses for its API key.
enum UpiPaymentResult { success, timedOut, failed, notConfigured }

class UpiPaymentService {
  static const _uuid = Uuid();

  /// How long we poll /api/check-status before giving up and telling the
  /// buyer to retry. The webhook path depends on a phone forwarding a
  /// bank SMS — that's rarely instant, but if it hasn't landed in five
  /// minutes something's actually wrong rather than just slow.
  static const _pollTimeout = Duration(minutes: 5);
  static const _pollInterval = Duration(seconds: 3);

  static Future<String?> _fetchBaseUrl() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('paymentGateway').get();
      final url = doc.data()?['baseUrl'] as String?;
      if (url == null || url.trim().isEmpty) return null;
      return url.trim().endsWith('/') ? url.trim().substring(0, url.trim().length - 1) : url.trim();
    } catch (e) {
      debugPrint('[UPI] Failed to read settings/paymentGateway from Firestore: $e');
      return null;
    }
  }

  /// Starts a UPI payment for [amount] rupees, opens the buyer's UPI app
  /// with the amount pre-filled, then polls until the webhook marks it
  /// paid (or we give up). [gatewayOrderId] is a fresh ID generated
  /// specifically for the payment gateway — deliberately not reusing our
  /// own Firestore order ID, since that doesn't exist yet at this point
  /// (payment happens *before* placeOrder is called, so a failed/
  /// abandoned payment never creates an empty order).
  static Future<({UpiPaymentResult result, String gatewayOrderId})> pay({
    required int amount,
    required String userId,
    String? merchantId,
  }) async {
    final baseUrl = await _fetchBaseUrl();
    if (baseUrl == null) {
      debugPrint('[UPI] No baseUrl configured in settings/paymentGateway — check Gaonadmin Payment tab.');
      return (result: UpiPaymentResult.notConfigured, gatewayOrderId: '');
    }
    debugPrint('[UPI] Using gateway base URL: $baseUrl');

    final gatewayOrderId = 'GH${DateTime.now().millisecondsSinceEpoch}${_uuid.v4().substring(0, 6)}';

    final http.Response initiateResponse;
    try {
      initiateResponse = await http
          .post(
            Uri.parse('$baseUrl/api/initiate-payment'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'orderId': gatewayOrderId,
              'baseAmount': amount,
              'userId': userId,
              'merchantId': merchantId ?? '1',
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('[UPI] initiate-payment request threw: $e');
      return (result: UpiPaymentResult.failed, gatewayOrderId: gatewayOrderId);
    }

    debugPrint('[UPI] initiate-payment -> ${initiateResponse.statusCode}: ${initiateResponse.body}');

    if (initiateResponse.statusCode != 200) {
      return (result: UpiPaymentResult.failed, gatewayOrderId: gatewayOrderId);
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(initiateResponse.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[UPI] Could not parse initiate-payment response as JSON: $e');
      return (result: UpiPaymentResult.failed, gatewayOrderId: gatewayOrderId);
    }

    final upiUrl = data['upiUrl'] as String?;
    if (upiUrl == null) {
      debugPrint('[UPI] Response had no upiUrl field: $data');
      return (result: UpiPaymentResult.failed, gatewayOrderId: gatewayOrderId);
    }

    debugPrint('[UPI] Launching: $upiUrl');
    bool launched;
    try {
      launched = await launchUrl(Uri.parse(upiUrl), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[UPI] launchUrl threw: $e');
      launched = false;
    }
    if (!launched) {
      debugPrint('[UPI] launchUrl returned false — no UPI app could handle this link.');
      return (result: UpiPaymentResult.failed, gatewayOrderId: gatewayOrderId);
    }

    // Poll for the webhook to have matched a forwarded SMS to this order.
    final deadline = DateTime.now().add(_pollTimeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(_pollInterval);
      try {
        final statusResponse = await http
            .get(Uri.parse('$baseUrl/api/check-status/$gatewayOrderId'))
            .timeout(const Duration(seconds: 10));
        debugPrint('[UPI] check-status -> ${statusResponse.statusCode}: ${statusResponse.body}');
        if (statusResponse.statusCode == 200) {
          final statusData = jsonDecode(statusResponse.body) as Map<String, dynamic>;
          if (statusData['status'] == 'SUCCESS') {
            return (result: UpiPaymentResult.success, gatewayOrderId: gatewayOrderId);
          }
        }
      } catch (e) {
        debugPrint('[UPI] check-status poll failed (will retry): $e');
        // A single failed poll (flaky network) shouldn't abandon the
        // whole wait — keep trying until the deadline.
      }
    }
    debugPrint('[UPI] Gave up waiting for payment confirmation after $_pollTimeout.');
    return (result: UpiPaymentResult.timedOut, gatewayOrderId: gatewayOrderId);
  }
}
