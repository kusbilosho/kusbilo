import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../data/models/order.dart';
import '../providers/order_provider.dart';
import 'order_tracking_screen.dart';

/// Reached from Profile → "मेरे ऑर्डर". Loads once on mount; pull down
/// to refresh picks up status changes a seller made in the meantime
/// (e.g. placed → confirmed).
class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  OrderProvider? _orderProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().load();
    });
  }

  // Same belt-and-suspenders fix as Home: subscribe directly with
  // addListener()/setState() instead of relying only on context.watch,
  // so this screen is guaranteed to refresh the moment OrderProvider's
  // data changes, regardless of any InheritedWidget propagation timing.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<OrderProvider>();
    if (!identical(_orderProvider, provider)) {
      _orderProvider?.removeListener(_onOrdersChanged);
      _orderProvider = provider;
      _orderProvider!.addListener(_onOrdersChanged);
    }
  }

  void _onOrdersChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _orderProvider?.removeListener(_onOrdersChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleProvider>().strings;
    final orderProvider = context.watch<OrderProvider>();
    final orders = orderProvider.myOrders;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: Text(strings.myOrdersTitle, style: AppTextStyles.display(fontSize: 18)),
        iconTheme: const IconThemeData(color: AppColors.charcoal),
      ),
      body: SafeArea(
        child: orderProvider.errorMessage != null
            ? _OrdersError(
                message: orderProvider.errorMessage!,
                onRetry: () => context.read<OrderProvider>().load(forceRefresh: true),
              )
            : orderProvider.isLoading
            ? const ShimmerListSkeleton()
            : orders.isEmpty
            ? _EmptyOrders(strings: strings)
            : RefreshIndicator(
                onRefresh: () => context.read<OrderProvider>().load(forceRefresh: true),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _OrderCard(order: orders[i], strings: strings),
                ),
              ),
      ),
    );
  }
}

class _OrdersError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _OrdersError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.inactive),
            const SizedBox(height: 12),
            Text('कुछ गड़बड़ हो गई', style: AppTextStyles.display(fontSize: 16)),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption(fontSize: 13),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('फिर से कोशिश करें'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.green,
                side: const BorderSide(color: AppColors.green),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  final AppStrings strings;
  const _EmptyOrders({required this.strings});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.inactive),
          const SizedBox(height: 12),
          Text(strings.noOrdersTitle, style: AppTextStyles.display(fontSize: 16)),
          const SizedBox(height: 6),
          Text(strings.noOrdersSubtitle, style: AppTextStyles.caption(fontSize: 13)),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final AppStrings strings;
  const _OrderCard({required this.order, required this.strings});

  String _statusLabel(OrderStatus status) => switch (status) {
        OrderStatus.placed => strings.orderStatusPlaced,
        OrderStatus.confirmed => strings.orderStatusConfirmed,
        OrderStatus.outForDelivery => strings.orderStatusOutForDelivery,
        OrderStatus.delivered => strings.orderStatusDelivered,
        OrderStatus.cancelled => strings.orderStatusCancelled,
      };

  Color _statusColor(OrderStatus status) => switch (status) {
        OrderStatus.delivered => AppColors.green,
        OrderStatus.cancelled => const Color(0xFFC0453B),
        OrderStatus.outForDelivery => AppColors.mustard,
        OrderStatus.confirmed => const Color(0xFF2E7DD1),
        OrderStatus.placed => AppColors.mutedDark,
      };

  IconData _statusIcon(OrderStatus status) => switch (status) {
        OrderStatus.delivered => Icons.check_circle_rounded,
        OrderStatus.cancelled => Icons.cancel_rounded,
        OrderStatus.outForDelivery => Icons.two_wheeler_rounded,
        OrderStatus.confirmed => Icons.storefront_rounded,
        OrderStatus.placed => Icons.receipt_long_rounded,
      };

  String _formattedDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} ${months[dt.month - 1]}, $hour12:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.status);
    final itemCount = order.items.fold<int>(0, (sum, i) => sum + i.quantity);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line, width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header strip: date on the left, status pill on the right.
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: AppColors.line, width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formattedDate(order.createdAt),
                    style: AppTextStyles.caption(fontSize: 12, color: AppColors.mutedDark)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(order.status), size: 13, color: statusColor),
                      const SizedBox(width: 5),
                      Text(_statusLabel(order.status),
                          style: AppTextStyles.caption(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: AppColors.sage, borderRadius: BorderRadius.circular(12)),
                      child: Stack(
                        children: [
                          const Center(child: Icon(Icons.shopping_basket_rounded, size: 22, color: AppColors.green)),
                          Positioned(
                            right: 2,
                            top: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(8)),
                              child: Text('$itemCount',
                                  style: AppTextStyles.caption(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.items.map((i) => '${i.nameHi} ×${i.quantity}').join(', '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          if (order.assignedMerchantName != null) ...[
                            const SizedBox(height: 3),
                            Text(order.assignedMerchantName!,
                                style: AppTextStyles.caption(fontSize: 11, color: AppColors.mutedDark)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: AppColors.line),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('₹${order.totalValue}', style: AppTextStyles.display(fontSize: 16)),
                    if (order.deliveryAddressLabel != null)
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_outlined, size: 13, color: AppColors.mutedDark),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(order.deliveryAddressLabel!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.caption(fontSize: 11, color: AppColors.mutedDark)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (order.status == OrderStatus.placed ||
                    order.status == OrderStatus.confirmed ||
                    order.status == OrderStatus.outForDelivery) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: order.id)),
                      ),
                      icon: const Icon(Icons.map_outlined, size: 16),
                      label: Text(strings.trackOrderButton),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.green),
                        foregroundColor: AppColors.green,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
