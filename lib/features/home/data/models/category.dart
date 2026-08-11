import 'package:flutter/material.dart';
import '../../../../core/localization/app_strings.dart';

/// A product category (Vegetables, Fruits, ...). Bilingual names live
/// directly on the model — this is how a real backend document would
/// look too, so swapping the data source later needs no UI changes.
class Category {
  final String id;
  final String nameHi;
  final String nameEn;
  final IconData icon;
  final Color color;
  final String? imageUrl;

  const Category({
    required this.id,
    required this.nameHi,
    required this.nameEn,
    required this.icon,
    required this.color,
    this.imageUrl,
  });

  String name(AppLanguage language) => language == AppLanguage.hindi ? nameHi : nameEn;
}
