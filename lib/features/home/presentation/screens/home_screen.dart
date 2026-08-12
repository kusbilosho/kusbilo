import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/haat_badge.dart';
import '../../../../core/widgets/lang_toggle.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../checkout/presentation/screens/checkout_screen.dart';
import '../../../merchant/presentation/providers/merchant_provider.dart';
import '../../../merchant/presentation/screens/merchant_kyc_screen.dart';
import '../../data/catalog_provider.dart';
import '../../data/models/category.dart';
import '../../data/models/product.dart';
import '../../../order/presentation/screens/order_history_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/static_info_screen.dart';
import '../../../admin/presentation/providers/admin_provider.dart';
import '../../../admin/presentation/screens/admin_kyc_queue_screen.dart';
import '../../../admin/presentation/screens/manage_categories_screen.dart';
import '../../../addresses/presentation/providers/addresses_provider.dart';
import '../../../addresses/presentation/screens/addresses_screen.dart';
import '../../../favorites/presentation/providers/favorites_provider.dart';
import '../../../favorites/presentation/screens/wishlist_screen.dart';
import '../widgets/live_call_sheet.dart';
import 'product_detail_screen.dart';

/// Bottom-nav shell shown right after login: Home / Categories / Cart /
/// Profile. Loads the catalog once when this shell first mounts, so every
/// tab underneath just reads from [CatalogProvider] — no tab fetches or
/// stores its own copy of the data.
/// Opens the app's Play Store (or App Store) listing for the buyer to
/// rate it. Reads the real package id at runtime via package_info_plus
/// instead of hardcoding one, so this keeps working correctly even if
/// the app's applicationId changes later.
Future<void> _openRateApp(BuildContext context) async {
  final strings = context.read<LocaleProvider>().strings;
  try {
    final info = await PackageInfo.fromPlatform();
    final uri = Uri.parse('https://play.google.com/store/apps/details?id=${info.packageName}');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings.rateAppFailedError)));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings.rateAppFailedError)));
    }
  }
}

class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({super.key});

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> with WidgetsBindingObserver {
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<CatalogProvider>().load();
    context.read<MerchantProvider>().load();
    context.read<CartProvider>().load();
    context.read<FavoritesProvider>().load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // If the app sat in the background for a while (or its very first fetch
  // never finished before the user left it), retry the catalog fetch when
  // the app comes back to the foreground instead of leaving Home stuck on
  // whatever state it was last in. `load()` itself is now timeout-guarded,
  // so this only ever retries a genuinely unfinished/failed fetch — it's a
  // no-op once the catalog has actually loaded.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final catalog = context.read<CatalogProvider>();
      if (catalog.status != CatalogStatus.loaded) {
        catalog.load(forceRefresh: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleProvider>().strings;

    final tabs = [
      _HomeTab(onGoToCategories: () => setState(() => _tabIndex = 1)),
      const _CategoriesTab(),
      const _CartTab(),
      const _ProfileTab(),
    ];

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(child: tabs[_tabIndex]),
      bottomNavigationBar: _BottomNav(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        strings: strings,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final AppStrings strings;

  const _BottomNav({required this.currentIndex, required this.onTap, required this.strings});

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartProvider>().totalItemCount;

    final items = [
      (Icons.home_rounded, strings.navHome),
      (Icons.grid_view_rounded, strings.categoriesTitle),
      (Icons.shopping_cart_outlined, strings.navCart),
      (Icons.person_outline_rounded, strings.navProfile),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: List.generate(items.length, (i) {
              final bool selected = i == currentIndex;
              final (icon, label) = items[i];
              final bool isCartTab = i == 2;
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(icon, size: 22, color: selected ? AppColors.green : AppColors.muted),
                          if (isCartTab && cartCount > 0)
                            Positioned(
                              right: -8,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.mustard,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  cartCount > 9 ? '9+' : '$cartCount',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: AppTextStyles.caption(
                          fontSize: 11,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? AppColors.green : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  final VoidCallback onGoToCategories;
  const _HomeTab({required this.onGoToCategories});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

// Converted from StatelessWidget to StatefulWidget with a manual
// addListener() subscription to CatalogProvider. `context.watch` *should*
// rebuild this on its own, but real-device reports showed the tab staying
// stuck on the skeleton even after the catalog had actually finished
// loading (confirmed because re-selecting the already-active Home tab —
// which force-rebuilds this widget from scratch — immediately showed the
// real data). Subscribing directly with addListener()/setState() removes
// any dependency on that InheritedWidget propagation path entirely, so
// this widget is guaranteed to rebuild the moment CatalogProvider calls
// notifyListeners(), no matter what.
class _HomeTabState extends State<_HomeTab> {
  CatalogProvider? _catalog;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final catalog = context.read<CatalogProvider>();
    if (!identical(_catalog, catalog)) {
      _catalog?.removeListener(_onCatalogChanged);
      _catalog = catalog;
      _catalog!.addListener(_onCatalogChanged);
    }
  }

  void _onCatalogChanged() {
    debugPrint('[HomeTab] manual listener fired — catalog.status=${_catalog?.status}');
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _catalog?.removeListener(_onCatalogChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleProvider>().strings;
    final lang = context.watch<LocaleProvider>().language;
    final catalog = _catalog!;
    debugPrint('[HomeTab] build() called — catalog.status=${catalog.status}');

    if (catalog.isLoading || catalog.status == CatalogStatus.idle) {
      debugPrint('[HomeTab] showing skeleton (status=${catalog.status})');
      return const HomeTabSkeleton();
    }

    final featured = catalog.products.take(6).toList();

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const HaatBadge(size: 34),
                        const SizedBox(width: 10),
                        Text(strings.appName, style: AppTextStyles.display(fontSize: 18)),
                      ],
                    ),
                    const LangToggle(),
                  ],
                ),
                const SizedBox(height: 20),
                Text(strings.homeGreeting, style: AppTextStyles.display(fontSize: 22)),
                const SizedBox(height: 4),
                Text(strings.homeSubGreeting,
                    style: AppTextStyles.caption(fontSize: 14, color: AppColors.mutedDark)),
                const SizedBox(height: 18),
                _SearchBar(hint: strings.searchHint),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: strings.categoriesTitle,
                  actionLabel: strings.seeAll,
                  onActionTap: widget.onGoToCategories,
                ),
                const SizedBox(height: 12),
                if (catalog.status == CatalogStatus.error)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFC0453B), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(strings.catalogLoadFailedMessage,
                            style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.w700)),
                        if (catalog.errorMessage != null) ...[
                          const SizedBox(height: 4),
                          Text(catalog.errorMessage!,
                              style: AppTextStyles.caption(fontSize: 11, color: AppColors.muted)),
                        ],
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => context.read<CatalogProvider>().load(forceRefresh: true),
                          child: Text(strings.retryButton,
                              style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.green)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(
            child: SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: catalog.categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, i) {
                  final cat = catalog.categories[i];
                  return GestureDetector(
                    onTap: () => _openCategory(context, cat),
                    child: _CategoryCircle(label: cat.name(lang), icon: cat.icon, color: cat.color, imageUrl: cat.imageUrl),
                  );
                },
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Text(strings.categoriesTitle, style: AppTextStyles.display(fontSize: 18)),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.86,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final cat = catalog.categories[i];
                final items = catalog.productsByCategory(cat.id);
                return GestureDetector(
                  onTap: () => _openCategory(context, cat),
                  child: _CategoryPreviewCard(category: cat, lang: lang, items: items),
                );
              },
              childCount: catalog.categories.length,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _SectionHeader(title: strings.featuredTitle, actionLabel: strings.seeAll),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.78,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _ProductCard(product: featured[i], lang: lang, addLabel: strings.addToCart),
              childCount: featured.length,
            ),
          ),
        ),
      ],
    );
  }

  void _openCategory(BuildContext context, Category cat) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _CategoryDetailScreen(category: cat)));
  }
}

/// Blinkit-style category preview: a 2x2 grid of that category's product
/// thumbnails inside a soft card, with an item-count badge and the
/// category name below. Falls back to the category's own icon tile when
/// it has no products yet, so an empty category never looks broken.
class _CategoryPreviewCard extends StatelessWidget {
  final Category category;
  final AppLanguage lang;
  final List<Product> items;

  const _CategoryPreviewCard({required this.category, required this.lang, required this.items});

  @override
  Widget build(BuildContext context) {
    final preview = items.take(4).toList();
    final extra = items.length - preview.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.sage,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.line, width: 1),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: preview.isEmpty
                      ? Center(child: Icon(category.icon, color: category.color, size: 30))
                      : GridView.count(
                          crossAxisCount: 2,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                          physics: const NeverScrollableScrollPhysics(),
                          children: preview
                              .map((p) => ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      color: Colors.white,
                                      child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                                          ? Image.network(p.imageUrl!, fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Center(
                                                  child: Text(p.emoji.isNotEmpty ? p.emoji : '🛒',
                                                      style: const TextStyle(fontSize: 16))))
                                          : Center(
                                              child: Text(p.emoji.isNotEmpty ? p.emoji : '🛒',
                                                  style: const TextStyle(fontSize: 16))),
                                    ),
                                  ))
                              .toList(),
                        ),
                ),
              ),
              if (extra > 0)
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Text('+$extra', style: AppTextStyles.caption(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.mutedDark)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(category.name(lang),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body(fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// Full-page grid of all categories — reached via the bottom nav's
/// "श्रेणियाँ" (Categories) tab. Tapping a category opens the filtered
/// product list for that category.
class _CategoriesTab extends StatelessWidget {
  const _CategoriesTab();

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleProvider>().strings;
    final lang = context.watch<LocaleProvider>().language;
    final catalog = context.watch<CatalogProvider>();

    if (catalog.isLoading || catalog.status == CatalogStatus.idle) {
      return const CategoriesTabSkeleton();
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const HaatBadge(size: 34),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(strings.categoriesTitle, style: AppTextStyles.display(fontSize: 18)),
                    ),
                    const LangToggle(),
                  ],
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 18,
              crossAxisSpacing: 8,
              childAspectRatio: 0.78,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final cat = catalog.categories[i];
                final count = catalog.productsByCategory(cat.id).length;
                return _CategoryGridTile(
                  label: cat.name(lang),
                  icon: cat.icon,
                  color: cat.color,
                  imageUrl: cat.imageUrl,
                  itemsLabel: strings.itemsCount(count),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => _CategoryDetailScreen(category: cat))),
                );
              },
              childCount: catalog.categories.length,
            ),
          ),
        ),
      ],
    );
  }
}

/// Shows every product belonging to one category.
class _CategoryDetailScreen extends StatelessWidget {
  final Category category;
  const _CategoryDetailScreen({required this.category});

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleProvider>().strings;
    final lang = context.watch<LocaleProvider>().language;
    final items = context.watch<CatalogProvider>().productsByCategory(category.id);

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
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: category.color.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(category.icon, color: category.color, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(category.name(lang), style: AppTextStyles.display(fontSize: 18)),
                    ),
                    const LangToggle(),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              sliver: items.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text(strings.noProductsInCategory, style: AppTextStyles.caption(fontSize: 13)),
                        ),
                      ),
                    )
                  : SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.78,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) =>
                            _ProductCard(product: items[i], lang: lang, addLabel: strings.addToCart),
                        childCount: items.length,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fully functional cart tab: lists every item with quantity > 0, lets the
/// user adjust quantity with +/-, and shows a live subtotal.
class _CartTab extends StatelessWidget {
  const _CartTab();

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleProvider>().strings;
    final lang = context.watch<LocaleProvider>().language;
    final cart = context.watch<CartProvider>();
    final catalog = context.watch<CatalogProvider>();

    final cartItems = cart.quantities.entries
        .map((e) => (product: catalog.productById(e.key), qty: e.value))
        .where((entry) => entry.product != null)
        .map((entry) => (product: entry.product!, qty: entry.qty))
        .toList();

    final total = cartItems.fold<int>(0, (sum, item) => sum + item.product.priceValue * item.qty);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              const HaatBadge(size: 34),
              const SizedBox(width: 10),
              Expanded(child: Text(strings.navCart, style: AppTextStyles.display(fontSize: 18))),
              const LangToggle(),
            ],
          ),
        ),
        Expanded(
          child: cartItems.isEmpty
              ? _EmptyCart(strings: strings)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  itemCount: cartItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _CartRow(product: cartItems[i].product, lang: lang, qty: cartItems[i].qty),
                ),
        ),
        if (cartItems.isNotEmpty) _CartSummary(total: total, strings: strings),
      ],
    );
  }
}

class _EmptyCart extends StatelessWidget {
  final AppStrings strings;
  const _EmptyCart({required this.strings});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shopping_cart_outlined, size: 48, color: AppColors.inactive),
          const SizedBox(height: 12),
          Text(strings.cartEmptyTitle, style: AppTextStyles.display(fontSize: 16)),
          const SizedBox(height: 6),
          Text(strings.cartEmptySubtitle, style: AppTextStyles.caption(fontSize: 13)),
        ],
      ),
    );
  }
}

class _CartRow extends StatelessWidget {
  final Product product;
  final AppLanguage lang;
  final int qty;

  const _CartRow({required this.product, required this.lang, required this.qty});

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
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: AppColors.sage, borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(product.emoji, style: const TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name(lang),
                    style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(product.priceDisplay,
                    style: AppTextStyles.caption(fontSize: 12, color: AppColors.mutedDark)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _QtyStepper(
            qty: qty,
            onIncrement: () => context.read<CartProvider>().increment(product.id),
            onDecrement: () => context.read<CartProvider>().decrement(product.id),
          ),
        ],
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  final int total;
  final AppStrings strings;
  const _CartSummary({required this.total, required this.strings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(strings.subtotal, style: AppTextStyles.caption(fontSize: 12, color: AppColors.mutedDark)),
                  Text('₹$total', style: AppTextStyles.display(fontSize: 20)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(strings.checkoutButton,
                  style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact +/- quantity control shared by product cards and cart rows.
class _QtyStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _QtyStepper({required this.qty, required this.onIncrement, required this.onDecrement});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.green, width: 1.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepperButton(Icons.remove_rounded, onDecrement),
          SizedBox(
            width: 26,
            child: Text('$qty',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.green)),
          ),
          _stepperButton(Icons.add_rounded, onIncrement),
        ],
      ),
    );
  }

  Widget _stepperButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        child: Icon(icon, size: 16, color: AppColors.green),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final String hint;
  const _SearchBar({required this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line, width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 20, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              style: AppTextStyles.body(fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: AppTextStyles.caption(fontSize: 13),
              ),
            ),
          ),
          // Voice ordering entry point — placed right in the search bar
          // since typing is the exact barrier this is meant to remove.
          GestureDetector(
            onTap: () => showLiveCallSheet(context),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: AppColors.sage, shape: BoxShape.circle),
              child: const Icon(Icons.mic, size: 18, color: AppColors.green),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback? onActionTap;
  const _SectionHeader({required this.title, required this.actionLabel, this.onActionTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.display(fontSize: 17)),
        GestureDetector(
          onTap: onActionTap,
          child: Text(actionLabel,
              style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.green)),
        ),
      ],
    );
  }
}

class _CategoryCircle extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final String? imageUrl;
  const _CategoryCircle({required this.label, required this.icon, required this.color, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
            // Admin-uploaded category photo takes over from the icon
            // whenever one is set — the icon stays as the fallback for
            // every category that hasn't had a photo added yet.
            child: (imageUrl != null && imageUrl!.isNotEmpty)
                ? ClipOval(
                    // A 1.35x zoom crops away the plain background that
                    // most product-style photos are shot with, so the
                    // subject fills the circle instead of floating in
                    // the middle of visible white space.
                    child: Transform.scale(
                      scale: 1.35,
                      child: Image.network(
                        imageUrl!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(icon, color: color, size: 26),
                      ),
                    ),
                  )
                : Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.charcoal),
          ),
        ],
      ),
    );
  }
}

/// Bigger tappable category card used on the full Categories tab.
/// Clean, dense icon-grid tile for the full Categories page — matches
/// the layout used by major grocery/shopping apps (large marketplaces):
/// a colored circular icon with the label and item count underneath,
/// no card chrome. Visually consistent with the small `_CategoryCircle`
/// preview used on the Home tab, just sized up for a standalone grid.
class _CategoryGridTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final String? imageUrl;
  final String itemsLabel;
  final VoidCallback onTap;

  const _CategoryGridTile({
    required this.label,
    required this.icon,
    required this.color,
    this.imageUrl,
    required this.itemsLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: (imageUrl != null && imageUrl!.isNotEmpty)
                  ? ClipOval(
                      // Same zoom-crop as the Home circle — pulls the
                      // subject out from the middle of whatever plain
                      // background the source photo was shot on.
                      child: Transform.scale(
                        scale: 1.35,
                        child: Image.network(
                          imageUrl!,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(icon, color: color, size: 28),
                        ),
                      ),
                    )
                  : Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(itemsLabel,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption(fontSize: 10, color: AppColors.mutedDark)),
          ],
        ),
      ),
    );
  }
}

/// Product card used on Home and Category grids. Shows an Add button when
/// the product isn't in the cart yet, and a +/- stepper once it is.
class _ProductCard extends StatelessWidget {
  final Product product;
  final AppLanguage lang;
  final String addLabel;

  const _ProductCard({required this.product, required this.lang, required this.addLabel});

  @override
  Widget build(BuildContext context) {
    final qty = context.watch<CartProvider>().quantityOf(product.id);
    final isFavorite = context.watch<FavoritesProvider>().isFavorite(product.id);

    return InkWell(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product))),
      borderRadius: BorderRadius.circular(16),
      child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.charcoal.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      color: AppColors.sage,
                      child: Center(
                        child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                            ? Image.network(
                                product.imageUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  // Soft pulsing placeholder instead of a
                                  // blank box while the image streams in.
                                  return TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0.4, end: 1.0),
                                    duration: const Duration(milliseconds: 700),
                                    curve: Curves.easeInOut,
                                    builder: (context, value, _) => Opacity(
                                      opacity: value,
                                      child: Icon(Icons.image_outlined, color: AppColors.inactive, size: 32),
                                    ),
                                  );
                                },
                                errorBuilder: (_, __, ___) =>
                                    Text(product.emoji.isNotEmpty ? product.emoji : '🛒', style: const TextStyle(fontSize: 40)),
                              )
                            : Text(product.emoji.isNotEmpty ? product.emoji : '🛒', style: const TextStyle(fontSize: 40)),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => context.read<FavoritesProvider>().toggle(product.id),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        size: 16,
                        color: isFavorite ? const Color(0xFFC0453B) : AppColors.inactive,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(product.name(lang),
              style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(product.priceDisplay, style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.green)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: qty == 0
                ? OutlinedButton(
                    onPressed: () => context.read<CartProvider>().add(product.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.green,
                      side: const BorderSide(color: AppColors.green, width: 1.4),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(addLabel,
                        style: AppTextStyles.body(
                            fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.green)),
                  )
                : Center(
                    child: _QtyStepper(
                      qty: qty,
                      onIncrement: () => context.read<CartProvider>().increment(product.id),
                      onDecrement: () => context.read<CartProvider>().decrement(product.id),
                    ),
                  ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Profile tab — shopping-app-style layout: avatar + phone number header,
/// grouped menu sections (My Account / Seller / Support), and logout.
/// Every row except Logout is UI-only for now (shows a "coming soon"
/// snackbar) — the real logic behind each gets built one at a time next.
class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleProvider>().strings;
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
    final kycStatus = context.watch<MerchantProvider>().status;

    String sellerSubtitle;
    switch (kycStatus) {
      case KycStatus.notApplied:
        sellerSubtitle = strings.becomeMerchantSubtitle;
        break;
      case KycStatus.pending:
        sellerSubtitle = strings.kycStatusPendingShort;
        break;
      case KycStatus.approved:
        sellerSubtitle = strings.kycStatusApprovedShort;
        break;
      case KycStatus.rejected:
        sellerSubtitle = strings.kycStatusRejectedShort;
        break;
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                const HaatBadge(size: 34),
                const SizedBox(width: 10),
                Expanded(child: Text(strings.navProfile, style: AppTextStyles.display(fontSize: 18))),
                const LangToggle(),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _ProfileHeaderCard(name: strings.profileGuestName, phone: phone),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _MenuSection(
              title: strings.myAccount,
              rows: [
                _MenuRowData(Icons.receipt_long_rounded, strings.myOrders, AppColors.green,
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const OrderHistoryScreen()))),
                _MenuRowData(Icons.location_on_outlined, strings.myAddresses, AppColors.green,
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const AddressesScreen()))),
                _MenuRowData(Icons.credit_card_rounded, strings.paymentMethods, AppColors.green,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => StaticInfoScreen(
                              title: strings.paymentMethods,
                              sections: [StaticInfoSection(body: strings.paymentMethodsInfo)],
                            )))),
                _MenuRowData(Icons.favorite_border_rounded, strings.wishlist, AppColors.green,
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const WishlistScreen()))),
              ],
              strings: strings,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _MenuSection(
              title: strings.sellerSection,
              rows: [
                _MenuRowData(Icons.storefront_rounded, strings.becomeMerchant, const Color(0xFFC0453B),
                    subtitle: sellerSubtitle,
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const MerchantEntryScreen()))),
              ],
              strings: strings,
            ),
          ),
        ),
        SliverToBoxAdapter(child: _AdminMenuSection(strings: strings)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _MenuSection(
              title: strings.supportSection,
              rows: [
                _MenuRowData(Icons.headset_mic_outlined, strings.helpSupport, AppColors.muted,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => StaticInfoScreen(
                              title: strings.helpSupport,
                              sections: [
                                StaticInfoSection(body: strings.helpSupportIntro),
                                StaticInfoSection(
                                  actionIcon: Icons.call,
                                  actionLabel: strings.callUsButton,
                                  onAction: () => launchUrl(Uri.parse('tel:+911234567890')),
                                ),
                                StaticInfoSection(
                                  actionIcon: Icons.chat,
                                  actionLabel: strings.whatsappUsButton,
                                  onAction: () => launchUrl(Uri.parse('https://wa.me/911234567890')),
                                ),
                                StaticInfoSection(
                                  actionIcon: Icons.email,
                                  actionLabel: strings.emailUsButton,
                                  onAction: () => launchUrl(Uri.parse('mailto:support@gaonhaat.app')),
                                ),
                              ],
                            )))),
                _MenuRowData(Icons.info_outline_rounded, strings.aboutUs, AppColors.muted,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => StaticInfoScreen(
                              title: strings.aboutUs,
                              sections: [StaticInfoSection(body: strings.aboutUsBody)],
                            )))),
                _MenuRowData(Icons.privacy_tip_outlined, strings.privacyPolicyTitle, AppColors.muted,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => StaticInfoScreen(
                              title: strings.privacyPolicyTitle,
                              sections: strings.privacyPolicySections
                                  .map((s) => StaticInfoSection(heading: s.$1, body: s.$2))
                                  .toList(),
                            )))),
                _MenuRowData(Icons.description_outlined, strings.termsOfServiceTitle, AppColors.muted,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => StaticInfoScreen(
                              title: strings.termsOfServiceTitle,
                              sections: strings.termsOfServiceSections
                                  .map((s) => StaticInfoSection(heading: s.$1, body: s.$2))
                                  .toList(),
                            )))),
                _MenuRowData(Icons.star_border_rounded, strings.rateApp, AppColors.muted,
                    onTap: () => _openRateApp(context)),
              ],
              strings: strings,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          sliver: SliverToBoxAdapter(
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmLogout(context, strings),
                icon: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFFC0453B)),
                label: Text(strings.logoutButton,
                    style: AppTextStyles.body(
                        fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFFC0453B))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFC0453B), width: 1.4),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: Text(strings.appVersion, style: AppTextStyles.caption(fontSize: 12, color: AppColors.muted)),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmLogout(BuildContext context, AppStrings strings) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(strings.logoutConfirmTitle,
            style: AppTextStyles.body(fontSize: 16, fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.cancel, style: AppTextStyles.body(fontSize: 14, color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              context.read<CartProvider>().resetSession();
              context.read<FavoritesProvider>().resetSession();
              context.read<AddressesProvider>().resetSession();
              await FirebaseAuth.instance.signOut();
              // AuthGate (in main.dart) listens to authStateChanges and will
              // automatically swap back to PhoneLoginScreen once signed out.
            },
            child: Text(strings.logoutConfirmYes,
                style: AppTextStyles.body(
                    fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFFC0453B))),
          ),
        ],
      ),
    );
  }
}

class _AdminMenuSection extends StatelessWidget {
  final AppStrings strings;
  const _AdminMenuSection({required this.strings});

  @override
  Widget build(BuildContext context) {
    // Hidden entirely for non-admins — checkIsAdmin() reads a server-set
    // custom claim, so there's nothing here a regular user could spoof
    // their way into by, say, tampering with local app state.
    return FutureBuilder<bool>(
      future: context.read<AdminProvider>().checkIsAdmin(),
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: _MenuSection(
            title: 'Admin',
            rows: [
              _MenuRowData(Icons.fact_check_outlined, strings.adminMenuLabel, AppColors.green,
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const AdminKycQueueScreen()))),
              _MenuRowData(Icons.category_outlined, 'Manage Categories', AppColors.green,
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const ManageCategoriesScreen()))),
            ],
            strings: strings,
          ),
        );
      },
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  final String name;
  final String phone;
  const _ProfileHeaderCard({required this.name, required this.phone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: AppColors.sage, shape: BoxShape.circle),
            child: const Icon(Icons.person_rounded, color: AppColors.green, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.display(fontSize: 16)),
                const SizedBox(height: 2),
                Text(phone, style: AppTextStyles.caption(fontSize: 13, color: AppColors.mutedDark)),
              ],
            ),
          ),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: AppColors.sage, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.edit_rounded, size: 16, color: AppColors.green),
          ),
        ],
      ),
    );
  }
}

class _MenuRowData {
  final IconData icon;
  final String title;
  final Color iconColor;
  final String? subtitle;
  final VoidCallback? onTap;
  const _MenuRowData(this.icon, this.title, this.iconColor, {this.subtitle, this.onTap});
}

class _MenuSection extends StatelessWidget {
  final String title;
  final List<_MenuRowData> rows;
  final AppStrings strings;
  const _MenuSection({required this.title, required this.rows, required this.strings});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 2),
          child: Text(title,
              style: AppTextStyles.caption(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line, width: 1),
          ),
          child: Column(
            children: List.generate(rows.length, (i) {
              final row = rows[i];
              return Column(
                children: [
                  InkWell(
                    onTap: row.onTap ??
                        () => ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(strings.featureComingSoon),
                                  duration: const Duration(seconds: 2)),
                            ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: row.iconColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(row.icon, size: 18, color: row.iconColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(row.title,
                                    style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w600)),
                                if (row.subtitle != null) ...[
                                  const SizedBox(height: 2),
                                  Text(row.subtitle!,
                                      style: AppTextStyles.caption(fontSize: 12, color: AppColors.mutedDark)),
                                ],
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.muted),
                        ],
                      ),
                    ),
                  ),
                  if (i < rows.length - 1)
                    const Divider(height: 1, color: AppColors.line, indent: 14, endIndent: 14),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}
