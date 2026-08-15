/// A single buyer's rating (+ optional comment) for one product, stored
/// at `products/{productId}/reviews/{buyerId}` — keyed by buyer so a
/// second rating from the same person overwrites their first instead of
/// piling up duplicates, and so "have I already rated this?" is a single
/// document read rather than a query.
class Review {
  final String buyerId;
  final String buyerName;
  final int rating; // 1–5
  final String comment;
  final DateTime createdAt;

  const Review({
    required this.buyerId,
    required this.buyerName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'buyerId': buyerId,
        'buyerName': buyerName,
        'rating': rating,
        'comment': comment,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Review.fromMap(Map<String, dynamic> map) => Review(
        buyerId: map['buyerId'] as String,
        buyerName: map['buyerName'] as String? ?? '',
        rating: (map['rating'] as num).toInt(),
        comment: map['comment'] as String? ?? '',
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}
