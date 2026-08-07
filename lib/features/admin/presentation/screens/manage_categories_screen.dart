import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../home/data/catalog_provider.dart';

/// (iconName, IconData, label) options an admin can pick from when adding
/// a category. iconName is what gets stored in Firestore — keep this in
/// sync with CatalogProvider._iconForName, which maps it back to an icon
/// for display everywhere else in the app.
const _kCategoryIconOptions = [
  ('eco', Icons.eco_rounded, 'Vegetables-style'),
  ('flower', Icons.local_florist_rounded, 'Fruits-style'),
  ('grass', Icons.grass_rounded, 'Grains-style'),
  ('water_drop', Icons.water_drop_rounded, 'Dairy-style'),
  ('fire', Icons.local_fire_department_rounded, 'Spices-style'),
  ('handyman', Icons.handyman_rounded, 'Handicrafts-style'),
  ('clothes', Icons.checkroom_rounded, 'Clothes'),
  ('medicine', Icons.medication_rounded, 'Medicine'),
  ('electronics', Icons.devices_other_rounded, 'Electronics'),
  ('bakery', Icons.bakery_dining_rounded, 'Bakery'),
  ('meat', Icons.set_meal_rounded, 'Meat/Fish'),
  ('stationery', Icons.edit_note_rounded, 'Stationery'),
  ('toys', Icons.toys_rounded, 'Toys'),
  ('household', Icons.cleaning_services_rounded, 'Household'),
  ('beauty', Icons.face_retouching_natural_rounded, 'Beauty'),
];

const _kCategoryColorOptions = [
  0xFF1F5F3F, 0xFFD9714E, 0xFFE8A33D, 0xFF4C8CBF, 0xFFC0453B,
  0xFF8A6D3B, 0xFF6C5CE7, 0xFF00897B, 0xFFAD1457, 0xFF546E7A,
];

/// Lets an admin add new product categories (e.g. Clothes, Medicine) —
/// category writes are admin-only in Firestore rules deliberately, to
/// avoid a fragmented mess of near-duplicate categories sellers might
/// create ("sabzi" vs "sabji" vs "vegetables"). New sellers who need a
/// category that doesn't exist yet just need to ask the admin to add it
/// here, which takes seconds.
class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<CatalogProvider>().load();
  }

  Future<void> _openAddCategorySheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddCategorySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: Text('Manage Categories', style: AppTextStyles.display(fontSize: 18)),
        iconTheme: const IconThemeData(color: AppColors.charcoal),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddCategorySheet,
        backgroundColor: AppColors.green,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Category', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        itemCount: catalog.categories.length,
        itemBuilder: (context, i) {
          final c = catalog.categories[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: c.color.withOpacity(0.12), shape: BoxShape.circle),
                  child: Icon(c.icon, size: 20, color: c.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${c.nameHi} / ${c.nameEn}',
                      style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AddCategorySheet extends StatefulWidget {
  const _AddCategorySheet();

  @override
  State<_AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends State<_AddCategorySheet> {
  final _nameHiCtrl = TextEditingController();
  final _nameEnCtrl = TextEditingController();
  String _iconName = _kCategoryIconOptions.first.$1;
  int _colorValue = _kCategoryColorOptions.first;
  bool _saving = false;

  @override
  void dispose() {
    _nameHiCtrl.dispose();
    _nameEnCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nameHi = _nameHiCtrl.text.trim();
    final nameEn = _nameEnCtrl.text.trim();
    if (nameHi.isEmpty || nameEn.isEmpty) return;

    setState(() => _saving = true);
    final id = nameEn.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    try {
      await FirebaseFirestore.instance.collection('categories').doc(id).set({
        'nameHi': nameHi,
        'nameEn': nameEn,
        'iconName': _iconName,
        'colorValue': _colorValue,
      });
      if (!mounted) return;
      await context.read<CatalogProvider>().load();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Couldn't save — try again")));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('New Category', style: AppTextStyles.display(fontSize: 17)),
              const SizedBox(height: 16),
              TextField(
                controller: _nameHiCtrl,
                decoration: const InputDecoration(labelText: 'Name (Hindi) — जैसे कपड़े'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameEnCtrl,
                decoration: const InputDecoration(labelText: 'Name (English) — e.g. Clothes'),
              ),
              const SizedBox(height: 16),
              Text('Icon', style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _kCategoryIconOptions.map((opt) {
                  final selected = opt.$1 == _iconName;
                  return InkWell(
                    onTap: () => setState(() => _iconName = opt.$1),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: selected ? AppColors.green.withOpacity(0.15) : AppColors.cream,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: selected ? AppColors.green : AppColors.line, width: selected ? 1.5 : 1),
                      ),
                      child: Icon(opt.$2, size: 20, color: selected ? AppColors.green : AppColors.mutedDark),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text('Color', style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _kCategoryColorOptions.map((value) {
                  final selected = value == _colorValue;
                  return InkWell(
                    onTap: () => setState(() => _colorValue = value),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(value),
                        shape: BoxShape.circle,
                        border: selected ? Border.all(color: AppColors.charcoal, width: 2) : null,
                      ),
                    ),
                  );
                }).toList(),
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
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Category', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
