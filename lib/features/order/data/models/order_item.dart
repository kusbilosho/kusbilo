/// A single product line inside an [Order]. We snapshot the name/price
/// at the time of ordering (instead of just storing a productId) so that
/// if the product's price changes later, old orders still show what the
/// customer actually paid.
class OrderItem {
  final String productId;
  final String nameHi;
  final String nameEn;
  final int priceValue;
  final String unit;
  final int quantity;

  const OrderItem({
    required this.productId,
    required this.nameHi,
    required this.nameEn,
    required this.priceValue,
    required this.unit,
    required this.quantity,
  });

  int get lineTotal => priceValue * quantity;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'nameHi': nameHi,
        'nameEn': nameEn,
        'priceValue': priceValue,
        'unit': unit,
        'quantity': quantity,
      };

  factory OrderItem.fromMap(Map<String, dynamic> map) => OrderItem(
        productId: map['productId'] as String,
        nameHi: map['nameHi'] as String,
        nameEn: map['nameEn'] as String,
        priceValue: (map['priceValue'] as num).toInt(),
        unit: map['unit'] as String,
        quantity: (map['quantity'] as num).toInt(),
      );
}
