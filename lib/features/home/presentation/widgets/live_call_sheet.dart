import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/services/live_voice_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../data/catalog_provider.dart';
import '../../data/models/product.dart';

/// Opens the voice-ordering call as a bottom sheet. This is the ONLY entry
/// point into a call — it owns one [LiveVoiceService] for the lifetime of
/// the sheet and tears it down when the sheet closes, so a call can never
/// be left running invisibly in the background.
void showLiveCallSheet(BuildContext context) {
  final catalog = context.read<CatalogProvider>();
  final locale = context.read<LocaleProvider>();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _LiveCallSheet(
      products: catalog.products,
      isHindi: locale.language == AppLanguage.hindi,
    ),
  );
}

class _LiveCallSheet extends StatefulWidget {
  final List<Product> products;
  final bool isHindi;
  const _LiveCallSheet({required this.products, required this.isHindi});

  @override
  State<_LiveCallSheet> createState() => _LiveCallSheetState();
}

class _LiveCallSheetState extends State<_LiveCallSheet> with SingleTickerProviderStateMixin {
  final _service = LiveVoiceService();
  LiveCallPhase _phase = LiveCallPhase.connecting;
  String? _error;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

    _service.onError = (e) => setState(() => _error = e);
    _service.onOrderCall = (call) {
      final cart = context.read<CartProvider>();
      final exists = widget.products.any((p) => p.id == call.productId);
      if (exists) cart.addQuantity(call.productId, call.quantity);
      return exists;
    };
    _service.onConfirmOrder = (call) {
      // Actual order placement (address, payment) happens in the normal
      // checkout screen — the call hands off there instead of trying to
      // place a full order over voice.
      _service.respondToConfirmOrder(call.functionCallId, 'success');
    };

    _service.phaseStream.listen((p) {
      if (mounted) setState(() => _phase = p);
    });

    final strings = context.read<LocaleProvider>().strings;
    _service.start(widget.products, strings, isHindi: widget.isHindi).catchError((e) {
      if (mounted) setState(() => _error = e.toString());
    });
  }

  @override
  void dispose() {
    _service.dispose();
    _pulse.dispose();
    super.dispose();
  }

  String get _statusText {
    switch (_phase) {
      case LiveCallPhase.connecting:
        return widget.isHindi ? 'जुड़ रहे हैं...' : 'Connecting...';
      case LiveCallPhase.listening:
        return widget.isHindi ? 'सुन रहे हैं...' : 'Listening...';
      case LiveCallPhase.aiSpeaking:
        return widget.isHindi ? 'बोल रहे हैं...' : 'Speaking...';
      case LiveCallPhase.error:
        return _error ?? (widget.isHindi ? 'कुछ गड़बड़ हो गई' : 'Something went wrong');
      case LiveCallPhase.ended:
        return widget.isHindi ? 'कॉल खत्म हुई' : 'Call ended';
    }
  }

  void _endCall() {
    _service.stop();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final speaking = _phase == LiveCallPhase.aiSpeaking;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) {
                final scale = speaking ? 1.0 + (_pulse.value * 0.12) : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                    child: const Icon(Icons.call, color: Colors.white, size: 36),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(_statusText, style: const TextStyle(fontSize: 16, color: AppColors.charcoal)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _CircleButton(
                  icon: _service.isMuted ? Icons.mic_off : Icons.mic,
                  background: AppColors.sage,
                  iconColor: AppColors.charcoal,
                  onTap: () => setState(_service.toggleMute),
                ),
                const SizedBox(width: 24),
                _CircleButton(
                  icon: Icons.call_end,
                  background: Colors.red,
                  iconColor: Colors.white,
                  onTap: _endCall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color iconColor;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.background, required this.iconColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor),
      ),
    );
  }
}
