import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../providers/addresses_provider.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AddressesProvider>().load();
    });
  }

  Future<void> _addAddress() async {
    final strings = context.read<LocaleProvider>().strings;
    final labelCtrl = TextEditingController();
    DetectedLocation? detected;
    bool detecting = false;
    String? error;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Future<void> detect() async {
            setSheetState(() {
              detecting = true;
              error = null;
            });
            try {
              final result = await LocationService.detectCurrentLocation();
              setSheetState(() {
                detected = result;
                detecting = false;
              });
            } catch (_) {
              setSheetState(() {
                detecting = false;
                error = strings.locationUnknownError;
              });
            }
          }

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(strings.addAddressTitle, style: AppTextStyles.display(fontSize: 18)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: labelCtrl,
                    style: AppTextStyles.body(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: strings.addressLabelHint,
                      filled: true,
                      fillColor: AppColors.cream,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (detected != null)
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: AppColors.green, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(detected!.label, style: AppTextStyles.caption(fontSize: 12)),
                        ),
                      ],
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: detecting ? null : detect,
                      icon: detecting
                          ? const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green),
                            )
                          : const Icon(Icons.my_location, size: 16),
                      label: Text(detecting ? strings.detectingLocation : strings.detectLocationButton,
                          style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.green)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.green)),
                    ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: AppTextStyles.caption(fontSize: 12, color: Colors.red)),
                  ],
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: strings.saveAddressButton,
                    trailingIcon: null,
                    enabled: labelCtrl.text.trim().isNotEmpty || true,
                    onPressed: () {
                      if (labelCtrl.text.trim().isEmpty || detected == null) {
                        setSheetState(() => error = strings.addressIncompleteError);
                        return;
                      }
                      Navigator.of(sheetContext).pop();
                      context.read<AddressesProvider>().add(SavedAddress(
                            id: DateTime.now().microsecondsSinceEpoch.toString(),
                            label: labelCtrl.text.trim(),
                            lat: detected!.latitude,
                            lng: detected!.longitude,
                            detectedLabel: detected!.label,
                          ));
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleProvider>().strings;
    final addressesProvider = context.watch<AddressesProvider>();
    final addresses = addressesProvider.addresses;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: Text(strings.myAddresses, style: AppTextStyles.display(fontSize: 18)),
        iconTheme: const IconThemeData(color: AppColors.charcoal),
      ),
      body: SafeArea(
        child: addressesProvider.isLoading
            ? const ShimmerListSkeleton()
            : addresses.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 48, color: AppColors.inactive),
                    const SizedBox(height: 12),
                    Text(strings.noAddressesTitle, style: AppTextStyles.display(fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(strings.noAddressesSubtitle, style: AppTextStyles.caption(fontSize: 13)),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                itemCount: addresses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final a = addresses[i];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.line, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: AppColors.green, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.label, style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w700)),
                              Text(a.detectedLabel, style: AppTextStyles.caption(fontSize: 12)),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => context.read<AddressesProvider>().remove(a.id),
                          icon: const Icon(Icons.delete_outline, color: Color(0xFFC0453B), size: 20),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addAddress,
        backgroundColor: AppColors.green,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(strings.addAddressTitle, style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
      ),
    );
  }
}
