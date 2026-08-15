import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../favorites/presentation/providers/favorites_provider.dart';
import '../../data/catalog_provider.dart';
import '../../data/models/product.dart';
import '../../data/models/review.dart';

/// Full product page — big photo, description, tags, who's selling it,
/// a quantity control, a ratings/reviews section fed by buyers who
/// bought this from a delivered order (see RateOrderScreen), and a
/// "similar products" strip from the same category. Reached by tapping
/// any product card anywhere in the app.
class ProductDetailScreen extends StatelessWidget {
  final Product product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleProvider>().strings;
    final lang = context.watch<LocaleProvider>().language;
    final cart = context.watch<CartProvider>();
    final favorites = context.watch<FavoritesProvider>();
    final qty = cart.quantityOf(product.id);
    final isFavorite = favorites.isFavorite(product.id);

    final similar = context
        .watch<CatalogProvider>()
        .productsByCategory(product.categoryId)
        .where((p) => p.id != product.id)
        .take(10)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.white,
            pinned: true,
            expandedHeight: 260,
            iconTheme: const IconThemeData(color: AppColors.charcoal),
            actions: [
              IconButton(
                onPressed: () => context.read<FavoritesProvider>().toggle(product.id),
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? const Color(0xFFC0453B) : AppColors.mutedDark,
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: AppColors.sage,
                child: product.imageUrl != null
                    ? Image.network(
                        product.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Center(child: Text(product.emoji, style: const TextStyle(fontSize: 90))),
                      )
                    : Center(child: Text(product.emoji, style: const TextStyle(fontSize: 90))),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(product.name(lang), style: AppTextStyles.display(fontSize: 20)),
                const SizedBox(height: 6),
                Text(product.priceDisplay, style: AppTextStyles.display(fontSize: 18, color: AppColors.green)),
                if (product.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(strings.productDescriptionLabel, style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(product.description, style: AppTextStyles.caption(fontSize: 13, color: AppColors.mutedDark)),
                ],
                if (product.tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: product.tags
                        .map((t) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.sage,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(t, style: AppTextStyles.caption(fontSize: 11, color: AppColors.green)),
                            ))
                        .toList(),
                  ),
                ],
                if (product.ownerId != null) ...[
                  const SizedBox(height: 16),
                  _SellerRow(ownerId: product.ownerId!),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: qty == 0
                      ? ElevatedButton(
                          onPressed: () => cart.add(product.id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Text(strings.addToCart,
                              style: AppTextStyles.body(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                        )
                      : Center(
                          child: _QtyStepperLarge(
                            qty: qty,
                            onIncrement: () => cart.increment(product.id),
                            onDecrement: () => cart.decrement(product.id),
                          ),
                        ),
                ),
                const SizedBox(height: 28),
                _ReviewsSection(productId: product.id, strings: strings),
                if (similar.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  Text(strings.similarProductsTitle, style: AppTextStyles.display(fontSize: 16)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 150,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: similar.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, i) => SizedBox(
                        width: 120,
                        child: _SimilarProductCard(product: similar[i], lang: lang),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  final String productId;
  final AppStrings strings;
  const _ReviewsSection({required this.productId, required this.strings});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green)));
        }
        final reviews = snapshot.data!.docs.map((d) => Review.fromMap(d.data())).toList();

        Widget summary;
        if (reviews.isEmpty) {
          summary = Text(strings.noReviewsYetMessage, style: AppTextStyles.caption(fontSize: 13));
        } else {
          final avg = reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
          summary = Row(
            children: [
              ...List.generate(5, (i) {
                final filled = i < avg.round();
                return Icon(filled ? Icons.star_rounded : Icons.star_border_rounded,
                    color: AppColors.mustard, size: 20);
              }),
              const SizedBox(width: 8),
              Text(avg.toStringAsFixed(1), style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(width: 4),
              Text(strings.reviewCountLabel(reviews.length), style: AppTextStyles.caption(fontSize: 12)),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            summary,
            if (reviews.isNotEmpty) ...[
              const SizedBox(height: 14),
              for (final review in reviews.take(5)) ...[
                _ReviewTile(review: review),
                const SizedBox(height: 10),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final Review review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.sage,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(5, (i) {
                final filled = i < review.rating;
                return Icon(filled ? Icons.star_rounded : Icons.star_border_rounded,
                    color: AppColors.mustard, size: 14);
              }),
              if (review.buyerName.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(review.buyerName, style: AppTextStyles.caption(fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(review.comment, style: AppTextStyles.body(fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

class _SellerRow extends StatelessWidget {
  final String ownerId;
  const _SellerRow({required this.ownerId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('merchants').doc(ownerId).get(),
      builder: (context, snapshot) {
        final shopName = snapshot.data?.data()?['shopName'] as String?;
        if (shopName == null) return const SizedBox.shrink();
        return Row(
          children: [
            const Icon(Icons.storefront_rounded, size: 16, color: AppColors.mutedDark),
            const SizedBox(width: 6),
            Text(shopName, style: AppTextStyles.caption(fontSize: 12, color: AppColors.mutedDark)),
          ],
        );
      },
    );
  }
}

class _SimilarProductCard extends StatelessWidget {
  final Product product;
  final AppLanguage lang;
  const _SimilarProductCard({required this.product, required this.lang});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Center(
                child: product.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(product.imageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => Text(product.emoji, style: const TextStyle(fontSize: 30))),
                      )
                    : Text(product.emoji, style: const TextStyle(fontSize: 30)),
              ),
            ),
            const SizedBox(height: 6),
            Text(product.name(lang),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.body(fontSize: 12, fontWeight: FontWeight.w600)),
            Text(product.priceDisplay, style: AppTextStyles.caption(fontSize: 11, color: AppColors.mutedDark)),
          ],
        ),
      ),
    );
  }
}

class _QtyStepperLarge extends StatelessWidget {
  final int qty;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  const _QtyStepperLarge({required this.qty, required this.onIncrement, required this.onDecrement});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(onPressed: onDecrement, icon: const Icon(Icons.remove, color: Colors.white)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('$qty', style: AppTextStyles.body(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
          IconButton(onPressed: onIncrement, icon: const Icon(Icons.add, color: Colors.white)),
        ],
      ),
    );
  }
}
