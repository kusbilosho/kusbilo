import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../home/data/catalog_provider.dart';
import '../providers/favorites_provider.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FavoritesProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleProvider>().strings;
    final lang = context.watch<LocaleProvider>().language;
    final favoritesProvider = context.watch<FavoritesProvider>();
    final favoriteIds = favoritesProvider.productIds;
    final catalog = context.watch<CatalogProvider>();
    final cart = context.watch<CartProvider>();

    final items = favoriteIds
        .map((id) => catalog.productById(id))
        .where((p) => p != null)
        .map((p) => p!)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: Text(strings.wishlist, style: AppTextStyles.display(fontSize: 18)),
        iconTheme: const IconThemeData(color: AppColors.charcoal),
      ),
      body: SafeArea(
        child: favoritesProvider.isLoading
            ? const ShimmerListSkeleton()
            : items.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.favorite_border_rounded, size: 48, color: AppColors.inactive),
                    const SizedBox(height: 12),
                    Text(strings.noFavoritesTitle, style: AppTextStyles.display(fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(strings.noFavoritesSubtitle, style: AppTextStyles.caption(fontSize: 13)),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final product = items[i];
                  final qty = cart.quantityOf(product.id);
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.line, width: 1),
                    ),
                    child: Row(
                      children: [
                        Text(product.emoji, style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(product.name(lang), style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w700)),
                              Text(product.priceDisplay, style: AppTextStyles.caption(fontSize: 12)),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => context.read<FavoritesProvider>().toggle(product.id),
                          icon: const Icon(Icons.favorite, color: Color(0xFFC0453B), size: 20),
                        ),
                        if (qty == 0)
                          TextButton(
                            onPressed: () => context.read<CartProvider>().add(product.id),
                            child: Text(strings.addToCart,
                                style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.green)),
                          )
                        else
                          Text('×$qty', style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.green)),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
