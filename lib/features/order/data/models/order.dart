import 'order_item.dart';

/// Lifecycle of an order. Kept deliberately simple — a village-market
/// order mostly just needs to answer "has the seller seen it, and has it
/// arrived yet".
enum OrderStatus { placed, confirmed, outForDelivery, delivered, cancelled }

OrderStatus orderStatusFromString(String? value) {
  switch (value) {
    case 'confirmed':
      return OrderStatus.confirmed;
    case 'outForDelivery':
      return OrderStatus.outForDelivery;
    case 'delivered':
      return OrderStatus.delivered;
    case 'cancelled':
      return OrderStatus.cancelled;
    case 'placed':
    default:
      return OrderStatus.placed;
  }
}

String orderStatusToString(OrderStatus status) => status.name;

/// Whether a merchant has responded to being assigned this order yet.
/// Separate from [OrderStatus] because "placed" already covers the
/// buyer-facing state — this tracks the seller-side handoff, including
/// automatic reassignment if the nearest merchant rejects it.
enum AssignmentStatus { pendingMerchant, confirmed, unassignable }

AssignmentStatus assignmentStatusFromString(String? value) {
  switch (value) {
    case 'confirmed':
      return AssignmentStatus.confirmed;
    case 'unassignable':
      return AssignmentStatus.unassignable;
    case 'pending_merchant':
    default:
      return AssignmentStatus.pendingMerchant;
  }
}

String assignmentStatusToString(AssignmentStatus status) {
  switch (status) {
    case AssignmentStatus.confirmed:
      return 'confirmed';
    case AssignmentStatus.unassignable:
      return 'unassignable';
    case AssignmentStatus.pendingMerchant:
      return 'pending_merchant';
  }
}

/// A placed order, backed by an `orders/{orderId}` Firestore document.
/// Delivery address is stored as plain lat/lng + a human-readable label
/// (village/district) since that's what [LocationService] produces —
/// no separate "address" typing UI is required from the buyer.
///
/// Merchant assignment (which seller fulfills this order) and its ETA
/// are computed server-side by the `placeOrder` Cloud Function — see
/// functions/index.js — using the nearest approved merchant who sells
/// the ordered product(s). If that merchant rejects it, the same
/// function's `respondToOrder` reassigns to the next-nearest one.
class Order {
  final String id;
  final String buyerId;
  final List<OrderItem> items;
  final int totalValue;
  final OrderStatus status;
  final double? deliveryLat;
  final double? deliveryLng;
  final String? deliveryAddressLabel;
  final DateTime createdAt;
  final String? assignedMerchantId;
  final String? assignedMerchantName;
  final AssignmentStatus assignmentStatus;
  final List<String> rejectedMerchantIds;
  final int? etaMinutes;
  final String paymentMethod;
  final String? paymentStatus;
  final String? gatewayOrderId;

  const Order({
    required this.id,
    required this.buyerId,
    required this.items,
    required this.totalValue,
    required this.status,
    required this.createdAt,
    this.deliveryLat,
    this.deliveryLng,
    this.deliveryAddressLabel,
    this.assignedMerchantId,
    this.assignedMerchantName,
    this.assignmentStatus = AssignmentStatus.pendingMerchant,
    this.rejectedMerchantIds = const [],
    this.etaMinutes,
    this.paymentMethod = 'cod',
    this.paymentStatus,
    this.gatewayOrderId,
  });

  Map<String, dynamic> toMap() => {
        'buyerId': buyerId,
        'items': items.map((i) => i.toMap()).toList(),
        'totalValue': totalValue,
        'status': orderStatusToString(status),
        'deliveryLat': deliveryLat,
        'deliveryLng': deliveryLng,
        'deliveryAddressLabel': deliveryAddressLabel,
        'createdAt': createdAt.toIso8601String(),
        'assignedMerchantId': assignedMerchantId,
        'assignedMerchantName': assignedMerchantName,
        'assignmentStatus': assignmentStatusToString(assignmentStatus),
        'rejectedMerchantIds': rejectedMerchantIds,
        'etaMinutes': etaMinutes,
        'paymentMethod': paymentMethod,
        'paymentStatus': paymentStatus,
        'gatewayOrderId': gatewayOrderId,
      };

  factory Order.fromMap(String id, Map<String, dynamic> map) => Order(
        id: id,
        buyerId: map['buyerId'] as String,
        items: ((map['items'] as List<dynamic>? ?? []))
            .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        totalValue: (map['totalValue'] as num).toInt(),
        status: orderStatusFromString(map['status'] as String?),
        deliveryLat: (map['deliveryLat'] as num?)?.toDouble(),
        deliveryLng: (map['deliveryLng'] as num?)?.toDouble(),
        deliveryAddressLabel: map['deliveryAddressLabel'] as String?,
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
        assignedMerchantId: map['assignedMerchantId'] as String?,
        assignedMerchantName: map['assignedMerchantName'] as String?,
        assignmentStatus: assignmentStatusFromString(map['assignmentStatus'] as String?),
        rejectedMerchantIds:
            (map['rejectedMerchantIds'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
        etaMinutes: (map['etaMinutes'] as num?)?.toInt(),
        paymentMethod: map['paymentMethod'] as String? ?? 'cod',
        paymentStatus: map['paymentStatus'] as String?,
        gatewayOrderId: map['gatewayOrderId'] as String?,
      );

  Order copyWith({OrderStatus? status}) => Order(
        id: id,
        buyerId: buyerId,
        items: items,
        totalValue: totalValue,
        status: status ?? this.status,
        createdAt: createdAt,
        deliveryLat: deliveryLat,
        deliveryLng: deliveryLng,
        deliveryAddressLabel: deliveryAddressLabel,
        assignedMerchantId: assignedMerchantId,
        assignedMerchantName: assignedMerchantName,
        assignmentStatus: assignmentStatus,
        rejectedMerchantIds: rejectedMerchantIds,
        etaMinutes: etaMinutes,
        paymentMethod: paymentMethod,
        paymentStatus: paymentStatus,
        gatewayOrderId: gatewayOrderId,
      );
}
