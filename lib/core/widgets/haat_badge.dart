import 'package:flutter/material.dart';

/// Signature brand mark — renders the exact GaonHaat logo asset so the
/// in-app badge always matches the app icon pixel-for-pixel, instead of
/// approximating it with a built-in icon.
class HaatBadge extends StatelessWidget {
  final double size;

  const HaatBadge({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/gaonhaat_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
