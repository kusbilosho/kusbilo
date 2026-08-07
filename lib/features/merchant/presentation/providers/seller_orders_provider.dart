import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/services/live_location_service.dart';
import '../../../order/data/models/order.dart';

/// Orders currently waiting on THIS merchant to accept or reject, plus
/// the orders they've already accepted and are actively fulfilling
/// (confirmed -> outForDelivery -> delivered). A rejected order doesn't
/// just vanish from [pendingOrders]; the respondToOrder Cloud Function
/// reassigns it to the next-nearest seller automatically, so this
/// merchant simply stops seeing it once they've responded.
class SellerOrdersProvider extends ChangeNotifier {
  final _firestore = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instance;

  List<Order> _pendingOrders = [];
  List<Order> _activeOrders = [];
  bool _responding = false;
  bool _updatingStatus = false;

  List<Order> get pendingOrders => _pendingOrders;
  List<Order> get activeOrders => _activeOrders;
  bool get isResponding => _responding;
  bool get isUpdatingStatus => _updatingStatus;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> load() async {
    final uid = _uid;
    if (uid == null) return;

    final pendingSnap = await _firestore
        .collection('orders')
        .where('assignedMerchantId', isEqualTo: uid)
        .where('assignmentStatus', isEqualTo: 'pending_merchant')
        .get();
    _pendingOrders = pendingSnap.docs.map((d) => Order.fromMap(d.id, d.data())).toList();

    final activeSnap = await _firestore
        .collection('orders')
        .where('assignedMerchantId', isEqualTo: uid)
        .where('status', whereIn: ['confirmed', 'outForDelivery'])
        .get();
    _activeOrders = activeSnap.docs.map((d) => Order.fromMap(d.id, d.data())).toList();

    notifyListeners();
  }

  Future<bool> respond(String orderId, {required bool accept}) async {
    _responding = true;
    notifyListeners();
    try {
      await _functions.httpsCallable('respondToOrder').call({'orderId': orderId, 'accept': accept});
      _pendingOrders = _pendingOrders.where((o) => o.id != orderId).toList();
      if (accept) await load(); // pick up the newly-confirmed order into activeOrders
      return true;
    } catch (_) {
      return false;
    } finally {
      _responding = false;
      notifyListeners();
    }
  }

  /// Marks an accepted order as out for delivery and starts broadcasting
  /// this seller's live GPS position on that order document.
  Future<bool> startDelivery(String orderId) async {
    _updatingStatus = true;
    notifyListeners();
    try {
      await _firestore.collection('orders').doc(orderId).update({'status': 'outForDelivery'});
      await LiveLocationService.start(orderId);
      await load();
      return true;
    } catch (_) {
      return false;
    } finally {
      _updatingStatus = false;
      notifyListeners();
    }
  }

  /// Marks an order delivered and stops the live-location broadcast.
  Future<bool> markDelivered(String orderId) async {
    _updatingStatus = true;
    notifyListeners();
    try {
      await LiveLocationService.stop(clearLastPoint: true);
      await _firestore.collection('orders').doc(orderId).update({'status': 'delivered'});
      _activeOrders = _activeOrders.where((o) => o.id != orderId).toList();
      return true;
    } catch (_) {
      return false;
    } finally {
      _updatingStatus = false;
      notifyListeners();
    }
  }
}
