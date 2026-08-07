import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/haat_badge.dart';
import '../../../../core/widgets/lang_toggle.dart';
import '../../../../core/widgets/primary_button.dart';
import '../providers/auth_flow_provider.dart';
import 'otp_verification_screen.dart';

/// First screen of the login flow. Fully functional: typing updates state,
/// the button enables only for a valid 10-digit number, and pressing it
/// really navigates to the OTP screen with that number carried forward.
class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleProvider>().strings;
    final authFlow = context.watch<AuthFlowProvider>();

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: const LangToggle(),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    const HaatBadge(),
                    const SizedBox(height: 20),
                    Text(strings.appName, style: AppTextStyles.display(fontSize: 26)),
                    const SizedBox(height: 4),
                    Text(
                      strings.tagline,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption(fontSize: 14, color: AppColors.mutedDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Text(strings.loginHeading,
                  style: AppTextStyles.body(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(strings.loginSubtext, style: AppTextStyles.caption(fontSize: 14)),
              const SizedBox(height: 24),
              _PhoneField(
                controller: _controller,
                focusNode: _focusNode,
                hint: strings.phoneHint,
                isValid: authFlow.isPhoneValid,
                onChanged: (value) =>
                    context.read<AuthFlowProvider>().setPhoneNumber(value),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: strings.continueButton,
                enabled: authFlow.isPhoneValid && !authFlow.isLoading,
                onPressed: () async {
                  _focusNode.unfocus();
                  final sent = await context.read<AuthFlowProvider>().sendOtp();
                  if (sent && context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const OtpVerificationScreen()),
                    );
                  }
                },
              ),
              if (authFlow.isLoading) ...[
                const SizedBox(height: 12),
                const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.green),
                  ),
                ),
              ],
              if (authFlow.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  authFlow.errorMessage!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption(fontSize: 13, color: Colors.red.shade700),
                ),
              ],
              const SizedBox(height: 20),
              Text.rich(
                TextSpan(
                  style: AppTextStyles.caption(fontSize: 12, color: AppColors.muted),
                  children: [
                    TextSpan(text: '${strings.termsPrefix} '),
                    TextSpan(
                      text: strings.termsOfService,
                      style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: ' ${strings.termsMiddle} '),
                    TextSpan(
                      text: strings.privacyPolicy,
                      style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: ' ${strings.termsSuffix}'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool isValid;
  final ValueChanged<String> onChanged;

  const _PhoneField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.isValid,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasText = controller.text.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isValid ? AppColors.green : (hasText ? AppColors.line : AppColors.line),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.phone_rounded, size: 16, color: AppColors.green),
                const SizedBox(width: 6),
                Text('+91',
                    style: AppTextStyles.body(fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Container(
            height: 22,
            width: 1.5,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: AppColors.line,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              onChanged: onChanged,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppTextStyles.body(fontSize: 16, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppTextStyles.body(fontSize: 16, color: AppColors.muted),
                border: InputBorder.none,
                counterText: '',
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
