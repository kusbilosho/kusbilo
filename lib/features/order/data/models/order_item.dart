/// A single product line inside an [Order]. We snapshot the name/price
/// (and photo) at the time of ordering — instead of just storing a
/// productId — so that if the product's price or photo changes later,
/// old orders still show exactly what the customer actually ordered.
class OrderItem {
  final String productId;
  final String nameHi;
  final String nameEn;
  final int priceValue;
  final String unit;
  final int quantity;
  final String? imageUrl;

  const OrderItem({
    required this.productId,
    required this.nameHi,
    required this.nameEn,
    required this.priceValue,
    required this.unit,
    required this.quantity,
    this.imageUrl,
  });

  int get lineTotal => priceValue * quantity;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'nameHi': nameHi,
        'nameEn': nameEn,
        'priceValue': priceValue,
        'unit': unit,
        'quantity': quantity,
        'imageUrl': imageUrl,
      };

  factory OrderItem.fromMap(Map<String, dynamic> map) => OrderItem(
        productId: map['productId'] as String? ?? '',
        nameHi: map['nameHi'] as String? ?? '',
        nameEn: map['nameEn'] as String? ?? '',
        priceValue: (map['priceValue'] as num?)?.toInt() ?? 0,
        unit: map['unit'] as String? ?? '',
        quantity: (map['quantity'] as num?)?.toInt() ?? 1,
        imageUrl: map['imageUrl'] as String?,
      );
}
