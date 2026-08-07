import 'dart:async';
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
import 'auth_success_screen.dart';

/// Real 6-digit OTP entry: typing a digit auto-advances focus, backspace on
/// an empty box moves focus back, Verify only enables once all boxes are
/// filled, and Resend has a 30-second cooldown before it becomes tappable.
///
/// IMPORTANT: each box needs TWO focus nodes — one for the TextField
/// (handles tap-to-open-keyboard) and a SEPARATE one for the KeyboardListener
/// that catches the backspace key. Giving both the SAME FocusNode crashes
/// Flutter ("Tried to make a child into a parent of itself"). Both node
/// lists are created ONCE as fields and properly disposed.
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  static const int _resendCooldownSeconds = 30;

  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final List<FocusNode> _keyListenerNodes =
      List.generate(6, (_) => FocusNode(skipTraversal: true));

  Timer? _resendTimer;
  int _secondsLeft = _resendCooldownSeconds;
  bool _isResending = false;

  bool get _isFilled => _controllers.every((c) => c.text.isNotEmpty);
  bool get _canResend => _secondsLeft <= 0;

  @override
  void initState() {
    super.initState();
    _startResendCooldown();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    for (final f in _keyListenerNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _secondsLeft = _resendCooldownSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  Future<void> _onResendTap() async {
    if (!_canResend || _isResending) return;
    setState(() => _isResending = true);

    final ok = await context.read<AuthFlowProvider>().resendOtp();

    if (!mounted) return;
    setState(() => _isResending = false);

    if (ok) {
      for (final c in _controllers) {
        c.clear();
      }
      setState(() {});
      _focusNodes[0].requestFocus();
      _startResendCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.read<LocaleProvider>().strings.otpResent),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _onChanged(int index, String value) {
    setState(() {});
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
  }

  void _onKey(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verify() async {
    if (!_isFilled) return;
    final smsCode = _controllers.map((c) => c.text).join();
    final ok = await context.read<AuthFlowProvider>().verifyOtp(smsCode);
    if (ok && context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthSuccessScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleProvider>().strings;
    final phone = context.watch<AuthFlowProvider>().phoneNumber;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18, color: AppColors.green),
                    label: Text(strings.back,
                        style: AppTextStyles.body(
                            fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.green)),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  ),
                  const LangToggle(),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: Column(
                  children: [
                    const HaatBadge(size: 60),
                    const SizedBox(height: 18),
                    Text(strings.otpTitle, style: AppTextStyles.display(fontSize: 20)),
                    const SizedBox(height: 6),
                    Text(
                      '${strings.otpSubtext}\n+91 $phone',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption(fontSize: 14, color: AppColors.mutedDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => _otpBox(i)),
              ),
              const SizedBox(height: 20),
              Center(child: _resendRow(strings)),
              const SizedBox(height: 28),
              PrimaryButton(
                label: strings.verifyButton,
                enabled: _isFilled && !context.watch<AuthFlowProvider>().isLoading,
                onPressed: _verify,
              ),
              if (context.watch<AuthFlowProvider>().isLoading) ...[
                const SizedBox(height: 12),
                const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.green),
                  ),
                ),
              ],
              if (context.watch<AuthFlowProvider>().errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  context.watch<AuthFlowProvider>().errorMessage!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption(fontSize: 13, color: Colors.red.shade700),
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resendRow(strings) {
    if (_isResending) {
      return SizedBox(
        height: 18,
        width: 18,
        child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.green),
      );
    }

    if (!_canResend) {
      return Text(
        '${strings.otpResendQuestion} ${strings.otpResend} (0:${_secondsLeft.toString().padLeft(2, '0')})',
        style: AppTextStyles.caption(fontSize: 14, color: AppColors.muted),
      );
    }

    return GestureDetector(
      onTap: _onResendTap,
      behavior: HitTestBehavior.opaque,
      child: RichText(
        text: TextSpan(
          style: AppTextStyles.caption(fontSize: 14),
          children: [
            TextSpan(text: '${strings.otpResendQuestion} '),
            TextSpan(
              text: strings.otpResend,
              style: const TextStyle(color: AppColors.mustard, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _otpBox(int index) {
    final bool filled = _controllers[index].text.isNotEmpty;
    return SizedBox(
      width: 46,
      height: 52,
      child: KeyboardListener(
        focusNode: _keyListenerNodes[index],
        onKeyEvent: (event) => _onKey(index, event),
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          autofocus: index == 0,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: AppTextStyles.body(fontSize: 18, fontWeight: FontWeight.w700),
          onChanged: (value) => _onChanged(index, value),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: filled ? AppColors.green : AppColors.line, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: filled ? AppColors.green : AppColors.line, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.green, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}
