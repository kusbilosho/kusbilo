import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/services/ai_assistant_service.dart';
import '../../../../core/services/app_faq_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/voice_order_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../order/data/models/order_item.dart';
import '../../../order/presentation/providers/order_provider.dart';
import '../../../order/presentation/screens/order_success_screen.dart';
import '../../data/catalog_provider.dart';

enum _CallState { connecting, listening, thinking, error }

/// Opens as a bottom sheet from the mic button on Home — turn-based
/// voice ordering: the buyer speaks, on-device speech recognition turns
/// it into text, the askAssistant Cloud Function (Gemini + the live
/// catalog) figures out what they meant, and a natural voice reply
/// (Google Cloud TTS, pre-synthesized server-side) speaks back before
/// listening resumes automatically. Deliberately NOT the continuous
/// Gemini Live API: that needs a billed project; this listen -> think
/// -> speak loop runs on Firebase's free tier and a phone's own mic/TTS.
Future<void> showVoiceOrderSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => const _VoiceOrderSheet(),
  );
}

class _VoiceOrderSheet extends StatefulWidget {
  const _VoiceOrderSheet();

  @override
  State<_VoiceOrderSheet> createState() => _VoiceOrderSheetState();
}

class _VoiceOrderSheetState extends State<_VoiceOrderSheet> {
  final _service = VoiceOrderService();
  _CallState _state = _CallState.connecting;
  String? _errorText;
  bool _ended = false;
  final List<String> _addedLines = [];

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  Future<void> _startSession() async {
    final strings = context.read<LocaleProvider>().strings;
    final ready = await _service.init();

    if (!mounted) return;
    if (!ready) {
      setState(() {
        _state = _CallState.error;
        _errorText = strings.liveCallMicPermissionError;
      });
      return;
    }

    setState(() => _state = _CallState.listening);
    _listenTurn();
  }

  Future<void> _listenTurn() async {
    if (_ended) return;
    setState(() => _state = _CallState.listening);
    await _service.listen(onResult: _handleUserText);
  }

  Future<void> _handleUserText(String text) async {
    if (_ended) return;
    if (text.trim().isEmpty) {
      _listenTurn();
      return;
    }

    setState(() => _state = _CallState.thinking);

    // Cheap, offline, instant app-FAQ check first — no reason to spend
    // a network round trip asking Gemini "how do I place an order".
    final strings = context.read<LocaleProvider>().strings;
    final faqTopic = AppFaqService.match(text);
    if (faqTopic != null) {
      await _service.speak(AppFaqService.answerFor(faqTopic, strings));
      _listenTurn();
      return;
    }

    final result = await AiAssistantService.ask(text);
    if (_ended || !mounted) return;

    switch (result.type) {
      case AssistantResultType.order:
        _applyOrder(result);
        break;
      case AssistantResultType.confirmOrder:
      case AssistantResultType.answer:
      case AssistantResultType.unclear:
        break;
    }

    if (result.audioBase64 != null) {
      await _service.playAudioBase64(result.audioBase64!);
    } else {
      await _service.speak(result.message ?? strings.voiceUnclearMessage);
    }

    if (result.type == AssistantResultType.confirmOrder) {
      await _confirmOrder();
      return;
    }

    _listenTurn();
  }

  /// Builds an order from whatever's currently in the cart, detects the
  /// buyer's current location as the delivery point (same GPS-only
  /// approach as checkout — nobody types an address), and places it via
  /// the same placeOrder Cloud Function the regular checkout screen
  /// uses. On success, ends the voice session and hands off to the
  /// normal order-success screen; on failure, speaks what went wrong
  /// and resumes listening so the buyer can try again.
  Future<void> _confirmOrder() async {
    final strings = context.read<LocaleProvider>().strings;
    final cart = context.read<CartProvider>();
    final catalog = context.read<CatalogProvider>();

    if (cart.isEmpty) {
      await _service.speak(strings.voiceCartEmptyMessage);
      _listenTurn();
      return;
    }

    setState(() => _state = _CallState.thinking);

    DetectedLocation location;
    try {
      location = await LocationService.detectCurrentLocation();
    } catch (_) {
      if (!mounted) return;
      await _service.speak(strings.locationUnknownError);
      _listenTurn();
      return;
    }

    final items = cart.quantities.entries
        .map((e) => (product: catalog.productById(e.key), qty: e.value))
        .where((entry) => entry.product != null)
        .map((entry) => OrderItem(
              productId: entry.product!.id,
              nameHi: entry.product!.nameHi,
              nameEn: entry.product!.nameEn,
              priceValue: entry.product!.priceValue,
              unit: entry.product!.unit,
              quantity: entry.qty,
            ))
        .toList();

    if (!mounted) return;
    final order = await context.read<OrderProvider>().placeOrder(
          items: items,
          deliveryLat: location.latitude,
          deliveryLng: location.longitude,
          deliveryAddressLabel: location.label,
        );

    if (!mounted) return;
    if (order == null) {
      await _service.speak(strings.voiceOrderFailedMessage);
      _listenTurn();
      return;
    }

    cart.clear();
    _ended = true;
    await _service.stopListening();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => OrderSuccessScreen(order: order)),
    );
  }

  void _applyOrder(AssistantResult result) {
    if (result.productId == null) return;
    final catalog = context.read<CatalogProvider>();
    final product = catalog.productById(result.productId!);
    if (product == null) return;

    final cart = context.read<CartProvider>();
    for (var i = 0; i < result.quantity; i++) {
      cart.add(product.id);
    }

    if (!mounted) return;
    final lang = context.read<LocaleProvider>().language;
    final strings = context.read<LocaleProvider>().strings;
    setState(() {
      _addedLines.add(strings.liveCallItemAdded(product.name(lang), result.quantity));
    });
  }

  Future<void> _endCall() async {
    _ended = true;
    await _service.stopListening();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _ended = true;
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleProvider>().strings;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _endCall();
      },
      child: Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.inactive, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              if (_addedLines.isNotEmpty) ...[
                ..._addedLines.map((line) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: AppColors.green, size: 16),
                          const SizedBox(width: 6),
                          Text(line, style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )),
                const SizedBox(height: 12),
              ],
              _buildStateBody(strings),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _endCall,
                  icon: const Icon(Icons.call_end, color: Colors.white, size: 18),
                  label: Text(strings.liveCallEndButton,
                      style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC0453B),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateBody(dynamic strings) {
    switch (_state) {
      case _CallState.connecting:
        return Column(
          children: [
            const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.green)),
            const SizedBox(height: 16),
            Text(strings.liveCallConnecting, style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        );
      case _CallState.listening:
        return Column(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.9, end: 1.1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeInOut,
              builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
              child: Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                child: const Icon(Icons.mic_rounded, color: Colors.white, size: 36),
              ),
              onEnd: () {},
            ),
            const SizedBox(height: 16),
            Text(strings.voiceListeningLabel,
                textAlign: TextAlign.center, style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        );
      case _CallState.thinking:
        return Column(
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(color: AppColors.mustard, shape: BoxShape.circle),
              child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            Text(strings.voiceThinkingLabel,
                textAlign: TextAlign.center, style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        );
      case _CallState.error:
        return Column(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFC0453B), size: 44),
            const SizedBox(height: 12),
            Text(_errorText ?? '', textAlign: TextAlign.center, style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        );
    }
  }
}
