import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../home/data/models/product.dart';

/// Holds the current seller's own listings. These live in the SAME
/// `products` collection buyers read from (via CatalogProvider) — the
/// only difference is `ownerId` matches this seller's uid. That's what
/// makes a listing show up in the buyer catalog and voice search the
/// moment it's saved, instead of sitting invisible in a private
/// subcollection.
class SellerProductsProvider extends ChangeNotifier {
  final _firestore = FirebaseFirestore.instance;

  List<Product> _products = [];
  bool _loaded = false;
  bool _saving = false;

  List<Product> get products => List.unmodifiable(_products);
  int get productCount => _products.length;
  bool get isSaving => _saving;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> load({bool forceRefresh = false}) async {
    if (_loaded && !forceRefresh) return;
    final uid = _uid;
    if (uid == null) return;

    final snap = await _firestore.collection('products').where('ownerId', isEqualTo: uid).get();
    _products = snap.docs.map((d) => Product.fromMap(d.id, d.data())).toList();
    _loaded = true;
    notifyListeners();
  }

  /// [imageUrl] is optional — a listing without a photo still shows the
  /// chosen emoji, since not every seller will have (or want to bother
  /// with) a real product photo for every item.
  Future<void> addProduct({
    required String categoryId,
    required String nameHi,
    required String nameEn,
    required String emoji,
    required int priceValue,
    required String unit,
    required int stock,
    required String description,
    required List<String> tags,
    String? imageUrl,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    final docRef = _firestore.collection('products').doc();
    final product = Product(
      id: docRef.id,
      categoryId: categoryId,
      nameHi: nameHi,
      nameEn: nameEn,
      emoji: emoji,
      priceValue: priceValue,
      unit: unit,
      ownerId: uid,
      description: description,
      tags: tags,
      imageUrl: imageUrl,
      stock: stock,
      isActive: true,
    );

    _products = [..._products, product];
    notifyListeners();

    await docRef.set(product.toMap());
  }

  Future<void> removeProduct(String id) async {
    _products = _products.where((p) => p.id != id).toList();
    notifyListeners();
    await _firestore.collection('products').doc(id).delete();
  }

  Future<void> toggleActive(String id) async {
    final index = _products.indexWhere((p) => p.id == id);
    if (index == -1) return;

    final updated = _products[index].copyWith(isActive: !_products[index].isActive);
    _products = [..._products]..[index] = updated;
    notifyListeners();

    await _firestore.collection('products').doc(id).update({'isActive': updated.isActive});
  }
}
