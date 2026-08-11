import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';

/// App-wide shimmer wrapper. Wrap any skeleton layout in this to get the
/// moving light-sweep "loading" animation used across the app (product
/// grids, category tiles, order tracking, lists, etc).
///
/// Usage:
/// ```dart
/// AppShimmer(
///   child: Column(children: [ShimmerBox(height: 16, width: 120), ...]),
/// )
/// ```
class AppShimmer extends StatelessWidget {
  final Widget child;
  const AppShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.line.withOpacity(0.55),
      highlightColor: AppColors.cream,
      period: const Duration(milliseconds: 1400),
      child: child,
    );
  }
}

/// A single solid block — the basic building block for every skeleton
/// (a line of text, an image placeholder, a button placeholder, etc).
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  final EdgeInsetsGeometry? margin;

  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.radius = 8,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A circular placeholder — used for avatars / category icons.
class ShimmerCircle extends StatelessWidget {
  final double size;
  const ShimmerCircle({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
    );
  }
}

/// Skeleton for a single product card (used in home feed / category grid).
/// Mirrors the real `_ProductCard` proportions so the layout doesn't jump
/// once real data arrives.
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.15,
            child: ShimmerBox(height: double.infinity, radius: 10),
          ),
          const SizedBox(height: 10),
          const ShimmerBox(height: 12, width: 90, radius: 4),
          const SizedBox(height: 6),
          const ShimmerBox(height: 10, width: 60, radius: 4),
          const SizedBox(height: 10),
          const ShimmerBox(height: 30, radius: 8),
        ],
      ),
    );
  }
}

/// Skeleton for the round category icon + label row on the home tab.
class CategoryCircleSkeleton extends StatelessWidget {
  const CategoryCircleSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      child: Column(
        children: [
          const ShimmerCircle(size: 56),
          const SizedBox(height: 8),
          const ShimmerBox(height: 10, width: 50, radius: 4),
        ],
      ),
    );
  }
}

/// Skeleton for the bigger category card (2x2 thumbnail preview / category
/// tile) used on the home tab and the categories tab.
class CategoryCardSkeleton extends StatelessWidget {
  const CategoryCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: ShimmerBox(height: double.infinity, radius: 10)),
          const SizedBox(height: 8),
          const ShimmerBox(height: 12, width: 70, radius: 4),
        ],
      ),
    );
  }
}

/// Full skeleton for the home tab's top area — search bar row + section
/// header, so the very first frame doesn't look like a blank white screen.
class HomeTabSkeleton extends StatelessWidget {
  const HomeTabSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const ShimmerCircle(size: 34),
                const SizedBox(width: 10),
                const ShimmerBox(height: 18, width: 100, radius: 4),
              ],
            ),
            const SizedBox(height: 20),
            const ShimmerBox(height: 22, width: 200, radius: 4),
            const SizedBox(height: 10),
            const ShimmerBox(height: 14, width: 140, radius: 4),
            const SizedBox(height: 18),
            const ShimmerBox(height: 52, radius: 26),
            const SizedBox(height: 24),
            const ShimmerBox(height: 18, width: 120, radius: 4),
            const SizedBox(height: 14),
            SizedBox(
              height: 92,
              child: Row(
                children: List.generate(
                  5,
                  (i) => Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: const CategoryCircleSkeleton(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const ShimmerBox(height: 18, width: 120, radius: 4),
            const SizedBox(height: 14),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.86,
              children: List.generate(6, (i) => const CategoryCardSkeleton()),
            ),
            const SizedBox(height: 24),
            const ShimmerBox(height: 18, width: 120, radius: 4),
            const SizedBox(height: 14),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.78,
              children: List.generate(4, (i) => const ProductCardSkeleton()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full skeleton for the categories tab — a 2-column grid of big cards.
class CategoriesTabSkeleton extends StatelessWidget {
  const CategoriesTabSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const ShimmerCircle(size: 34),
                const SizedBox(width: 10),
                const ShimmerBox(height: 18, width: 130, radius: 4),
              ],
            ),
            const SizedBox(height: 18),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.05,
              children: List.generate(6, (i) => const CategoryCardSkeleton()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Generic row skeleton — an avatar/icon block + two lines of text. Used
/// for simple list screens (addresses, admin lists, order history, etc).
class ShimmerListRow extends StatelessWidget {
  const ShimmerListRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line, width: 1),
      ),
      child: Row(
        children: [
          const ShimmerBox(width: 44, height: 44, radius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(height: 13, width: 160, radius: 4),
                SizedBox(height: 8),
                ShimmerBox(height: 11, width: 220, radius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A vertical list of `ShimmerListRow`s, ready to drop in as a full-screen
/// loading state for any list-based screen.
class ShimmerListSkeleton extends StatelessWidget {
  final int itemCount;
  final EdgeInsetsGeometry padding;

  const ShimmerListSkeleton({
    super.key,
    this.itemCount = 6,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 16),
  });

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.builder(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: itemCount,
        itemBuilder: (context, i) => const ShimmerListRow(),
      ),
    );
  }
}

/// Skeleton for the order-tracking screen while the Firestore stream's
/// first snapshot hasn't arrived yet.
class OrderTrackingSkeleton extends StatelessWidget {
  const OrderTrackingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerBox(height: 16, width: 160, radius: 4),
            const SizedBox(height: 6),
            const ShimmerBox(height: 12, width: 100, radius: 4),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line, width: 1),
              ),
              child: Column(
                children: List.generate(
                  4,
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ShimmerCircle(size: 28),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              ShimmerBox(height: 13, width: 140, radius: 4),
                              SizedBox(height: 6),
                              ShimmerBox(height: 10, width: 90, radius: 4),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const ShimmerListRow(),
            const ShimmerListRow(),
          ],
        ),
      ),
    );
  }
}
