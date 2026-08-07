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
  final String? imageUrl;
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
    this.imageUrl,
    this.stock = 0,
    this.isActive = true,
  });

  String name(AppLanguage language) => language == AppLanguage.hindi ? nameHi : nameEn;

  String get priceDisplay => '₹$priceValue$unit';

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
        'imageUrl': imageUrl,
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
        imageUrl: map['imageUrl'] as String?,
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
    String? imageUrl,
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
        imageUrl: imageUrl ?? this.imageUrl,
        stock: stock ?? this.stock,
        isActive: isActive ?? this.isActive,
      );
}
