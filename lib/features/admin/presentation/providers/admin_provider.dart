import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// A pending seller application, shown to an admin for review.
class PendingKycApplication {
  final String uid;
  final String shopName;
  final String ownerName;
  final String village;
  final String district;

  const PendingKycApplication({
    required this.uid,
    required this.shopName,
    required this.ownerName,
    required this.village,
    required this.district,
  });

  factory PendingKycApplication.fromDoc(String uid, Map<String, dynamic> data) =>
      PendingKycApplication(
        uid: uid,
        shopName: data['shopName'] as String? ?? '',
        ownerName: data['ownerName'] as String? ?? '',
        village: data['village'] as String? ?? '',
        district: data['district'] as String? ?? '',
      );
}

/// Backs the (admin-only) KYC review screen. Whether the current user
/// is actually an admin is decided entirely server-side — this class
/// just asks the `checkIsAdmin` Cloud Function and trusts its answer,
/// since the custom claim it reads can't be forged by the client.
class AdminProvider extends ChangeNotifier {
  final _firestore = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instance;

  bool? _isAdmin; // null = not checked yet
  List<PendingKycApplication> _pending = [];
  bool _busy = false;

  bool? get isAdmin => _isAdmin;
  List<PendingKycApplication> get pending => _pending;
  bool get isBusy => _busy;

  /// Checks the admin claim once per session. Call this before showing
  /// any admin entry point in the UI (e.g. the Profile menu row), not
  /// just before the review screen, so non-admins never even see the
  /// option.
  Future<bool> checkIsAdmin() async {
    if (FirebaseAuth.instance.currentUser == null) {
      _isAdmin = false;
      return false;
    }
    if (_isAdmin != null) return _isAdmin!;

    try {
      final result = await _functions.httpsCallable('checkIsAdmin').call();
      _isAdmin = result.data['isAdmin'] == true;
    } catch (_) {
      _isAdmin = false;
    }
    notifyListeners();
    return _isAdmin!;
  }

  Future<void> loadPending() async {
    final snap =
        await _firestore.collection('merchants').where('status', isEqualTo: 'pending').get();
    _pending = snap.docs.map((d) => PendingKycApplication.fromDoc(d.id, d.data())).toList();
    notifyListeners();
  }

  /// Approves or rejects an application via the Cloud Function — never
  /// writes `status` to Firestore directly, since the security rules
  /// block that from the client on purpose (see firestore.rules).
  Future<bool> review(String applicantUid, {required bool approve}) async {
    _busy = true;
    notifyListeners();
    try {
      await _functions.httpsCallable('reviewKycApplication').call({
        'applicantUid': applicantUid,
        'decision': approve ? 'approved' : 'rejected',
      });
      _pending = _pending.where((p) => p.uid != applicantUid).toList();
      return true;
    } catch (_) {
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
