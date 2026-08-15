import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Holds the shopping cart state as productId -> quantity, backed by the
/// `carts/{uid}` Firestore document (one per user, keyed by their
/// Firebase Auth uid) so it survives app restarts and works across
/// devices. [load] pulls in whatever's already there; every mutation
/// updates local state immediately (so the UI never waits on a network
/// round-trip) and then persists the change in the background.
class CartProvider extends ChangeNotifier {
  final _firestore = FirebaseFirestore.instance;

  final Map<String, int> _quantities = {};
  bool _loaded = false;

  Map<String, int> get quantities => Map.unmodifiable(_quantities);

  int quantityOf(String productId) => _quantities[productId] ?? 0;

  int get totalItemCount => _quantities.values.fold(0, (sum, q) => sum + q);

  bool get isEmpty => _quantities.isEmpty;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _doc {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore.collection('carts').doc(uid);
  }

  /// Loads this user's saved cart. Safe to call multiple times — only
  /// fetches once per session unless [forceRefresh] is set.
  Future<void> load({bool forceRefresh = false}) async {
    if (_loaded && !forceRefresh) return;
    final doc = _doc;
    if (doc == null) return;

    final snap = await doc.get();
    _quantities.clear();
    if (snap.exists) {
      final items = snap.data()?['items'] as Map<String, dynamic>? ?? {};
      items.forEach((productId, qty) => _quantities[productId] = (qty as num).toInt());
    }
    _loaded = true;
    notifyListeners();
  }

  /// Adds one unit of the product (used by the "जोड़ें" / Add button).
  void add(String productId) {
    _quantities[productId] = (_quantities[productId] ?? 0) + 1;
    notifyListeners();
    _persist();
  }

  /// Adds [qty] units in one go — used by "reorder from history" so
  /// restoring a past order's line items is a single persisted write
  /// instead of calling [add] in a loop (which would round-trip to
  /// Firestore once per unit).
  void addQuantity(String productId, int qty) {
    if (qty <= 0) return;
    _quantities[productId] = (_quantities[productId] ?? 0) + qty;
    notifyListeners();
    _persist();
  }

  void increment(String productId) {
    _quantities[productId] = (_quantities[productId] ?? 0) + 1;
    notifyListeners();
    _persist();
  }

  /// Decrements the quantity; removes the item entirely once it hits 0.
  void decrement(String productId) {
    final current = _quantities[productId] ?? 0;
    if (current <= 1) {
      _quantities.remove(productId);
    } else {
      _quantities[productId] = current - 1;
    }
    notifyListeners();
    _persist();
  }

  void removeItem(String productId) {
    _quantities.remove(productId);
    notifyListeners();
    _persist();
  }

  void clear() {
    _quantities.clear();
    notifyListeners();
    _persist();
  }

  /// Resets ONLY local/in-memory state — used on logout so the next
  /// login starts fresh and re-fetches from Firestore, without deleting
  /// this user's actually-saved cart. Never call this to empty a cart
  /// the user meant to empty; use [clear] for that.
  void resetSession() {
    _quantities.clear();
    _loaded = false;
    notifyListeners();
  }

  Future<void> _persist() async {
    final doc = _doc;
    if (doc == null) return;
    await doc.set({'items': _quantities});
  }
}
