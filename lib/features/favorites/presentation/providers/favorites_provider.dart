import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// A buyer's liked products (heart icon on a product card). Stored as
/// one small doc per buyer (`favorites/{uid}` with a `productIds`
/// array) rather than a subcollection — a village buyer's favorites
/// list is small, so one doc read/write is simpler and cheaper than a
/// subcollection would be.
class FavoritesProvider extends ChangeNotifier {
  final _firestore = FirebaseFirestore.instance;

  Set<String> _productIds = {};
  bool _loaded = false;

  Set<String> get productIds => _productIds;
  bool isFavorite(String productId) => _productIds.contains(productId);
  // Only true before the first successful load — used by the wishlist
  // screen to show a shimmer skeleton instead of briefly flashing the
  // "no favorites" empty state while the real list is still loading.
  bool get isLoading => !_loaded;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> load() async {
    if (_loaded) return;
    final uid = _uid;
    if (uid == null) return;

    final doc = await _firestore.collection('favorites').doc(uid).get();
    final ids = (doc.data()?['productIds'] as List<dynamic>? ?? []).map((e) => e.toString());
    _productIds = ids.toSet();
    _loaded = true;
    notifyListeners();
  }

  Future<void> toggle(String productId) async {
    final uid = _uid;
    if (uid == null) return;

    final isFav = _productIds.contains(productId);
    final updated = Set<String>.from(_productIds);
    if (isFav) {
      updated.remove(productId);
    } else {
      updated.add(productId);
    }
    _productIds = updated;
    notifyListeners();

    final docRef = _firestore.collection('favorites').doc(uid);
    await docRef.set({'productIds': _productIds.toList()}, SetOptions(merge: true));
  }

  void resetSession() {
    _productIds = {};
    _loaded = false;
    notifyListeners();
  }
}
