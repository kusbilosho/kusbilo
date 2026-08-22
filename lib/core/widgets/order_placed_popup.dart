import 'package:flutter/material.dart';
import '../../features/order/data/models/order.dart';
import '../../features/order/presentation/screens/order_tracking_screen.dart';
import '../localization/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'primary_button.dart';

/// Shows the order-success moment as a centered popup card over the
/// checkout screen (checkmark, order id, ETA) instead of navigating to
/// a brand new full page. The checkout screen stays underneath so the
/// transition feels like a confirmation, not a page change.
///
/// Dismissing (via a button) pops the popup, then hands control back to
/// the caller via [onContinueShopping] / navigates to order tracking.
Future<void> showOrderPlacedPopup(
  BuildContext context, {
  required Order order,
  required AppStrings strings,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.45),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, _, __) => const SizedBox.shrink(),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
      return Opacity(
        opacity: animation.value.clamp(0, 1),
        child: Transform.scale(
          scale: 0.85 + (0.15 * curved.value.clamp(0.0, 1.0)),
          child: _OrderPlacedCard(order: order, strings: strings),
        ),
      );
    },
  );
}

class _OrderPlacedCard extends StatelessWidget {
  final Order order;
  final AppStrings strings;
  const _OrderPlacedCard({required this.order, required this.strings});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(color: AppColors.sage, shape: BoxShape.circle),
              child: const Icon(Icons.check_circle, color: AppColors.green, size: 48),
            ),
            const SizedBox(height: 20),
            Text(strings.orderPlacedTitle, style: AppTextStyles.display(fontSize: 20), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(strings.orderPlacedSubtitle,
                style: AppTextStyles.caption(fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 14),
            Text(strings.orderIdLabel(order.id.substring(0, 8).toUpperCase()),
                style: AppTextStyles.caption(fontSize: 12, color: AppColors.mutedDark)),
            if (order.etaMinutes != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: AppColors.sage, borderRadius: BorderRadius.circular(20)),
                child: Text(strings.etaMinutesLabel(order.etaMinutes!),
                    style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.green)),
              ),
            ],
            const SizedBox(height: 28),
            PrimaryButton(
              label: strings.continueShoppingButton,
              trailingIcon: null,
              onPressed: () => Navigator.of(context)
                ..pop()
                ..popUntil((route) => route.isFirst),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: order.id)),
                  );
                },
                icon: const Icon(Icons.map_outlined, size: 16),
                label: Text(strings.trackOrderButton),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.green),
                  foregroundColor: AppColors.green,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
