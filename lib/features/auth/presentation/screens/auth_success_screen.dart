import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/haat_badge.dart';
import '../../../../core/widgets/lang_toggle.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../providers/auth_flow_provider.dart';
import 'phone_login_screen.dart';

/// Final screen of the login flow — confirms the phone number was
/// verified, then auto-advances into the Home shell.
class AuthSuccessScreen extends StatefulWidget {
  const AuthSuccessScreen({super.key});

  @override
  State<AuthSuccessScreen> createState() => _AuthSuccessScreenState();
}

class _AuthSuccessScreenState extends State<AuthSuccessScreen> {
  Timer? _redirectTimer;

  @override
  void initState() {
    super.initState();
    _redirectTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShellScreen()),
        (route) => false,
      );
    });
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    super.dispose();
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
            children: [
              Align(alignment: Alignment.topRight, child: const LangToggle()),
              const Spacer(),
              const HaatBadge(size: 80),
              const SizedBox(height: 24),
              Text('${strings.welcomeTitle} 🎉', style: AppTextStyles.display(fontSize: 20)),
              const SizedBox(height: 8),
              Text(
                '+91 $phone ${strings.verifiedSuffix}',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption(fontSize: 14, color: AppColors.mutedDark),
              ),
              const SizedBox(height: 20),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.green),
              ),
              const SizedBox(height: 12),
              Text(
                strings.redirectingToHome,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption(fontSize: 12),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  _redirectTimer?.cancel();
                  context.read<AuthFlowProvider>().reset();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
                    (route) => false,
                  );
                },
                child: Text('↻ ${strings.restartLogin}',
                    style: AppTextStyles.body(
                        fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.green)),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}