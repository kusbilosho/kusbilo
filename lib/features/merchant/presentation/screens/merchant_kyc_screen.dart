import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/haat_badge.dart';
import '../../../../core/widgets/lang_toggle.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/models/kyc_application.dart';
import '../providers/merchant_provider.dart';
import 'seller_dashboard_screen.dart';

/// Single entry point for the "Become a Merchant" flow. Shows whichever
/// state applies right now: the KYC form (not applied / rejected-retry),
/// or a status message (pending / approved). One screen, one source of
/// truth (MerchantProvider.status) — no separate navigation per state.
class MerchantEntryScreen extends StatelessWidget {
  const MerchantEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.watch<MerchantProvider>().status;

    switch (status) {
      case KycStatus.notApplied:
        return const _KycFormScreen();
      case KycStatus.rejected:
        return const _KycRejectedScreen();
      case KycStatus.pending:
        return const _KycPendingScreen();
      case KycStatus.approved:
        return const SellerDashboardScreen();
    }
  }
}

class _KycRejectedScreen extends StatelessWidget {
  const _KycRejectedScreen();

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleProvider>().strings;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Icon(Icons.arrow_back_rounded, size: 22, color: AppColors.green),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: const Color(0xFFC0453B).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded, size: 40, color: Color(0xFFC0453B)),
              ),
              const SizedBox(height: 22),
              Text(strings.kycRejectedTitle, textAlign: TextAlign.center, style: AppTextStyles.display(fontSize: 20)),
              const SizedBox(height: 10),
              Text(strings.kycRejectedSubtitle,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption(fontSize: 14, color: AppColors.mutedDark)),
              const Spacer(),
              PrimaryButton(
                label: strings.reapplyButton,
                onPressed: () => context.read<MerchantProvider>().resetToNotApplied(),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _KycFormScreen extends StatefulWidget {
  const _KycFormScreen();

  @override
  State<_KycFormScreen> createState() => _KycFormScreenState();
}

class _KycFormScreenState extends State<_KycFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _shopNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _aadhaarCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _villageCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _bankAccountCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();

  bool _submitting = false;
  DetectedLocation? _shopLocation;
  bool _detectingLocation = false;
  String? _locationError;

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _aadhaarCtrl.dispose();
    _panCtrl.dispose();
    _addressCtrl.dispose();
    _villageCtrl.dispose();
    _districtCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    _bankAccountCtrl.dispose();
    _ifscCtrl.dispose();
    super.dispose();
  }

  Future<void> _detectShopLocation() async {
    final strings = context.read<LocaleProvider>().strings;
    setState(() {
      _detectingLocation = true;
      _locationError = null;
    });
    try {
      final result = await LocationService.detectCurrentLocation();
      if (!mounted) return;
      setState(() {
        _shopLocation = result;
        _detectingLocation = false;
      });
    } on LocationFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _detectingLocation = false;
        _locationError = switch (e.reason) {
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
        _detectingLocation = false;
        _locationError = strings.locationUnknownError;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_shopLocation == null) {
      final strings = context.read<LocaleProvider>().strings;
      setState(() => _locationError = strings.shopLocationRequiredError);
      return;
    }

    setState(() => _submitting = true);

    final application = KycApplication(
      shopName: _shopNameCtrl.text.trim(),
      ownerName: _ownerNameCtrl.text.trim(),
      aadhaarNumber: _aadhaarCtrl.text.trim(),
      panNumber: _panCtrl.text.trim().isEmpty ? null : _panCtrl.text.trim().toUpperCase(),
      address: _addressCtrl.text.trim(),
      village: _villageCtrl.text.trim(),
      district: _districtCtrl.text.trim(),
      state: _stateCtrl.text.trim(),
      pincode: _pincodeCtrl.text.trim(),
      bankAccountNumber: _bankAccountCtrl.text.trim(),
      ifscCode: _ifscCtrl.text.trim().toUpperCase(),
      shopLat: _shopLocation!.latitude,
      shopLng: _shopLocation!.longitude,
    );

    await context.read<MerchantProvider>().submitKyc(application);

    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleProvider>().strings;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
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
                      const HaatBadge(size: 30),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(strings.kycFormTitle, style: AppTextStyles.display(fontSize: 18)),
                      ),
                      const LangToggle(),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _SectionLabel(strings.businessInfoSection),
                    const SizedBox(height: 10),
                    _KycField(
                      controller: _shopNameCtrl,
                      label: strings.shopNameLabel,
                      requiredError: strings.fieldRequiredError,
                    ),
                    const SizedBox(height: 12),
                    _KycField(
                      controller: _ownerNameCtrl,
                      label: strings.ownerNameLabel,
                      requiredError: strings.fieldRequiredError,
                    ),
                    const SizedBox(height: 12),
                    _KycField(
                      controller: _aadhaarCtrl,
                      label: strings.aadhaarLabel,
                      requiredError: strings.fieldRequiredError,
                      keyboardType: TextInputType.number,
                      maxLength: 12,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      customValidator: (v) =>
                          v!.length == 12 ? null : strings.aadhaarInvalidError,
                    ),
                    const SizedBox(height: 12),
                    _KycField(
                      controller: _panCtrl,
                      label: strings.panLabel,
                      requiredError: strings.fieldRequiredError,
                      isOptional: true,
                      maxLength: 10,
                      textCapitalization: TextCapitalization.characters,
                      customValidator: (v) {
                        if (v!.isEmpty) return null;
                        final ok = RegExp(r'^[A-Za-z]{5}[0-9]{4}[A-Za-z]$').hasMatch(v);
                        return ok ? null : strings.panInvalidError;
                      },
                    ),
                    const SizedBox(height: 24),
                    _SectionLabel(strings.addressSection),
                    const SizedBox(height: 10),
                    _KycField(
                      controller: _addressCtrl,
                      label: strings.addressLabel,
                      requiredError: strings.fieldRequiredError,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    _KycField(
                      controller: _villageCtrl,
                      label: strings.villageLabel,
                      requiredError: strings.fieldRequiredError,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _KycField(
                            controller: _districtCtrl,
                            label: strings.districtLabel,
                            requiredError: strings.fieldRequiredError,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _KycField(
                            controller: _stateCtrl,
                            label: strings.stateLabel,
                            requiredError: strings.fieldRequiredError,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _KycField(
                      controller: _pincodeCtrl,
                      label: strings.pincodeLabel,
                      requiredError: strings.fieldRequiredError,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      customValidator: (v) => v!.length == 6 ? null : strings.pincodeInvalidError,
                    ),
                    const SizedBox(height: 24),
                    _SectionLabel(strings.shopLocationSection),
                    const SizedBox(height: 6),
                    Text(strings.shopLocationHelper, style: AppTextStyles.caption(fontSize: 12)),
                    const SizedBox(height: 10),
                    if (_shopLocation != null)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.line, width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.storefront_rounded, color: AppColors.green, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_shopLocation!.label,
                                  style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w600)),
                            ),
                            TextButton(
                              onPressed: _detectingLocation ? null : _detectShopLocation,
                              child: Text(strings.changeLocation,
                                  style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.green)),
                            ),
                          ],
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _detectingLocation ? null : _detectShopLocation,
                          icon: _detectingLocation
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green),
                                )
                              : const Icon(Icons.my_location, size: 18),
                          label: Text(_detectingLocation ? strings.detectingLocation : strings.detectLocationButton,
                              style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.green)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.green),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    if (_locationError != null) ...[
                      const SizedBox(height: 8),
                      Text(_locationError!, style: AppTextStyles.caption(fontSize: 12, color: Colors.red)),
                    ],
                    const SizedBox(height: 24),
                    _SectionLabel(strings.bankDetailsSection),
                    const SizedBox(height: 10),
                    _KycField(
                      controller: _bankAccountCtrl,
                      label: strings.bankAccountLabel,
                      requiredError: strings.fieldRequiredError,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      customValidator: (v) =>
                          v!.length >= 9 && v.length <= 18 ? null : strings.bankAccountInvalidError,
                    ),
                    const SizedBox(height: 12),
                    _KycField(
                      controller: _ifscCtrl,
                      label: strings.ifscLabel,
                      requiredError: strings.fieldRequiredError,
                      maxLength: 11,
                      textCapitalization: TextCapitalization.characters,
                      customValidator: (v) {
                        final ok = RegExp(r'^[A-Za-z]{4}0[A-Za-z0-9]{6}$').hasMatch(v!);
                        return ok ? null : strings.ifscInvalidError;
                      },
                    ),
                    const SizedBox(height: 28),
                    PrimaryButton(
                      label: strings.submitKycButton,
                      enabled: !_submitting,
                      onPressed: _submit,
                    ),
                    if (_submitting) ...[
                      const SizedBox(height: 12),
                      const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.green),
                        ),
                      ),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KycPendingScreen extends StatelessWidget {
  const _KycPendingScreen();

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleProvider>().strings;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Icon(Icons.arrow_back_rounded, size: 22, color: AppColors.green),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.mustard.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hourglass_top_rounded, size: 40, color: AppColors.mustard),
              ),
              const SizedBox(height: 22),
              Text(strings.kycPendingTitle, textAlign: TextAlign.center, style: AppTextStyles.display(fontSize: 20)),
              const SizedBox(height: 10),
              Text(strings.kycPendingSubtitle,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption(fontSize: 14, color: AppColors.mutedDark)),
              const Spacer(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: AppTextStyles.caption(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted));
  }
}

/// Shared text field styling for the KYC form, with an optional custom
/// validator layered on top of the standard required-field check.
class _KycField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String requiredError;
  final String? Function(String?)? customValidator;
  final bool isOptional;
  final TextInputType? keyboardType;
  final int? maxLength;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  const _KycField({
    required this.controller,
    required this.label,
    required this.requiredError,
    this.customValidator,
    this.isOptional = false,
    this.keyboardType,
    this.maxLength,
    this.maxLines = 1,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      style: AppTextStyles.body(fontSize: 14),
      validator: (value) {
        final v = value ?? '';
        if (!isOptional && v.trim().isEmpty) return requiredError;
        if (customValidator != null) return customValidator!(v.trim());
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        labelStyle: AppTextStyles.caption(fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line, width: 1.4),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line, width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.green, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.4),
        ),
      ),
    );
  }
}
