import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_strings.dart';
import '../localization/locale_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Top-right pill switch to toggle between Hindi and English,
/// matching the pattern used by large consumer apps.
class LangToggle extends StatelessWidget {
  const LangToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pill(context, label: 'हिं', lang: AppLanguage.hindi, current: locale.language),
          _pill(context, label: 'EN', lang: AppLanguage.english, current: locale.language),
        ],
      ),
    );
  }

  Widget _pill(
    BuildContext context, {
    required String label,
    required AppLanguage lang,
    required AppLanguage current,
  }) {
    final bool selected = lang == current;
    return GestureDetector(
      onTap: () => context.read<LocaleProvider>().setLanguage(lang),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.green : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.cream : AppColors.muted,
          ),
        ),
      ),
    );
  }
}
