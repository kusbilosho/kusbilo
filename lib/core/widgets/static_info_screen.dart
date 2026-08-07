import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// A single support-contact row (call/WhatsApp/email) or a plain
/// paragraph of body text — StaticInfoScreen renders a mixed list of
/// these so Help & Support, About Us, and Terms & Privacy can all share
/// one simple screen instead of three near-identical ones.
class StaticInfoSection {
  final String? heading;
  final String? body;
  final IconData? actionIcon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const StaticInfoSection({this.heading, this.body, this.actionIcon, this.actionLabel, this.onAction});
}

class StaticInfoScreen extends StatelessWidget {
  final String title;
  final List<StaticInfoSection> sections;

  const StaticInfoScreen({super.key, required this.title, required this.sections});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: Text(title, style: AppTextStyles.display(fontSize: 18)),
        iconTheme: const IconThemeData(color: AppColors.charcoal),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: sections.map((section) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (section.heading != null) ...[
                    Text(section.heading!, style: AppTextStyles.body(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                  ],
                  if (section.body != null) Text(section.body!, style: AppTextStyles.caption(fontSize: 13)),
                  if (section.onAction != null) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: section.onAction,
                      icon: Icon(section.actionIcon, size: 16),
                      label: Text(section.actionLabel ?? '',
                          style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.green)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.green,
                        side: const BorderSide(color: AppColors.green),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
