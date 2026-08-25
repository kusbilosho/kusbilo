import '../../../../core/localization/app_strings.dart';

/// A single sellable item — the SAME model whether it came from the
/// starter catalog (ownerId == null) or a real seller's listing
/// (ownerId == that seller's uid). There used to be a separate
/// MerchantProduct type that lived in a private `merchants/{uid}/products`
/// subcollection buyers never saw; that meant anything a seller added
/// was invisible in the app. Now sellers write directly into the same
/// top-level `products` collection buyers read from (see
/// SellerProductsProvider / CatalogProvider), so a new listing shows up
/// immediately.
class Product {
  final String id;
  final String categoryId;
  final String nameHi;
  final String nameEn;
  final String emoji;
  final int priceValue;
  final String unit;
  final String? ownerId;
  final String description;
  final List<String> tags;
  /// All photos the seller uploaded for this product, in the order
  /// they should appear in the gallery. A seller can add as many as
  /// they want — nothing in this model caps the count.
  final List<String> imageUrls;
  final int stock;
  final bool isActive;

  const Product({
    required this.id,
    required this.categoryId,
    required this.nameHi,
    required this.nameEn,
    required this.emoji,
    required this.priceValue,
    required this.unit,
    this.ownerId,
    this.description = '',
    this.tags = const [],
    this.imageUrls = const [],
    this.stock = 0,
    this.isActive = true,
  });

  String name(AppLanguage language) => language == AppLanguage.hindi ? nameHi : nameEn;

  String get priceDisplay => '₹$priceValue$unit';

  /// Convenience accessor so every screen that only ever needed "the"
  /// product photo (grid cards, similar-products strip) keeps working
  /// unchanged — it's just the first image of the gallery, or null if
  /// the seller hasn't uploaded any yet.
  String? get imageUrl => imageUrls.isNotEmpty ? imageUrls.first : null;

  /// Text a voice/search match should be scored against — name, tags,
  /// and description all count, since a seller's own words ("देसी आलू,
  /// ताज़ा") are exactly what buyers describe products by out loud.
  String get searchableText =>
      [nameHi, nameEn, ...tags, description].join(' ').toLowerCase();

  Map<String, dynamic> toMap() => {
        'categoryId': categoryId,
        'nameHi': nameHi,
        'nameEn': nameEn,
        'emoji': emoji,
        'priceValue': priceValue,
        'unit': unit,
        'ownerId': ownerId,
        'description': description,
        'tags': tags,
        // 'imageUrl' (singular) kept alongside the list purely so any
        // older client/merchant build that still reads only that field
        // doesn't suddenly see a product with no photo.
        'imageUrl': imageUrl,
        'imageUrls': imageUrls,
        'stock': stock,
        'isActive': isActive,
      };

  factory Product.fromMap(String id, Map<String, dynamic> map) => Product(
        id: id,
        categoryId: map['categoryId'] as String,
        nameHi: map['nameHi'] as String,
        nameEn: map['nameEn'] as String,
        emoji: map['emoji'] as String,
        priceValue: (map['priceValue'] as num).toInt(),
        unit: map['unit'] as String,
        ownerId: map['ownerId'] as String?,
        description: map['description'] as String? ?? '',
        tags: (map['tags'] as List<dynamic>? ?? []).map((t) => t.toString()).toList(),
        // Prefer the new 'imageUrls' list; fall back to the old single
        // 'imageUrl' field for products saved before this change so
        // nothing already listed loses its photo.
        imageUrls: (map['imageUrls'] as List<dynamic>?)?.map((u) => u.toString()).toList() ??
            ((map['imageUrl'] as String?)?.isNotEmpty == true ? [map['imageUrl'] as String] : const []),
        stock: (map['stock'] as num?)?.toInt() ?? 0,
        isActive: map['isActive'] as bool? ?? true,
      );

  Product copyWith({
    String? nameHi,
    String? nameEn,
    String? emoji,
    int? priceValue,
    String? unit,
    String? description,
    List<String>? tags,
    List<String>? imageUrls,
    int? stock,
    bool? isActive,
  }) =>
      Product(
        id: id,
        categoryId: categoryId,
        nameHi: nameHi ?? this.nameHi,
        nameEn: nameEn ?? this.nameEn,
        emoji: emoji ?? this.emoji,
        priceValue: priceValue ?? this.priceValue,
        unit: unit ?? this.unit,
        ownerId: ownerId,
        description: description ?? this.description,
        tags: tags ?? this.tags,
        imageUrls: imageUrls ?? this.imageUrls,
        stock: stock ?? this.stock,
        isActive: isActive ?? this.isActive,
      );
}
