import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/upi_payment_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/order_placed_popup.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../home/data/catalog_provider.dart';
import '../../../order/data/models/order_item.dart';
import '../../../order/presentation/providers/order_provider.dart';

enum _PaymentMethod { cod, upi }

/// Reached from the Cart tab's "Checkout" button. Buyer never types an
/// address by hand — a single button detects GPS location and reverse-
/// geocodes it, since most people in Gao's target villages can't
/// reliably fill in a manual address form. Payment is either Cash on
/// Delivery, or UPI paid up front through our own collection server
/// (see UpiPaymentService) — the buyer picks either way.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  DetectedLocation? _location;
  bool _detecting = false;
  String? _errorText;
  _PaymentMethod _paymentMethod = _PaymentMethod.cod;

  // Only meaningful while _paymentMethod == upi and a payment attempt is
  // in flight — drives the "opening app / waiting for confirmation"
  // messaging so the buyer isn't just staring at a spinner with no idea
  // what's happening (their money may already be mid-transfer).
  bool _upiInProgress = false;
  String? _upiStatusText;

  Future<void> _detectLocation() async {
    final strings = context.read<LocaleProvider>().strings;
    setState(() {
      _detecting = true;
      _errorText = null;
    });
    try {
      final result = await LocationService.detectCurrentLocation();
      if (!mounted) return;
      setState(() {
        _location = result;
        _detecting = false;
      });
    } on LocationFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _detecting = false;
        _errorText = switch (e.reason) {
          LocationFailureReason.serviceDisabled => strings.locationServiceDisabledError,
          LocationFailureReason.permissionDenied => strings.locationPermissionDeniedError,
          LocationFailureReason.permissionDeniedForever =>
            strings.locationPermissionDeniedForeverError,
          LocationFailureReason.unknown => strings.locationUnknownError,
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _detecting = false;
        _errorText = strings.locationUnknownError;
      });
    }
  }

  Future<void> _placeOrder({String paymentStatus = 'cod', String? gatewayOrderId}) async {
    final cart = context.read<CartProvider>();
    final catalog = context.read<CatalogProvider>();
    final orderProvider = context.read<OrderProvider>();
    final strings = context.read<LocaleProvider>().strings;

    final items = cart.quantities.entries
        .map((e) => (product: catalog.productById(e.key), qty: e.value))
        .where((entry) => entry.product != null)
        .map((entry) => OrderItem(
              productId: entry.product!.id,
              nameHi: entry.product!.nameHi,
              nameEn: entry.product!.nameEn,
              priceValue: entry.product!.priceValue,
              unit: entry.product!.unit,
              quantity: entry.qty,
            ))
        .toList();

    final order = await orderProvider.placeOrder(
      items: items,
      deliveryLat: _location!.latitude,
      deliveryLng: _location!.longitude,
      deliveryAddressLabel: _location!.label,
      paymentMethod: _paymentMethod == _PaymentMethod.upi ? 'upi' : 'cod',
      paymentStatus: paymentStatus,
      gatewayOrderId: gatewayOrderId,
    );

    if (!mounted) return;
    if (order == null) {
      setState(() => _errorText = strings.locationUnknownError);
      return;
    }

    cart.clear();
    await showOrderPlacedPopup(context, order: order, strings: strings);
  }

  Future<void> _handlePlaceOrderPressed(int total) async {
    final strings = context.read<LocaleProvider>().strings;
    if (_location == null) {
      setState(() => _errorText = strings.addressRequiredError);
      return;
    }

    if (_paymentMethod == _PaymentMethod.cod) {
      await _placeOrder();
      return;
    }

    // UPI path: collect the money first, only place the order once the
    // webhook has actually confirmed it — an order should never exist
    // in "confirmed but unpaid" limbo for an online-payment choice.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    setState(() {
      _upiInProgress = true;
      _errorText = null;
      _upiStatusText = strings.upiPaymentOpeningApp;
    });

    final payment = await UpiPaymentService.pay(amount: total, userId: uid ?? 'unknown');

    if (!mounted) return;

    if (payment.result == UpiPaymentResult.notConfigured) {
      setState(() {
        _upiInProgress = false;
        _upiStatusText = null;
        _errorText = strings.upiPaymentNotConfigured;
      });
      return;
    }

    if (payment.result == UpiPaymentResult.failed) {
      setState(() {
        _upiInProgress = false;
        _upiStatusText = null;
        _errorText = strings.upiPaymentFailed;
      });
      return;
    }

    if (payment.result == UpiPaymentResult.timedOut) {
      setState(() {
        _upiInProgress = false;
        _upiStatusText = null;
        _errorText = strings.upiPaymentTimedOut;
      });
      return;
    }

    // Success.
    setState(() => _upiStatusText = strings.upiPaymentSuccess);
    await _placeOrder(paymentStatus: 'paid', gatewayOrderId: payment.gatewayOrderId);
    if (!mounted) return;
    setState(() => _upiInProgress = false);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleProvider>().strings;
    final lang = context.watch<LocaleProvider>().language;
    final cart = context.watch<CartProvider>();
    final catalog = context.watch<CatalogProvider>();
    final isPlacing = context.watch<OrderProvider>().isPlacing;

    final cartItems = cart.quantities.entries
        .map((e) => (product: catalog.productById(e.key), qty: e.value))
        .where((entry) => entry.product != null)
        .map((entry) => (product: entry.product!, qty: entry.qty))
        .toList();

    final total = cartItems.fold<int>(0, (sum, item) => sum + item.product.priceValue * item.qty);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: Text(strings.checkoutTitle, style: AppTextStyles.display(fontSize: 18)),
        iconTheme: const IconThemeData(color: AppColors.charcoal),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                children: [
                  Text(strings.deliveryAddressSection, style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  _LocationCard(
                    location: _location,
                    detecting: _detecting,
                    errorText: _errorText,
                    strings: strings,
                    onDetect: _detectLocation,
                  ),
                  const SizedBox(height: 24),
                  Text(strings.orderSummarySection, style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  ...cartItems.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Text(item.product.emoji, style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${item.product.name(lang)} × ${item.qty}',
                                style: AppTextStyles.body(fontSize: 14),
                              ),
                            ),
                            Text('₹${item.product.priceValue * item.qty}',
                                style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )),
                  const Divider(height: 24, color: AppColors.line),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(strings.totalLabel, style: AppTextStyles.body(fontSize: 15, fontWeight: FontWeight.w700)),
                      Text('₹$total', style: AppTextStyles.display(fontSize: 20)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(strings.paymentMethodSection, style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  _PaymentMethodOption(
                    icon: Icons.payments_outlined,
                    title: strings.paymentMethodCod,
                    subtitle: strings.paymentMethodCodSubtitle,
                    selected: _paymentMethod == _PaymentMethod.cod,
                    onTap: _upiInProgress
                        ? null
                        : () => setState(() {
                              _paymentMethod = _PaymentMethod.cod;
                              _errorText = null;
                            }),
                  ),
                  const SizedBox(height: 10),
                  _PaymentMethodOption(
                    icon: Icons.qr_code_2,
                    title: strings.paymentMethodUpi,
                    subtitle: strings.paymentMethodUpiSubtitle,
                    selected: _paymentMethod == _PaymentMethod.upi,
                    onTap: _upiInProgress
                        ? null
                        : () => setState(() {
                              _paymentMethod = _PaymentMethod.upi;
                              _errorText = null;
                            }),
                  ),
                  if (_upiStatusText != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.sage,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          if (_upiInProgress) ...[
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green),
                            ),
                            const SizedBox(width: 10),
                          ] else
                            const Icon(Icons.check_circle, size: 18, color: AppColors.green),
                          Expanded(
                            child: Text(_upiStatusText!, style: AppTextStyles.caption(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.line, width: 1)),
              ),
              child: SafeArea(
                top: false,
                child: PrimaryButton(
                  label: (isPlacing || _upiInProgress) ? strings.placingOrder : strings.placeOrderButton,
                  enabled: !isPlacing && !_upiInProgress && cartItems.isNotEmpty,
                  trailingIcon: null,
                  onPressed: () => _handlePlaceOrderPressed(total),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  const _PaymentMethodOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.sage : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.green : AppColors.line, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: selected ? AppColors.green : AppColors.charcoal),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.caption(fontSize: 12)),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.green : AppColors.line,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final DetectedLocation? location;
  final bool detecting;
  final String? errorText;
  final dynamic strings;
  final VoidCallback onDetect;

  const _LocationCard({
    required this.location,
    required this.detecting,
    required this.errorText,
    required this.strings,
    required this.onDetect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (location != null) ...[
            Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(location!.label,
                      style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(strings.locationDetected, style: AppTextStyles.caption(fontSize: 12, color: AppColors.green)),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: detecting ? null : onDetect,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(strings.changeLocation, style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.w600)),
              style: TextButton.styleFrom(foregroundColor: AppColors.green, padding: EdgeInsets.zero),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: detecting ? null : onDetect,
                icon: detecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green),
                      )
                    : const Icon(Icons.my_location, size: 18),
                label: Text(detecting ? strings.detectingLocation : strings.detectLocationButton,
                    style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.green)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.green),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
          if (errorText != null) ...[
            const SizedBox(height: 10),
            Text(errorText!, style: AppTextStyles.caption(fontSize: 12, color: Colors.red)),
          ],
        ],
      ),
    );
  }
}
