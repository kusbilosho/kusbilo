import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/services/product_image_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/haat_badge.dart';
import '../../../../core/widgets/lang_toggle.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../home/data/catalog_provider.dart';
import '../providers/seller_products_provider.dart';

const _kUnitOptions = ['/kg', '/g', '/ltr', '/ml', '/pc', '/dz', '/500g'];

const _kEmojiOptions = [
  '🍅', '🥕', '🥔', '🧅', '🥦', '🌽', '🍆',
  '🍌', '🥭', '🍎', '🍊', '🍇',
  '🌾', '🍚', '🥜',
  '🥛', '🥣',
  '🫙', '🌶️',
  '🧺', '🏺',
];

/// Form for a seller to add one product. Writes straight into the same
/// `products` collection buyers browse (SellerProductsProvider), with a
/// photo, description, and tags — those three are exactly what the
/// buyer-side voice ordering matches spoken words against, so a seller
/// who fills them in well shows up more often in voice search results.
class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();

  String? _categoryId;
  String? _categoryName;
  String _unit = _kUnitOptions.first;
  String? _emoji;
  bool _showCategoryError = false;
  File? _imageFile;
  bool _saving = false;
  bool _suggesting = false;
  String? _nameHiOverride;
  String? _nameEnOverride;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final catalog = context.read<CatalogProvider>();
      await catalog.load();
      // If some earlier attempt left the catalog loaded-but-empty (e.g.
      // seeding failed once due to a permissions issue that's since
      // been fixed), one forced retry here means the seller doesn't
      // have to know to go "restart the app" themselves.
      if (catalog.categories.isEmpty && mounted) {
        await catalog.load(forceRefresh: true);
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    _descriptionCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      imageQuality: 80,
    );
    if (picked == null) return;
    setState(() => _imageFile = File(picked.path));
  }

  Future<void> _suggestListing() async {
    final strings = context.read<LocaleProvider>().strings;
    final productName = _nameCtrl.text.trim();
    if (productName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings.fieldRequiredError)));
      return;
    }

    setState(() => _suggesting = true);
    try {
      final result = await FirebaseFunctions.instance.httpsCallable('suggestProductListing').call({
        'productName': productName,
        'categoryName': _categoryName,
      });
      final data = Map<String, dynamic>.from(result.data as Map);

      if (!mounted) return;
      setState(() {
        _nameHiOverride = data['nameHi'] as String?;
        _nameEnOverride = data['nameEn'] as String?;
        _nameCtrl.text = _nameHiOverride ?? productName;
        _descriptionCtrl.text = data['description'] as String? ?? _descriptionCtrl.text;
        final tags = (data['tags'] as List?)?.cast<String>() ?? [];
        if (tags.isNotEmpty) _tagsCtrl.text = tags.join(', ');
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings.aiSuggestFailedMessage)));
    } finally {
      if (mounted) setState(() => _suggesting = false);
    }
  }

  Future<void> _save() async {
    final formOk = _formKey.currentState!.validate();
    setState(() {
      _showCategoryError = _categoryId == null;
    });
    // Emoji is only a fallback thumbnail for when there's no real photo
    // — a merchant selling something not in the preset list (any real
    // product, not just what's hardcoded here) should never be blocked
    // by "pick one of these icons".
    if (!formOk || _categoryId == null || _saving) return;

    setState(() => _saving = true);

    try {
      final tags = _tagsCtrl.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final provider = context.read<SellerProductsProvider>();
      final name = _nameCtrl.text.trim();

      String? imageUrl;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (_imageFile != null && uid != null) {
        try {
          imageUrl = await ProductImageService.uploadProductImage(
            sellerUid: uid,
            productId: DateTime.now().microsecondsSinceEpoch.toString(),
            imageFile: _imageFile!,
          );
        } catch (_) {
          // Photo upload failing shouldn't block the whole listing —
          // the product still saves with just the emoji/fallback icon.
        }
      }

      await provider.addProduct(
        categoryId: _categoryId!,
        nameHi: _nameHiOverride ?? name,
        nameEn: _nameEnOverride ?? name,
        emoji: _emoji ?? '🛍️',
        priceValue: int.parse(_priceCtrl.text.trim()),
        unit: _unit,
        stock: int.parse(_stockCtrl.text.trim()),
        description: _descriptionCtrl.text.trim(),
        tags: tags,
        imageUrl: imageUrl,
      );

      // The buyer-facing Home screen caches CatalogProvider's data and
      // only refetches when explicitly told to — without this, a
      // seller's brand-new listing wouldn't show up until the buyer
      // happened to force-refresh or restart the app.
      if (mounted) {
        await context.read<CatalogProvider>().load(forceRefresh: true);
      }

      if (!mounted) return;
      final strings = context.read<LocaleProvider>().strings;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.productAddedMessage), duration: const Duration(seconds: 2)),
      );
    } catch (e) {
      if (!mounted) return;
      final strings = context.read<LocaleProvider>().strings;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${strings.productSaveFailed}: $e'), duration: const Duration(seconds: 4)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleProvider>().strings;
    final lang = context.watch<LocaleProvider>().language;
    final categories = context.watch<CatalogProvider>().categories;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Padding(
                          padding: EdgeInsets.only(right: 8, top: 4, bottom: 4),
                          child: Icon(Icons.arrow_back_rounded, size: 22, color: AppColors.green),
                        ),
                      ),
                      const HaatBadge(size: 30),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(strings.addProductTitle, style: AppTextStyles.display(fontSize: 18)),
                      ),
                      const LangToggle(),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ---- Photo ----
                    Text(strings.productPhotoLabel,
                        style: AppTextStyles.caption(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted)),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _pickImage,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.line, width: 1.4),
                        ),
                        child: _imageFile != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: Image.file(_imageFile!, fit: BoxFit.cover, width: double.infinity),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add_a_photo_outlined, size: 28, color: AppColors.muted),
                                  const SizedBox(height: 8),
                                  Text(strings.addPhotoHint, style: AppTextStyles.caption(fontSize: 12)),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(strings.chooseIconOptionalLabel,
                        style: AppTextStyles.caption(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _kEmojiOptions.map((e) => _EmojiChoice(
                            emoji: e,
                            selected: _emoji == e,
                            onTap: () => setState(() {
                              _emoji = (_emoji == e) ? null : e;
                            }),
                          )).toList(),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameCtrl,
                      style: AppTextStyles.body(fontSize: 14),
                      decoration: _fieldDecoration(strings.productNameLabel),
                      validator: (v) => (v == null || v.trim().isEmpty) ? strings.fieldRequiredError : null,
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _suggesting ? null : _suggestListing,
                        icon: _suggesting
                            ? const SizedBox(
                                width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green))
                            : const Icon(Icons.auto_awesome_rounded, size: 16),
                        label: Text(strings.aiSuggestButton),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.green),
                          foregroundColor: AppColors.green,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _descriptionCtrl,
                      maxLines: 3,
                      style: AppTextStyles.body(fontSize: 14),
                      decoration: _fieldDecoration(strings.productDescriptionLabel)
                          .copyWith(hintText: strings.productDescriptionHint, hintStyle: AppTextStyles.caption(fontSize: 12)),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _tagsCtrl,
                      style: AppTextStyles.body(fontSize: 14),
                      decoration: _fieldDecoration(strings.productTagsLabel)
                          .copyWith(hintText: strings.productTagsHint, hintStyle: AppTextStyles.caption(fontSize: 12)),
                    ),
                    const SizedBox(height: 6),
                    Text(strings.productTagsHelper, style: AppTextStyles.caption(fontSize: 11, color: AppColors.muted)),
                    const SizedBox(height: 14),
                    if (categories.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.line, width: 1.4),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(strings.categoriesLoadFailedMessage,
                                  style: AppTextStyles.caption(fontSize: 12)),
                            ),
                            TextButton(
                              onPressed: () => context.read<CatalogProvider>().load(forceRefresh: true),
                              child: Text(strings.retryButton,
                                  style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.green)),
                            ),
                          ],
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: _categoryId,
                        decoration: _fieldDecoration(strings.categoryFieldLabel),
                        style: AppTextStyles.body(fontSize: 14, color: AppColors.charcoal),
                        items: categories
                            .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name(lang))))
                            .toList(),
                      onChanged: (value) => setState(() {
                        _categoryId = value;
                        _categoryName = categories.firstWhere((c) => c.id == value).name(lang);
                        _showCategoryError = false;
                      }),
                    ),
                    if (_showCategoryError) ...[
                      const SizedBox(height: 6),
                      Text(strings.selectCategoryError,
                          style: AppTextStyles.caption(fontSize: 12, color: Colors.red.shade700)),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _priceCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: AppTextStyles.body(fontSize: 14),
                            decoration: _fieldDecoration(strings.priceLabel),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return strings.fieldRequiredError;
                              final n = int.tryParse(v.trim());
                              return (n == null || n <= 0) ? strings.priceInvalidError : null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: _unit,
                            decoration: _fieldDecoration(strings.unitLabel),
                            style: AppTextStyles.body(fontSize: 14, color: AppColors.charcoal),
                            items: _kUnitOptions
                                .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                                .toList(),
                            onChanged: (value) => setState(() => _unit = value ?? _unit),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _stockCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: AppTextStyles.body(fontSize: 14),
                      decoration: _fieldDecoration(strings.stockLabel),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return strings.fieldRequiredError;
                        final n = int.tryParse(v.trim());
                        return (n == null || n < 0) ? strings.stockInvalidError : null;
                      },
                    ),
                    const SizedBox(height: 28),
                    PrimaryButton(
                      label: _saving ? strings.savingProductLabel : strings.saveProductButton,
                      enabled: !_saving,
                      onPressed: _save,
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      labelStyle: AppTextStyles.caption(fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.line, width: 1.4),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.line, width: 1.4),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.green, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.4),
      ),
    );
  }
}

class _EmojiChoice extends StatelessWidget {
  final String emoji;
  final bool selected;
  final VoidCallback onTap;
  const _EmojiChoice({required this.emoji, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.sage : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.green : AppColors.line, width: selected ? 1.8 : 1),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 22)),
      ),
    );
  }
}
