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

  List<Order> get myOrders => _myOrders;
  bool get isPlacing => _placing;
  // Only true before the first successful load — used by the order
  // history screen to show a shimmer skeleton instead of briefly
  // flashing the "no orders" empty state while the real list is
  // still on its way from Firestore.
  bool get isLoading => !_loaded;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> load({bool forceRefresh = false}) async {
    if (_loaded && !forceRefresh) return;
    final uid = _uid;
    if (uid == null) return;

    final snap = await _firestore
        .collection('orders')
        .where('buyerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();

    _myOrders = snap.docs.map((d) => Order.fromMap(d.id, d.data())).toList();
    _loaded = true;
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
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      final order = Order.fromMap(data['orderId'] as String, Map<String, dynamic>.from(data['order'] as Map));
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

  void resetSession() {
    _myOrders = [];
    _loaded = false;
    notifyListeners();
  }
}
