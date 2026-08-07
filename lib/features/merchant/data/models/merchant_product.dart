/// A product listed by a merchant in their own store. Kept separate from
/// the public-catalog `Product` model (features/home) since a merchant's
/// draft/unpublished listings, stock, and status are seller-only concerns
/// — this model can later map onto whatever the "publish to catalog" step
/// needs, without the buyer-facing Product model having to know about it.
class MerchantProduct {
  final String id;
  final String categoryId;
  final String name;
  final String emoji;
  final int priceValue;
  final String unit;
  final int stock;
  final bool isActive;

  const MerchantProduct({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.emoji,
    required this.priceValue,
    required this.unit,
    required this.stock,
    this.isActive = true,
  });

  String get priceDisplay => '₹$priceValue$unit';
}
