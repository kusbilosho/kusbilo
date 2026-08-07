import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/models/order.dart';
import 'order_tracking_screen.dart';

/// Shown right after a successful [OrderProvider.placeOrder] call.
/// Replaces the checkout screen in the nav stack (pushReplacement) so
/// the back button doesn't return to a now-stale checkout form.
class OrderSuccessScreen extends StatelessWidget {
  final Order order;
  const OrderSuccessScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleProvider>().strings;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(color: AppColors.sage, shape: BoxShape.circle),
                child: const Icon(Icons.check_circle, color: AppColors.green, size: 56),
              ),
              const SizedBox(height: 24),
              Text(strings.orderPlacedTitle, style: AppTextStyles.display(fontSize: 22), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(strings.orderPlacedSubtitle,
                  style: AppTextStyles.caption(fontSize: 14), textAlign: TextAlign.center),
              const SizedBox(height: 16),
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
              const SizedBox(height: 36),
              PrimaryButton(
                label: strings.continueShoppingButton,
                trailingIcon: null,
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: order.id)),
                  ),
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
      ),
    );
  }
}
