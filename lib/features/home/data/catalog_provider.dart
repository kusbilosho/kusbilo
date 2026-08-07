import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'models/category.dart';
import 'models/product.dart';

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

  /// Loads the catalog from Firestore. Safe to call multiple times —
  /// only refetches if not already loaded, so screens can call this in
  /// initState without worrying about duplicate work.
  Future<void> load({bool forceRefresh = false}) async {
    if (_status == CatalogStatus.loaded && !forceRefresh) return;

    _status = CatalogStatus.loading;
    notifyListeners();

    try {
      await _seedIfEmpty();

      final categorySnap = await _firestore.collection('categories').get();
      _categories = categorySnap.docs.map(_categoryFromDoc).toList();

      final productSnap = await _firestore.collection('products').get();
      _products = productSnap.docs
          .map(_productFromDoc)
          .where((p) => p.isActive && p.stock > 0)
          .toList();

      _status = CatalogStatus.loaded;
    } catch (e) {
      _status = CatalogStatus.error;
      _errorMessage = e.toString();
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
