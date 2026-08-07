import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/haat_badge.dart';
import '../../../../core/widgets/lang_toggle.dart';
import '../../../home/data/models/product.dart';
import '../../../order/data/models/order.dart';
import '../../../order/presentation/screens/order_tracking_screen.dart';
import '../providers/merchant_provider.dart';
import '../providers/seller_orders_provider.dart';
import '../providers/seller_products_provider.dart';
import 'add_product_screen.dart';
import 'store_settings_screen.dart';

/// Home base for an approved seller: shop header, live stats, product
/// list, and entry points for order/store management. Reached once
/// [MerchantProvider.status] is approved — see MerchantEntryScreen.
class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    context.read<SellerProductsProvider>().load();
    context.read<SellerOrdersProvider>().load();
    NotificationService.registerMerchantDevice();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleProvider>().strings;
    final application = context.watch<MerchantProvider>().application;
    final sellerProducts = context.watch<SellerProductsProvider>();
    final sellerOrders = context.watch<SellerOrdersProvider>();

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Padding(
                        padding: EdgeInsets.only(right: 8, top: 4, bottom: 4),
                        child: Icon(Icons.arrow_back_rounded, size: 22, color: AppColors.green),
                      ),
                    ),
                    const HaatBadge(size: 30),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(strings.sellerDashboardTitle, style: AppTextStyles.display(fontSize: 18)),
                    ),
                    const LangToggle(),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _ShopHeaderCard(
                  shopName: application?.shopName ?? '',
                  ownerName: application?.ownerName ?? '',
                  badgeLabel: strings.approvedBadge,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.inventory_2_outlined,
                        label: strings.myProductsStat,
                        value: '${sellerProducts.productCount}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.receipt_long_outlined,
                        label: strings.ordersStat,
                        value: '${sellerOrders.pendingOrders.length}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.currency_rupee_rounded,
                        label: strings.earningsStat,
                        value: '₹0',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (sellerOrders.pendingOrders.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _IncomingOrdersSection(orders: sellerOrders.pendingOrders, strings: strings),
                ),
              ),
            if (sellerOrders.activeOrders.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _ActiveDeliveriesSection(orders: sellerOrders.activeOrders, strings: strings),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(strings.myProductsStat, style: AppTextStyles.display(fontSize: 17)),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => const AddProductScreen())),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(strings.addProductButton),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              sliver: sellerProducts.products.isEmpty
                  ? SliverToBoxAdapter(child: _EmptyProducts(strings: strings))
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _SellerProductRow(product: sellerProducts.products[i]),
                        ),
                        childCount: sellerProducts.products.length,
                      ),
                    ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    _DashboardMenuRow(
                      icon: Icons.receipt_long_rounded,
                      label: strings.manageOrders,
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(strings.featureComingSoon), duration: const Duration(seconds: 2)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _DashboardMenuRow(
                      icon: Icons.storefront_outlined,
                      label: strings.storeSettings,
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => const StoreSettingsScreen())),
                    ),
                    const SizedBox(height: 10),
                    _DashboardMenuRow(
                      icon: Icons.shopping_bag_outlined,
                      label: strings.backToShopping,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Orders this seller has already accepted (confirmed) or is currently
/// delivering (outForDelivery). "डिलीवरी शुरू करें" starts broadcasting
/// this seller's live GPS on the order (see LiveLocationService);
/// "डिलीवर हो गया" stops it and closes the order out.
class _ActiveDeliveriesSection extends StatelessWidget {
  final List<Order> orders;
  final AppStrings strings;
  const _ActiveDeliveriesSection({required this.orders, required this.strings});

  @override
  Widget build(BuildContext context) {
    final isUpdating = context.watch<SellerOrdersProvider>().isUpdatingStatus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(strings.activeDeliveriesTitle, style: AppTextStyles.display(fontSize: 17)),
        const SizedBox(height: 12),
        ...orders.map((order) {
          final isOutForDelivery = order.status == OrderStatus.outForDelivery;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.green, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.items.map((i) => '${i.nameHi} ×${i.quantity}').join(', '),
                    style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('₹${order.totalValue}', style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w700)),
                      Text(
                        isOutForDelivery ? strings.deliveryInProgressLabel : strings.deliveryPreparingLabel,
                        style: AppTextStyles.caption(
                            fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: order.id)),
                          ),
                          icon: const Icon(Icons.map_outlined, size: 16),
                          label: Text(strings.viewMapButton),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.green),
                            foregroundColor: AppColors.green,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isUpdating
                              ? null
                              : () async {
                                  final provider = context.read<SellerOrdersProvider>();
                                  final ok = isOutForDelivery
                                      ? await provider.markDelivered(order.id)
                                      : await provider.startDelivery(order.id);
                                  if (!context.mounted || ok) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(strings.deliveryUpdateFailed)),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            isOutForDelivery ? strings.markDeliveredButton : strings.startDeliveryButton,
                            style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _ShopHeaderCard extends StatelessWidget {
  final String shopName;
  final String ownerName;
  final String badgeLabel;

  const _ShopHeaderCard({required this.shopName, required this.ownerName, required this.badgeLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.green,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shopName,
                    style: AppTextStyles.display(fontSize: 16, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(ownerName,
                    style: AppTextStyles.caption(fontSize: 12, color: Colors.white.withOpacity(0.85))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(badgeLabel,
                style: AppTextStyles.caption(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line, width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppColors.green),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.display(fontSize: 16)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption(fontSize: 11, color: AppColors.mutedDark)),
        ],
      ),
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  final AppStrings strings;
  const _EmptyProducts({required this.strings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line, width: 1),
      ),
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.inactive),
          const SizedBox(height: 12),
          Text(strings.noProductsTitle, style: AppTextStyles.display(fontSize: 15)),
          const SizedBox(height: 4),
          Text(strings.noProductsSubtitle, style: AppTextStyles.caption(fontSize: 12, color: AppColors.mutedDark)),
        ],
      ),
    );
  }
}

class _IncomingOrdersSection extends StatelessWidget {
  final List<Order> orders;
  final AppStrings strings;
  const _IncomingOrdersSection({required this.orders, required this.strings});

  @override
  Widget build(BuildContext context) {
    final isResponding = context.watch<SellerOrdersProvider>().isResponding;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(strings.incomingOrdersTitle, style: AppTextStyles.display(fontSize: 17)),
        const SizedBox(height: 12),
        ...orders.map((order) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.mustard, width: 1.4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.items.map((i) => '${i.nameHi} ×${i.quantity}').join(', '),
                      style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('₹${order.totalValue}', style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w700)),
                        if (order.deliveryAddressLabel != null)
                          Flexible(
                            child: Text(order.deliveryAddressLabel!,
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption(fontSize: 11)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isResponding
                                ? null
                                : () async {
                                    final ok = await context
                                        .read<SellerOrdersProvider>()
                                        .respond(order.id, accept: false);
                                    if (!context.mounted || ok) return;
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(content: Text(strings.orderResponseFailed)));
                                  },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFC0453B)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(strings.rejectOrderButton,
                                style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFC0453B))),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isResponding
                                ? null
                                : () async {
                                    final ok = await context
                                        .read<SellerOrdersProvider>()
                                        .respond(order.id, accept: true);
                                    if (!context.mounted || ok) return;
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(content: Text(strings.orderResponseFailed)));
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(strings.acceptOrderButton,
                                style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}

class _SellerProductRow extends StatelessWidget {
  final Product product;
  const _SellerProductRow({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: AppColors.sage, borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(product.emoji, style: const TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.nameHi,
                    style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(product.priceDisplay,
                    style: AppTextStyles.caption(fontSize: 12, color: AppColors.mutedDark)),
              ],
            ),
          ),
          Switch(
            value: product.isActive,
            activeColor: AppColors.green,
            onChanged: (_) => context.read<SellerProductsProvider>().toggleActive(product.id),
          ),
        ],
      ),
    );
  }
}

class _DashboardMenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DashboardMenuRow({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.muted),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w600))),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
