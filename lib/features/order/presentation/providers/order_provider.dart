import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/order.dart';
import '../../data/models/order_item.dart';

/// Places orders and loads order history. Placing an order now goes
/// through the `placeOrder` Cloud Function instead of a direct
/// Firestore write — that's what lets a single call also (a) find the
/// nearest merchant selling these products, (b) compute an ETA, and (c)
/// push a notification to that merchant, all before the buyer's app
/// even sees a response. See functions/index.js.
class OrderProvider extends ChangeNotifier {
  final _firestore = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instance;

  List<Order> _myOrders = [];
  bool _loaded = false;
  bool _placing = false;
  String? _errorMessage;

  List<Order> get myOrders => _myOrders;
  bool get isPlacing => _placing;
  // Only true before the first successful load — used by the order
  // history screen to show a shimmer skeleton instead of briefly
  // flashing the "no orders" empty state while the real list is
  // still on its way from Firestore.
  bool get isLoading => !_loaded && _errorMessage == null;
  String? get errorMessage => _errorMessage;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> load({bool forceRefresh = false}) async {
    if (_loaded && !forceRefresh) return;
    final uid = _uid;
    if (uid == null) return;

    _errorMessage = null;
    notifyListeners();

    try {
      final snap = await _firestore
          .collection('orders')
          .where('buyerId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get()
          .timeout(const Duration(seconds: 12));

      _myOrders = snap.docs.map((d) => Order.fromMap(d.id, d.data())).toList();
      _loaded = true;
    } on TimeoutException catch (_) {
      // Without this, a stalled request left `_loaded` false forever with
      // no exception ever thrown — the screen would show its loading
      // skeleton indefinitely with no way to recover or retry.
      _errorMessage = 'Connection is taking too long. Please check your internet and try again.';
    } catch (e) {
      // Previously any Firestore error here (permission issue, missing
      // composite index, etc.) went uncaught: `_loaded` stayed false
      // forever and the screen was stuck on its loading skeleton with no
      // error shown and no way to retry.
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  /// Places a new order via the `placeOrder` Cloud Function. Returns the
  /// created [Order] (with merchant assignment + ETA already filled in
  /// by the server), or null if the call failed for any reason — the
  /// caller decides what to tell the user in that case.
  Future<Order?> placeOrder({
    required List<OrderItem> items,
    double? deliveryLat,
    double? deliveryLng,
    String? deliveryAddressLabel,
    String paymentMethod = 'cod',
    String? paymentStatus,
    String? gatewayOrderId,
  }) async {
    if (_uid == null || items.isEmpty) return null;

    _placing = true;
    notifyListeners();

    try {
      final result = await _functions.httpsCallable('placeOrder').call({
        'items': items.map((i) => i.toMap()).toList(),
        'deliveryLat': deliveryLat,
        'deliveryLng': deliveryLng,
        'deliveryAddressLabel': deliveryAddressLabel,
        'paymentMethod': paymentMethod,
        'paymentStatus': paymentStatus,
        'gatewayOrderId': gatewayOrderId,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      final orderId = data['orderId'] as String;
      final order = Order.fromMap(orderId, Map<String, dynamic>.from(data['order'] as Map));

      // Best-effort: the placeOrder Cloud Function may or may not already
      // persist paymentMethod/paymentStatus itself (we don't control that
      // code from the app). Writing it here too means payment info shows
      // up in order history either way. Non-fatal if the security rules
      // don't allow a buyer to touch their own order doc after creation —
      // the order itself is already placed successfully at this point.
      if (paymentMethod != 'cod' || paymentStatus != null) {
        try {
          await _firestore.collection('orders').doc(orderId).update({
            'paymentMethod': paymentMethod,
            if (paymentStatus != null) 'paymentStatus': paymentStatus,
            if (gatewayOrderId != null) 'gatewayOrderId': gatewayOrderId,
          });
        } catch (_) {}
      }

      _myOrders = [order, ..._myOrders];
      notifyListeners();
      return order;
    } catch (_) {
      return null;
    } finally {
      _placing = false;
      notifyListeners();
    }
  }

  /// Cancels an order the buyer placed. A direct Firestore write, not a
  /// Cloud Function call — there's no `cancelOrder` function in
  /// functions/index.js to call (only `placeOrder` was visible when this
  /// was written). This means it needs a Firestore rule that lets a
  /// signed-in buyer set their OWN order's status to 'cancelled', e.g.:
  ///
  ///   allow update: if request.auth.uid == resource.data.buyerId
  ///     && request.resource.data.status == 'cancelled'
  ///     && resource.data.status in ['placed', 'confirmed'];
  ///
  /// The UI already only offers this while status is placed/confirmed
  /// (see order_tracking_screen.dart), but the rule should enforce that
  /// server-side too rather than trusting the client.
  Future<bool> cancelOrder(String orderId) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({'status': 'cancelled'});
      final index = _myOrders.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        _myOrders = List.of(_myOrders)..[index] = _myOrders[index].copyWith(status: OrderStatus.cancelled);
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('[OrderProvider] cancelOrder failed: $e');
      return false;
    }
  }

  void resetSession() {
    _myOrders = [];
    _loaded = false;
    _errorMessage = null;
    notifyListeners();
  }
}
