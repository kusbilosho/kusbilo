import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/catalog_provider.dart';
import 'home_screen.dart' show buildProductCard;

/// One seller's full storefront — their photo/name up top, then every
/// active product with `ownerId == this seller's uid` in a grid.
/// Reached by tapping "Explore all products" on any of their listings'
/// product detail page.
class SellerProductsScreen extends StatelessWidget {
  final String ownerId;
  final String shopName;
  final String? photoUrl;

  const SellerProductsScreen({
    super.key,
    required this.ownerId,
    required this.shopName,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleProvider>().strings;
    final lang = context.watch<LocaleProvider>().language;
    final products = context
        .watch<CatalogProvider>()
        .products
        .where((p) => p.ownerId == ownerId && p.isActive)
        .toList();

    final initial = shopName.trim().isNotEmpty ? shopName.trim()[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.white,
            pinned: true,
            iconTheme: const IconThemeData(color: AppColors.charcoal),
            title: Text(shopName, style: AppTextStyles.display(fontSize: 16)),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: (photoUrl != null && photoUrl!.isNotEmpty)
                        ? CachedNetworkImage(imageUrl: photoUrl!, width: 60, height: 60, fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _initialCircle(initial))
                        : _initialCircle(initial),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(shopName, style: AppTextStyles.display(fontSize: 18)),
                        const SizedBox(height: 4),
                        Text('${products.length}', style: AppTextStyles.caption(fontSize: 12, color: AppColors.mutedDark)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (products.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(strings.noOtherProductsMessage, style: AppTextStyles.caption(fontSize: 13)),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => buildProductCard(context, products[i], lang, strings.addToCart),
                  childCount: products.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _initialCircle(String initial) => Container(
        width: 60,
        height: 60,
        decoration: const BoxDecoration(color: AppColors.sage, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(initial, style: AppTextStyles.display(fontSize: 22, color: AppColors.green)),
      );
}
