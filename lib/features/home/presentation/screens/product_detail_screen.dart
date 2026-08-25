import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/added_to_cart_popup.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../checkout/presentation/screens/checkout_screen.dart';
import '../../../favorites/presentation/providers/favorites_provider.dart';
import '../../data/catalog_provider.dart';
import '../../data/models/product.dart';
import '../../data/models/review.dart';
import '../widgets/product_image_gallery.dart';
import 'seller_products_screen.dart';

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
      bottomNavigationBar: _BottomActionBar(
        product: product,
        strings: strings,
        onPlaceOrder: () {
          if (qty == 0) cart.add(product.id);
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CheckoutScreen()),
          );
        },
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.white,
            pinned: true,
            expandedHeight: 320,
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
              background: ProductImageGallery(
                imageUrls: product.imageUrls,
                emoji: product.emoji,
                height: 320,
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
                // `product.tags` is intentionally NOT rendered here anymore.
                // It's SEO/search keywords the seller types in (e.g. "tshirt,
                // tee, टीशर्ट, t-shirt, casual wear") — great for matching
                // what a buyer searches or says out loud (see
                // Product.searchableText / the voice search), but showing
                // them as chips on the page just repeats the product name
                // in a messier form. Kept in the data model and used for
                // search; just not displayed here.
                if (product.ownerId != null) ...[
                  const SizedBox(height: 16),
                  _SellerRow(ownerId: product.ownerId!),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: qty == 0
                      ? ElevatedButton(
                          onPressed: () {
                            cart.add(product.id);
                            showAddedToCartPopup(context, strings.addedToCartMessage(product.name(lang)));
                          },
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

/// Fixed bar pinned to the bottom of the product page — price on the
/// left, Add-to-cart button (or the qty stepper once it's in the cart)
/// on the right. Stays visible while the rest of the page scrolls
/// underneath it, matching the layout of familiar shopping apps instead
/// of burying the action button mid-page where it scrolls out of view.
class _BottomActionBar extends StatelessWidget {
  final Product product;
  final AppStrings strings;
  final VoidCallback onPlaceOrder;

  const _BottomActionBar({
    required this.product,
    required this.strings,
    required this.onPlaceOrder,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, -3)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(product.priceDisplay,
                      style: AppTextStyles.display(fontSize: 17, color: AppColors.green)),
                  Text(strings.inclusiveOfTaxesLabel,
                      style: AppTextStyles.caption(fontSize: 11, color: AppColors.mutedDark)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: onPlaceOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(strings.placeOrderButton,
                  style: AppTextStyles.body(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
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
        // A permission-denied (or any other) stream error used to leave
        // this stuck on the loading spinner forever — snapshot.hasData
        // never becomes true, but nothing ever checked hasError either.
        // Treating an error the same as "no reviews yet" at least lets
        // the rest of the page render normally instead of an endless
        // spin with no way to tell what's wrong from the UI alone.
        if (snapshot.hasError) {
          return Text(strings.noReviewsYetMessage, style: AppTextStyles.caption(fontSize: 13));
        }
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
    final strings = context.watch<LocaleProvider>().strings;
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('merchants').doc(ownerId).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final shopName = data?['shopName'] as String?;
        if (shopName == null) return const SizedBox.shrink();
        final photoUrl = data?['shopPhotoUrl'] as String?;

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SellerProductsScreen(ownerId: ownerId, shopName: shopName, photoUrl: photoUrl),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line, width: 1),
            ),
            child: Row(
              children: [
                _SellerAvatar(shopName: shopName, photoUrl: photoUrl, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(strings.soldByLabel, style: AppTextStyles.caption(fontSize: 11, color: AppColors.mutedDark)),
                      const SizedBox(height: 2),
                      Text(shopName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(strings.exploreAllProductsLabel,
                    style: AppTextStyles.caption(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.green)),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.green),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Shop's circular avatar — a real photo if the seller uploaded one
/// (`shopPhotoUrl`), otherwise a colored circle with the shop name's
/// first letter so the row never looks broken/empty for sellers who
/// haven't added a photo yet.
class _SellerAvatar extends StatelessWidget {
  final String shopName;
  final String? photoUrl;
  final double size;
  const _SellerAvatar({required this.shopName, required this.photoUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    final initial = shopName.trim().isNotEmpty ? shopName.trim()[0].toUpperCase() : '?';
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: (photoUrl != null && photoUrl!.isNotEmpty)
          ? Image.network(
              photoUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initialCircle(initial),
            )
          : _initialCircle(initial),
    );
  }

  Widget _initialCircle(String initial) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(color: AppColors.sage, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(initial,
            style: AppTextStyles.display(fontSize: size * 0.4, color: AppColors.green)),
      );
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
