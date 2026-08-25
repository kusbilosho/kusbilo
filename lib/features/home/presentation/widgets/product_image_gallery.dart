import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fullscreen_image_viewer.dart';

/// Swipeable strip of every photo a seller uploaded for a product,
/// with dot indicators and tap-to-zoom. Shows the emoji placeholder
/// only when the seller hasn't added any photos at all — this widget
/// itself never caps how many images it can show.
class ProductImageGallery extends StatefulWidget {
  final List<String> imageUrls;
  final String emoji;
  final double height;

  const ProductImageGallery({
    super.key,
    required this.imageUrls,
    required this.emoji,
    this.height = 320,
  });

  @override
  State<ProductImageGallery> createState() => _ProductImageGalleryState();
}

class _ProductImageGalleryState extends State<ProductImageGallery> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.imageUrls;

    if (images.isEmpty) {
      return Container(
        height: widget.height,
        color: AppColors.sage,
        child: Center(child: Text(widget.emoji, style: const TextStyle(fontSize: 90))),
      );
    }

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => FullscreenImageViewer.open(context, images, i),
              child: Container(
                color: AppColors.sage,
                width: double.infinity,
                child: Image.network(
                  images[i],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Center(child: Text(widget.emoji, style: const TextStyle(fontSize: 90))),
                ),
              ),
            ),
          ),
          if (images.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(images.length, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active ? Colors.white : Colors.white70,
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                    ),
                  );
                }),
              ),
            ),
          // Small hint so buyers discover pinch-zoom on their own.
          Positioned(
            top: 12,
            left: 16,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
