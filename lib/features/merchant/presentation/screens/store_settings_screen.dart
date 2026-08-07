import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/merchant_provider.dart';

/// Lets an approved seller edit their shop name, description, and prep
/// time. KYC fields (Aadhaar, bank details, address) are intentionally
/// not editable here — they're locked once approved, both by Firestore
/// rules and by not offering the fields in this screen.
class StoreSettingsScreen extends StatefulWidget {
  const StoreSettingsScreen({super.key});

  @override
  State<StoreSettingsScreen> createState() => _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends State<StoreSettingsScreen> {
  late final TextEditingController _shopNameCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _prepMinutesCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final application = context.read<MerchantProvider>().application;
    _shopNameCtrl = TextEditingController(text: application?.shopName ?? '');
    _descriptionCtrl = TextEditingController(text: application?.description ?? '');
    _prepMinutesCtrl = TextEditingController(text: (application?.prepMinutes ?? 15).toString());
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _descriptionCtrl.dispose();
    _prepMinutesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final strings = context.read<LocaleProvider>().strings;
    final shopName = _shopNameCtrl.text.trim();
    final prepMinutes = int.tryParse(_prepMinutesCtrl.text.trim());

    if (shopName.isEmpty || prepMinutes == null || prepMinutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings.fieldRequiredError)));
      return;
    }

    setState(() => _saving = true);
    final ok = await context.read<MerchantProvider>().updateStoreSettings(
          shopName: shopName,
          description: _descriptionCtrl.text.trim(),
          prepMinutes: prepMinutes,
        );
    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? strings.settingsSavedMessage : strings.settingsSaveFailedMessage)),
    );
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleProvider>().strings;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: Text(strings.storeSettings, style: AppTextStyles.display(fontSize: 18)),
        iconTheme: const IconThemeData(color: AppColors.charcoal),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            _Field(label: strings.shopNameLabel, controller: _shopNameCtrl),
            const SizedBox(height: 16),
            _Field(
              label: strings.shopDescriptionLabel,
              controller: _descriptionCtrl,
              hint: strings.shopDescriptionHint,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _Field(
              label: strings.prepMinutesLabel,
              controller: _prepMinutesCtrl,
              hint: strings.prepMinutesHint,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(strings.saveButton,
                        style: AppTextStyles.body(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;

  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: AppTextStyles.body(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.caption(fontSize: 13, color: AppColors.mutedDark),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.green, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
