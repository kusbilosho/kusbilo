import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/admin_provider.dart';

/// Only reachable from a Profile menu row that's itself only shown to
/// users whose Cloud Function `checkIsAdmin` call returned true — see
/// HomeShellScreen's _ProfileTab. Every approve/reject action here goes
/// through the `reviewKycApplication` Cloud Function, never a direct
/// Firestore write, since that's what Firestore rules require anyway.
class AdminKycQueueScreen extends StatefulWidget {
  const AdminKycQueueScreen({super.key});

  @override
  State<AdminKycQueueScreen> createState() => _AdminKycQueueScreenState();
}

class _AdminKycQueueScreenState extends State<AdminKycQueueScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadPending();
    });
  }

  Future<void> _review(String uid, bool approve) async {
    final strings = context.read<LocaleProvider>().strings;
    final ok = await context.read<AdminProvider>().review(uid, approve: approve);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings.adminReviewFailed)));
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleProvider>().strings;
    final admin = context.watch<AdminProvider>();
    final pending = admin.pending;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: Text(strings.adminKycQueueTitle, style: AppTextStyles.display(fontSize: 18)),
        iconTheme: const IconThemeData(color: AppColors.charcoal),
      ),
      body: SafeArea(
        child: pending.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.fact_check_outlined, size: 48, color: AppColors.inactive),
                    const SizedBox(height: 12),
                    Text(strings.adminNoPendingTitle, style: AppTextStyles.display(fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(strings.adminNoPendingSubtitle, style: AppTextStyles.caption(fontSize: 13)),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () => context.read<AdminProvider>().loadPending(),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  itemCount: pending.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final app = pending[i];
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
                          Text(app.shopName, style: AppTextStyles.body(fontSize: 15, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(app.ownerName, style: AppTextStyles.caption(fontSize: 13)),
                          const SizedBox(height: 2),
                          Text('${app.village}, ${app.district}', style: AppTextStyles.caption(fontSize: 12)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: admin.isBusy ? null : () => _review(app.uid, false),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFC0453B)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: Text(strings.adminRejectButton,
                                      style: AppTextStyles.body(
                                          fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFC0453B))),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: admin.isBusy ? null : () => _review(app.uid, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: Text(strings.adminApproveButton,
                                      style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
