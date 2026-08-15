import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../home/data/models/review.dart';
import '../../../profile/presentation/providers/user_profile_provider.dart';
import '../../data/models/order.dart';

/// Reached from a delivered/cancelled order in history — lets the buyer
/// rate each product in that order individually (1–5 stars + an
/// optional comment). Writes straight to
/// `products/{productId}/reviews/{buyerId}`, one doc per buyer per
/// product, so re-rating something just overwrites their previous
/// review instead of piling up duplicates. Only products left at 0
/// stars are skipped — the buyer doesn't have to rate every item in a
/// mixed order to submit the ones they do have an opinion on.
class RateOrderScreen extends StatefulWidget {
  final Order order;
  const RateOrderScreen({super.key, required this.order});

  @override
  State<RateOrderScreen> createState() => _RateOrderScreenState();
}

class _RateOrderScreenState extends State<RateOrderScreen> {
  final Map<String, int> _ratings = {};
  final Map<String, TextEditingController> _comments = {};
  bool _loadingExisting = true;
  bool _submitting = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    for (final item in widget.order.items) {
      _ratings[item.productId] = 0;
      _comments[item.productId] = TextEditingController();
    }
    _loadExisting();
  }

  @override
  void dispose() {
    for (final c in _comments.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final uid = _uid;
    if (uid == null) {
      setState(() => _loadingExisting = false);
      return;
    }
    // A buyer re-opening this after already rating some items should see
    // their previous stars/comment, not a blank form that looks like
    // nothing was saved.
    for (final item in widget.order.items) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('products')
            .doc(item.productId)
            .collection('reviews')
            .doc(uid)
            .get();
        if (doc.exists) {
          final review = Review.fromMap(doc.data()!);
          _ratings[item.productId] = review.rating;
          _comments[item.productId]!.text = review.comment;
        }
      } catch (_) {
        // Fine to leave this one blank — worst case the buyer re-rates it.
      }
    }
    if (mounted) setState(() => _loadingExisting = false);
  }

  Future<void> _submit() async {
    final uid = _uid;
    if (uid == null) return;

    setState(() => _submitting = true);
    final buyerName = context.read<UserProfileProvider>().name?.trim();
    final displayName =
        (buyerName != null && buyerName.isNotEmpty) ? buyerName : (FirebaseAuth.instance.currentUser?.phoneNumber ?? '');

    var savedCount = 0;
    for (final item in widget.order.items) {
      final rating = _ratings[item.productId] ?? 0;
      if (rating <= 0) continue; // Skip items the buyer chose not to rate.
      final review = Review(
        buyerId: uid,
        buyerName: displayName,
        rating: rating,
        comment: _comments[item.productId]!.text.trim(),
        createdAt: DateTime.now(),
      );
      try {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(item.productId)
            .collection('reviews')
            .doc(uid)
            .set(review.toMap());
        savedCount++;
      } catch (_) {
        // Move on to the next item rather than losing the whole batch
        // over one failed write.
      }
    }

    if (!mounted) return;
    setState(() => _submitting = false);
    final strings = context.read<LocaleProvider>().strings;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(savedCount > 0 ? strings.reviewSubmittedMessage : strings.reviewSubmitFailedMessage)),
    );
    if (savedCount > 0) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleProvider>().strings;
    final lang = context.watch<LocaleProvider>().language;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: Text(strings.rateOrderTitle, style: AppTextStyles.display(fontSize: 18)),
        iconTheme: const IconThemeData(color: AppColors.charcoal),
      ),
      body: _loadingExisting
          ? const Center(child: CircularProgressIndicator(color: AppColors.green))
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  for (final item in widget.order.items) ...[
                    _ProductRatingCard(
                      title: lang == AppLanguage.hindi ? item.nameHi : item.nameEn,
                      rating: _ratings[item.productId] ?? 0,
                      commentController: _comments[item.productId]!,
                      onRatingChanged: (r) => setState(() => _ratings[item.productId] = r),
                    ),
                    const SizedBox(height: 14),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(strings.submitReviewButton,
                              style: AppTextStyles.body(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ProductRatingCard extends StatelessWidget {
  final String title;
  final int rating;
  final TextEditingController commentController;
  final ValueChanged<int> onRatingChanged;

  const _ProductRatingCard({
    required this.title,
    required this.rating,
    required this.commentController,
    required this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (i) {
              final starIndex = i + 1;
              return GestureDetector(
                onTap: () => onRatingChanged(starIndex),
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    starIndex <= rating ? Icons.star_rounded : Icons.star_border_rounded,
                    color: starIndex <= rating ? AppColors.mustard : AppColors.inactive,
                    size: 30,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: commentController,
            maxLines: 2,
            style: AppTextStyles.body(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'कमेंट (वैकल्पिक)',
              hintStyle: AppTextStyles.caption(fontSize: 12),
              filled: true,
              fillColor: AppColors.cream,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }
}
