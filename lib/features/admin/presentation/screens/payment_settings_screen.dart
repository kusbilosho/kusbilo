import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Lets an admin set the payment-gateway config that used to live only
/// as environment variables on the collection server — the merchant's
/// real UPI ID, display name, webhook secret, and the server's base URL
/// — all in one place (`settings/paymentGateway` in Firestore), editable
/// from the phone instead of a hosting dashboard. The collection server
/// itself (see the separate upi-payment-gateway repo) reads the same
/// document at request time, so a change here takes effect without a
/// redeploy.
class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  final _vpaCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();
  final _baseUrlCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _revealSecret = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _vpaCtrl.dispose();
    _nameCtrl.dispose();
    _secretCtrl.dispose();
    _baseUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('paymentGateway').get();
      final data = doc.data();
      if (data != null) {
        _vpaCtrl.text = data['merchantVpa'] as String? ?? '';
        _nameCtrl.text = data['merchantName'] as String? ?? '';
        _secretCtrl.text = data['webhookSecret'] as String? ?? '';
        _baseUrlCtrl.text = data['baseUrl'] as String? ?? '';
      }
    } catch (_) {
      // Leave fields blank — admin can still fill them in and save fresh.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final vpa = _vpaCtrl.text.trim();
    final baseUrl = _baseUrlCtrl.text.trim();
    if (vpa.isEmpty || !vpa.contains('@')) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a valid UPI ID, e.g. yourname@okaxis')));
      return;
    }
    if (baseUrl.isEmpty || !(baseUrl.startsWith('http://') || baseUrl.startsWith('https://'))) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter the full server URL, starting with https://')));
      return;
    }

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('settings').doc('paymentGateway').set({
        'merchantVpa': vpa,
        'merchantName': _nameCtrl.text.trim().isEmpty ? 'Gaonhaat' : _nameCtrl.text.trim(),
        'webhookSecret': _secretCtrl.text.trim(),
        'baseUrl': baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved ✅')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Couldn't save — check your connection and try again")));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: Text('Payment Settings', style: AppTextStyles.display(fontSize: 18)),
        iconTheme: const IconThemeData(color: AppColors.charcoal),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.green))
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.sage,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: AppColors.green),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Payments go straight to the UPI ID below — double-check it before saving. '
                            'The webhook secret must match what the SMS-forwarding app (e.g. MacroDroid) '
                            'sends on every request, or payments will never be confirmed.',
                            style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.charcoal),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _Field(label: 'Your UPI ID (VPA)', hint: 'yourname@okaxis', controller: _vpaCtrl),
                  const SizedBox(height: 14),
                  _Field(label: 'Display name shown to buyers', hint: 'Gaonhaat', controller: _nameCtrl),
                  const SizedBox(height: 14),
                  _Field(
                    label: 'Webhook secret',
                    hint: 'Long random string — also set in MacroDroid',
                    controller: _secretCtrl,
                    obscure: !_revealSecret,
                    trailing: IconButton(
                      icon: Icon(_revealSecret ? Icons.visibility_off : Icons.visibility, size: 20),
                      onPressed: () => setState(() => _revealSecret = !_revealSecret),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Field(
                    label: 'Server base URL',
                    hint: 'https://your-site.netlify.app',
                    controller: _baseUrlCtrl,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
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
  final String hint;
  final TextEditingController controller;
  final bool obscure;
  final Widget? trailing;

  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    this.obscure = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13, color: AppColors.mutedDark),
            suffixIcon: trailing,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.green, width: 1.5)),
          ),
        ),
      ],
    );
  }
}
