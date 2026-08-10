import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/services/live_voice_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../order/data/models/order_item.dart';
import '../../../order/presentation/providers/order_provider.dart';
import '../../../order/presentation/screens/order_success_screen.dart';
import '../../data/catalog_provider.dart';

/// Opens as a bottom sheet from the mic button on Home — a real
/// continuous live call over a direct Gemini Live API WebSocket, not
/// the old turn-based listen → think → speak loop. The buyer can talk
/// naturally, interrupt mid-reply, ask items to be added to the cart,
/// ask general questions about the app, and finish by asking to place
/// the order — all in one open conversation.
Future<void> showLiveCallSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => const _LiveCallSheet(),
  );
}

class _LiveCallSheet extends StatefulWidget {
  const _LiveCallSheet();

  @override
  State<_LiveCallSheet> createState() => _LiveCallSheetState();
}

class _LiveCallSheetState extends State<_LiveCallSheet> {
  final _service = LiveVoiceService();
  LiveCallPhase _phase = LiveCallPhase.connecting;
  bool _isMuted = false;
  String? _errorText;
  String _captionLine = '';
  bool _ended = false;
  bool _placingOrder = false;
  bool _needsApiKey = false;
  bool _savingKey = false;
  final _apiKeyController = TextEditingController();
  final List<String> _addedLines = [];

  @override
  void initState() {
    super.initState();
    _service.phaseStream.listen((phase) {
      if (mounted) setState(() => _phase = phase);
    });
    _service.muteStream.listen((muted) {
      if (mounted) setState(() => _isMuted = muted);
    });
    _service.onModelText = (text) {
      if (mounted) setState(() => _captionLine = text);
    };
    _service.onOrderCall = _handleOrderCall;
    _service.onConfirmOrder = _handleConfirmOrder;
    _service.onError = (message) {
      if (mounted) setState(() => _errorText = message);
    };
    _startSession();
  }

  Future<void> _startSession() async {
    final catalog = context.read<CatalogProvider>();
    final locale = context.read<LocaleProvider>();
    final strings = locale.strings;

    try {
      await _service.start(
        catalog.products,
        strings,
        isHindi: locale.language == AppLanguage.hindi,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = LiveCallPhase.error;
        if (e is NoApiKeyConfiguredException) {
          _needsApiKey = true;
          _errorText = strings.liveCallNoApiKeyError;
        } else if (e.toString().contains('ermission')) {
          _errorText = strings.liveCallMicPermissionError;
        } else {
          _errorText = strings.liveCallFailedError;
        }
      });
    }
  }

  /// Saves the key the buyer just typed (locally, on-device only — see
  /// LiveVoiceService.saveApiKey) and immediately retries the call so
  /// there's no extra tap needed.
  Future<void> _saveKeyAndRetry() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) return;
    setState(() => _savingKey = true);
    await LiveVoiceService.saveApiKey(key);
    if (!mounted) return;
    setState(() {
      _savingKey = false;
      _needsApiKey = false;
      _errorText = null;
    });
    _startSession();
  }

  void _handleOrderCall(LiveOrderCall call) {
    if (_ended || !mounted) return;
    final catalog = context.read<CatalogProvider>();
    final product = catalog.productById(call.productId);
    if (product == null) return;

    final cart = context.read<CartProvider>();
    for (var i = 0; i < call.quantity; i++) {
      cart.add(product.id);
    }

    final lang = context.read<LocaleProvider>().language;
    final strings = context.read<LocaleProvider>().strings;
    setState(() {
      _addedLines.add(strings.liveCallItemAdded(product.name(lang), call.quantity));
    });
  }

  /// Mirrors the old voice-order sheet's checkout flow: builds order
  /// items from whatever's in the cart, auto-detects delivery location
  /// via GPS, and places it through the same placeOrder Cloud Function
  /// as regular checkout. Reports the outcome back to the model via
  /// [LiveVoiceService.respondToConfirmOrder] so it can tell the buyer
  /// what happened in its own words instead of the app going silent.
  Future<void> _handleConfirmOrder(LiveConfirmOrderCall call) async {
    if (_ended || !mounted) return;
    final cart = context.read<CartProvider>();
    final catalog = context.read<CatalogProvider>();

    if (cart.isEmpty) {
      _service.respondToConfirmOrder(call.functionCallId, 'empty');
      return;
    }

    setState(() => _placingOrder = true);

    DetectedLocation location;
    try {
      location = await LocationService.detectCurrentLocation();
    } catch (_) {
      if (!mounted) return;
      setState(() => _placingOrder = false);
      _service.respondToConfirmOrder(call.functionCallId, 'location_error');
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
    setState(() => _placingOrder = false);

    if (order == null) {
      _service.respondToConfirmOrder(call.functionCallId, 'failed');
      return;
    }

    _service.respondToConfirmOrder(call.functionCallId, 'success');
    cart.clear();
    _ended = true;
    // Give the model a beat to actually speak the confirmation before
    // we tear the call down and navigate away.
    await Future.delayed(const Duration(seconds: 2));
    await _service.stop();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => OrderSuccessScreen(order: order)),
    );
  }

  Future<void> _endCall() async {
    _ended = true;
    await _service.stop();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _ended = true;
    _service.dispose();
    _apiKeyController.dispose();
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
                          Expanded(
                            child: Text(line, style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 12),
              ],
              _buildStateBody(strings),
              if (_captionLine.isNotEmpty && _phase != LiveCallPhase.error) ...[
                const SizedBox(height: 12),
                Text(
                  _captionLine,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(fontSize: 12, color: AppColors.muted),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  if (_phase == LiveCallPhase.listening || _phase == LiveCallPhase.aiSpeaking) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _service.toggleMute,
                        icon: Icon(_isMuted ? Icons.mic_off : Icons.mic, size: 18),
                        label: Text(
                          _isMuted ? strings.liveCallUnmuteButton : strings.liveCallMuteButton,
                          style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateBody(dynamic strings) {
    if (_placingOrder) {
      return Column(
        children: [
          const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.green)),
          const SizedBox(height: 16),
          Text(strings.liveCallPlacingOrderLabel, style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      );
    }

    switch (_phase) {
      case LiveCallPhase.connecting:
        return Column(
          children: [
            const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.green)),
            const SizedBox(height: 16),
            Text(strings.liveCallConnecting, style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        );
      case LiveCallPhase.listening:
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
                child: Icon(_isMuted ? Icons.mic_off_rounded : Icons.mic_rounded, color: Colors.white, size: 36),
              ),
            ),
            const SizedBox(height: 16),
            Text(strings.liveCallInProgress,
                textAlign: TextAlign.center, style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        );
      case LiveCallPhase.aiSpeaking:
        return Column(
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(color: AppColors.mustard, shape: BoxShape.circle),
              child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            Text(strings.liveCallAiSpeakingLabel,
                textAlign: TextAlign.center, style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        );
      case LiveCallPhase.error:
        if (_needsApiKey) return _buildApiKeyPrompt(strings);
        return Column(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFC0453B), size: 44),
            const SizedBox(height: 12),
            Text(_errorText ?? strings.liveCallFailedError,
                textAlign: TextAlign.center, style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        );
      case LiveCallPhase.ended:
        return const SizedBox(height: 84);
    }
  }

  /// Shown the first time (or after clearing the key) instead of the
  /// generic error — lets the buyer paste their own free Gemini API key
  /// right here and retry immediately, no separate settings screen.
  Widget _buildApiKeyPrompt(dynamic strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.key_rounded, color: AppColors.green, size: 36),
        const SizedBox(height: 10),
        Text(strings.liveCallSetupTitle,
            textAlign: TextAlign.center, style: AppTextStyles.body(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(strings.liveCallSetupBody,
            textAlign: TextAlign.center, style: AppTextStyles.caption(fontSize: 12)),
        const SizedBox(height: 14),
        TextField(
          controller: _apiKeyController,
          obscureText: true,
          decoration: InputDecoration(
            hintText: strings.liveCallApiKeyHint,
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 8),
        Text(strings.liveCallGetKeyLink,
            textAlign: TextAlign.center, style: AppTextStyles.caption(fontSize: 11)),
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: _savingKey ? null : _saveKeyAndRetry,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.green,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _savingKey
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(strings.liveCallSaveKeyButton,
                  style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ],
    );
  }
}
