import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/services/notification_service.dart';
import '../../data/models/kyc_application.dart';

enum KycStatus { notApplied, pending, approved, rejected }

/// Tracks a user's merchant-onboarding state, backed by the
/// `merchants/{uid}` Firestore document — one doc per user, keyed by
/// their Firebase Auth uid. [load] pulls in whatever's already there
/// (so status survives app restarts and works across devices);
/// [submitKyc] writes a new application.
class MerchantProvider extends ChangeNotifier {
  final _firestore = FirebaseFirestore.instance;

  KycStatus _status = KycStatus.notApplied;
  KycApplication? _application;
  bool _loaded = false;

  KycStatus get status => _status;
  KycApplication? get application => _application;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Loads this user's existing KYC doc, if any. Safe to call multiple
  /// times — only fetches once per session unless [forceRefresh] is set.
  Future<void> load({bool forceRefresh = false}) async {
    if (_loaded && !forceRefresh) return;
    final uid = _uid;
    if (uid == null) return;

    final doc = await _firestore.collection('merchants').doc(uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      _application = KycApplication(
        shopName: data['shopName'] as String,
        ownerName: data['ownerName'] as String,
        aadhaarNumber: data['aadhaarNumber'] as String,
        panNumber: data['panNumber'] as String?,
        address: data['address'] as String,
        village: data['village'] as String,
        district: data['district'] as String,
        state: data['state'] as String,
        pincode: data['pincode'] as String,
        bankAccountNumber: data['bankAccountNumber'] as String,
        ifscCode: data['ifscCode'] as String,
        shopLat: (data['shopLat'] as num?)?.toDouble() ?? 0,
        shopLng: (data['shopLng'] as num?)?.toDouble() ?? 0,
        description: data['description'] as String?,
        prepMinutes: (data['prepMinutes'] as num?)?.toInt(),
      );
      _status = _statusFromString(data['status'] as String?);
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> submitKyc(KycApplication application) async {
    final uid = _uid;
    if (uid == null) return;

    _application = application;
    _status = KycStatus.pending;
    notifyListeners();

    await _firestore.collection('merchants').doc(uid).set({
      'shopName': application.shopName,
      'ownerName': application.ownerName,
      'aadhaarNumber': application.aadhaarNumber,
      'panNumber': application.panNumber,
      'address': application.address,
      'village': application.village,
      'district': application.district,
      'state': application.state,
      'pincode': application.pincode,
      'bankAccountNumber': application.bankAccountNumber,
      'ifscCode': application.ifscCode,
      'shopLat': application.shopLat,
      'shopLng': application.shopLng,
      'status': 'pending',
      'submittedAt': FieldValue.serverTimestamp(),
    });
    // A device token registered now means the very first order (right
    // after approval) can already reach this merchant — no separate
    // "enable notifications" step for the seller to remember.
    await NotificationService.registerMerchantDevice();
    // Status starts as "pending" and can only move to approved/rejected
    // via the reviewKycApplication Cloud Function (see functions/index.js
    // and AdminProvider) — Firestore rules block the client from setting
    // it directly.
  }

  /// Lets an approved seller update their shop name, description, and
  /// prep time — the only fields Firestore rules allow a client to
  /// change on an already-approved merchant doc. KYC fields (Aadhaar,
  /// bank details, etc.) are locked after approval and can't be edited
  /// here — that's by design, not an oversight.
  Future<bool> updateStoreSettings({
    required String shopName,
    required String description,
    required int prepMinutes,
  }) async {
    final uid = _uid;
    if (uid == null) return false;

    try {
      await _firestore.collection('merchants').doc(uid).update({
        'shopName': shopName,
        'description': description,
        'prepMinutes': prepMinutes,
      });
      if (_application != null) {
        _application = _application!.copyWith(
          shopName: shopName,
          description: description,
          prepMinutes: prepMinutes,
        );
      }
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Lets a rejected applicant try again.
  Future<void> resetToNotApplied() async {
    _status = KycStatus.notApplied;
    _application = null;
    notifyListeners();

    final uid = _uid;
    if (uid != null) {
      await _firestore.collection('merchants').doc(uid).update({'status': 'notApplied'});
    }
  }

  /// Status changes from here on (pending -> approved/rejected) happen
  /// server-side, via the `reviewKycApplication` Cloud Function — see
  /// AdminProvider. This provider only ever reads that result back.

  KycStatus _statusFromString(String? s) {
    switch (s) {
      case 'pending':
        return KycStatus.pending;
      case 'approved':
        return KycStatus.approved;
      case 'rejected':
        return KycStatus.rejected;
      default:
        return KycStatus.notApplied;
    }
  }
}
