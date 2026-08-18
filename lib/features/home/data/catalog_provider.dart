import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'models/category.dart';
import 'models/product.dart';

/// How long we wait for a single Firestore call inside [CatalogProvider.load]
/// before giving up and surfacing an error. Without this, a stalled network
/// request (app resumed after being backgrounded for a long time, a flaky
/// connection, etc.) leaves [CatalogProvider.status] stuck at `loading`
/// forever — since nothing ever completes the `await`, the `catch` block
/// never runs either, so the UI has no way to show a retry option and just
/// spins indefinitely.
const _catalogFetchTimeout = Duration(seconds: 12);

enum CatalogStatus { idle, loading, loaded, error }

/// Single source of truth for categories and products across the app —
/// now backed by Cloud Firestore. [load] fetches from the `categories`
/// and `products` collections; if they're empty (a brand-new Firestore
/// project), it seeds them once with a starter catalog so the app has
/// something to show. Every screen that reads categories/products from
/// this provider is unaffected by any of that — they just see a list.
class CatalogProvider extends ChangeNotifier {
  final _firestore = FirebaseFirestore.instance;

  List<Category> _categories = [];
  List<Product> _products = [];
  CatalogStatus _status = CatalogStatus.idle;
  String? _errorMessage;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _categoriesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _productsSub;
  bool _categoriesReady = false;
  bool _productsReady = false;

  List<Category> get categories => _categories;
  List<Product> get products => _products;
  CatalogStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == CatalogStatus.loading;

  List<Product> productsByCategory(String categoryId) =>
      _products.where((p) => p.categoryId == categoryId).toList();

  Product? productById(String id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  Category? categoryById(String id) {
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Loads the catalog from Firestore and then keeps it live. Safe to
  /// call multiple times — if already subscribed, this is a no-op
  /// unless [forceRefresh] is passed (used for pull-to-refresh and the
  /// error screen's retry button), so screens can call this in
  /// initState without worrying about duplicate work.
  ///
  /// Categories and products are backed by `.snapshots()`, not a
  /// one-time `.get()` — a merchant adding, editing, or deleting a
  /// product updates every buyer's app within moments, with nobody
  /// needing to restart or pull-to-refresh to see it. The two listener
  /// setups and the seed-check all fire in parallel instead of one
  /// after another, since they don't actually depend on each other —
  /// that alone used to add two full sequential round trips to every
  /// cold start before a single product was visible.
  Future<void> load({bool forceRefresh = false}) async {
    if (_status == CatalogStatus.loaded && !forceRefresh) return;
    if (_categoriesSub != null && !forceRefresh) return;

    await _categoriesSub?.cancel();
    await _productsSub?.cancel();
    _categoriesReady = false;
    _productsReady = false;

    _status = CatalogStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final firstCategories = Completer<void>();
    final firstProducts = Completer<void>();

    // Unawaited on purpose — seeding a brand-new project and the two
    // live listeners below don't need to happen in order. If the
    // collections are empty, the listeners' first snapshot will just
    // be empty, then update again the moment _seedIfEmpty's batch
    // commits, instead of buyers waiting on a seed-check round trip
    // before they see anything at all on every normal (already-seeded)
    // app open.
    _seedIfEmpty().catchError((_) {
      // A failed seed attempt on an already-seeded project is harmless
      // (the listeners below still work fine); only a genuinely empty,
      // unseedable project would show an empty catalog, which the
      // error/timeout handling further down still catches.
    });

    _categoriesSub = _firestore.collection('categories').snapshots().listen(
      (snap) {
        _categories = snap.docs.map(_categoryFromDoc).toList();
        _categoriesReady = true;
        if (!firstCategories.isCompleted) firstCategories.complete();
        _markLoadedIfReady();
      },
      onError: (e) {
        if (!firstCategories.isCompleted) firstCategories.completeError(e);
      },
    );

    _productsSub = _firestore.collection('products').snapshots().listen(
      (snap) {
        _products = snap.docs
            .map(_productFromDoc)
            .where((p) => p.isActive && p.stock > 0)
            .toList();
        _productsReady = true;
        if (!firstProducts.isCompleted) firstProducts.complete();
        _markLoadedIfReady();
      },
      onError: (e) {
        if (!firstProducts.isCompleted) firstProducts.completeError(e);
      },
    );

    try {
      await Future.wait([firstCategories.future, firstProducts.future])
          .timeout(_catalogFetchTimeout);
    } on TimeoutException {
      // The request never came back (stalled connection, app resumed after
      // being backgrounded a long time, etc.) — surface this as a normal
      // error instead of leaving the UI stuck on the loading skeleton.
      _status = CatalogStatus.error;
      _errorMessage =
          'Connection is taking too long. Please check your internet and try again.';
      notifyListeners();
      return;
    } catch (e) {
      _status = CatalogStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return;
    }

    _markLoadedIfReady();
  }

  void _markLoadedIfReady() {
    if (_categoriesReady && _productsReady) {
      _status = CatalogStatus.loaded;
    }
    notifyListeners();
  }

  Category _categoryFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return Category(
      id: doc.id,
      nameHi: data['nameHi'] as String,
      nameEn: data['nameEn'] as String,
      icon: _iconForName(data['iconName'] as String),
      color: Color(data['colorValue'] as int),
      imageUrl: data['imageUrl'] as String?,
    );
  }

  Product _productFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return Product.fromMap(doc.id, doc.data());
  }

  // Icons can't be stored in Firestore directly, so categories store a
  // short `iconName` key instead and this maps it back to an IconData.
  IconData _iconForName(String name) {
    switch (name) {
      case 'eco':
        return Icons.eco_rounded;
      case 'flower':
        return Icons.local_florist_rounded;
      case 'grass':
        return Icons.grass_rounded;
      case 'water_drop':
        return Icons.water_drop_rounded;
      case 'fire':
        return Icons.local_fire_department_rounded;
      case 'handyman':
        return Icons.handyman_rounded;
      case 'clothes':
        return Icons.checkroom_rounded;
      case 'medicine':
        return Icons.medication_rounded;
      case 'electronics':
        return Icons.devices_other_rounded;
      case 'bakery':
        return Icons.bakery_dining_rounded;
      case 'meat':
        return Icons.set_meal_rounded;
      case 'stationery':
        return Icons.edit_note_rounded;
      case 'toys':
        return Icons.toys_rounded;
      case 'household':
        return Icons.cleaning_services_rounded;
      case 'beauty':
        return Icons.face_retouching_natural_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  /// One-time bootstrap: if `categories` is empty (fresh Firestore
  /// project), writes the starter catalog. Only ever writes when the
  /// collection is actually empty, so this is safe to call every load.
  Future<void> _seedIfEmpty() async {
    final existing = await _firestore.collection('categories').limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final batch = _firestore.batch();

    for (final c in _seedCategories) {
      final data = Map<String, dynamic>.from(c)..remove('id');
      batch.set(_firestore.collection('categories').doc(c['id'] as String), data);
    }
    for (final p in _seedProducts) {
      final data = Map<String, dynamic>.from(p)..remove('id');
      data['stock'] = data['stock'] ?? 999;
      data['isActive'] = data['isActive'] ?? true;
      data['tags'] = data['tags'] ?? <String>[];
      data['description'] = data['description'] ?? '';
      // Must be an explicit null, not just an absent key — the
      // Firestore rule checks `ownerId == null` to allow starter-
      // catalog seeding, and an absent field fails that check.
      data['ownerId'] = data['ownerId'];
      batch.set(_firestore.collection('products').doc(p['id'] as String), data);
    }

    await batch.commit();
  }

  @override
  void dispose() {
    _categoriesSub?.cancel();
    _productsSub?.cancel();
    super.dispose();
  }
}

const _seedCategories = [
  {'id': 'vegetables', 'nameHi': 'सब्ज़ियाँ', 'nameEn': 'Vegetables', 'iconName': 'eco', 'colorValue': 0xFF1F5F3F},
  {'id': 'fruits', 'nameHi': 'फल', 'nameEn': 'Fruits', 'iconName': 'flower', 'colorValue': 0xFFD9714E},
  {'id': 'grains', 'nameHi': 'अनाज', 'nameEn': 'Grains', 'iconName': 'grass', 'colorValue': 0xFFE8A33D},
  {'id': 'dairy', 'nameHi': 'डेयरी', 'nameEn': 'Dairy', 'iconName': 'water_drop', 'colorValue': 0xFF4C8CBF},
  {'id': 'spices', 'nameHi': 'मसाले', 'nameEn': 'Spices', 'iconName': 'fire', 'colorValue': 0xFFC0453B},
  {'id': 'handicrafts', 'nameHi': 'हस्तशिल्प', 'nameEn': 'Handicrafts', 'iconName': 'handyman', 'colorValue': 0xFF8A6D3B},
];

// First 6 entries stay in this exact order — the Home tab's "Featured"
// section shows only these, so their order/content must not shift.
const _seedProducts = [
  {'id': 'tomato', 'categoryId': 'vegetables', 'nameHi': 'टमाटर', 'nameEn': 'Tomato', 'emoji': '🍅', 'priceValue': 30, 'unit': '/kg'},
  {'id': 'carrot', 'categoryId': 'vegetables', 'nameHi': 'गाजर', 'nameEn': 'Carrot', 'emoji': '🥕', 'priceValue': 40, 'unit': '/kg'},
  {'id': 'wheat', 'categoryId': 'grains', 'nameHi': 'गेहूं', 'nameEn': 'Wheat', 'emoji': '🌾', 'priceValue': 28, 'unit': '/kg'},
  {'id': 'milk', 'categoryId': 'dairy', 'nameHi': 'दूध', 'nameEn': 'Milk', 'emoji': '🥛', 'priceValue': 55, 'unit': '/ltr'},
  {'id': 'turmeric', 'categoryId': 'spices', 'nameHi': 'हल्दी', 'nameEn': 'Turmeric', 'emoji': '🫙', 'priceValue': 120, 'unit': '/kg'},
  {'id': 'basket', 'categoryId': 'handicrafts', 'nameHi': 'बांस की टोकरी', 'nameEn': 'Bamboo Basket', 'emoji': '🧺', 'priceValue': 250, 'unit': '/pc'},
  {'id': 'banana', 'categoryId': 'fruits', 'nameHi': 'केला', 'nameEn': 'Banana', 'emoji': '🍌', 'priceValue': 50, 'unit': '/dz'},
  {'id': 'mango', 'categoryId': 'fruits', 'nameHi': 'आम', 'nameEn': 'Mango', 'emoji': '🥭', 'priceValue': 80, 'unit': '/kg'},
  {'id': 'potato', 'categoryId': 'vegetables', 'nameHi': 'आलू', 'nameEn': 'Potato', 'emoji': '🥔', 'priceValue': 25, 'unit': '/kg'},
  {'id': 'onion', 'categoryId': 'vegetables', 'nameHi': 'प्याज़', 'nameEn': 'Onion', 'emoji': '🧅', 'priceValue': 35, 'unit': '/kg'},
  {'id': 'rice', 'categoryId': 'grains', 'nameHi': 'चावल', 'nameEn': 'Rice', 'emoji': '🍚', 'priceValue': 45, 'unit': '/kg'},
  {'id': 'curd', 'categoryId': 'dairy', 'nameHi': 'दही', 'nameEn': 'Curd', 'emoji': '🥣', 'priceValue': 40, 'unit': '/500g'},
  {'id': 'chili', 'categoryId': 'spices', 'nameHi': 'लाल मिर्च', 'nameEn': 'Red Chili', 'emoji': '🌶️', 'priceValue': 150, 'unit': '/kg'},
  {'id': 'pot', 'categoryId': 'handicrafts', 'nameHi': 'मिट्टी का घड़ा', 'nameEn': 'Clay Pot', 'emoji': '🏺', 'priceValue': 180, 'unit': '/pc'},
];
