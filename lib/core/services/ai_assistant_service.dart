import 'package:cloud_functions/cloud_functions.dart';

enum AssistantResultType { order, confirmOrder, answer, unclear }

/// Result of asking the real AI (Gemini, via the askAssistant Cloud
/// Function) to interpret something the buyer said. Unlike the old
/// local keyword-matching, this actually understands natural language
/// — typos, indirect phrasing, and general questions about the app
/// ("delivery kitne din me aati hai", "seller kaise banu") all work,
/// not just an exact/substring match against a product name.
class AssistantResult {
  final AssistantResultType type;
  final String? productId;
  final int quantity;
  final String? message;
  final String? debugError;

  /// Pre-synthesized speech audio (base64 MP3) for this result,
  /// bundled server-side in the same call — playing this directly
  /// (VoiceOrderService.playAudioBase64) avoids a second network round
  /// trip that a separate synthesizeSpeech call would need.
  final String? audioBase64;

  const AssistantResult({
    required this.type,
    this.productId,
    this.quantity = 1,
    this.message,
    this.debugError,
    this.audioBase64,
  });
}

class AiAssistantService {
  static final _functions = FirebaseFunctions.instance;

  /// Sends what the buyer said to the askAssistant Cloud Function,
  /// which asks Gemini to either match it to a product in the live
  /// catalog or answer a general question about the app, and also
  /// returns ready-to-play spoken audio for the reply. Returns
  /// [AssistantResultType.unclear] (with [debugError] set) on failure
  /// so the caller always has a safe fallback path and something
  /// diagnosable to show.
  static Future<AssistantResult> ask(String text) async {
    try {
      final result = await _functions.httpsCallable('askAssistant').call({'text': text});
      final data = Map<String, dynamic>.from(result.data as Map);

      final typeStr = data['type'] as String?;
      final type = switch (typeStr) {
        'order' => AssistantResultType.order,
        'confirmOrder' => AssistantResultType.confirmOrder,
        'answer' => AssistantResultType.answer,
        _ => AssistantResultType.unclear,
      };

      return AssistantResult(
        type: type,
        productId: data['productId'] as String?,
        quantity: (data['quantity'] as num?)?.toInt() ?? 1,
        message: data['message'] as String?,
        debugError: data['debugError'] as String?,
        audioBase64: data['audioBase64'] as String?,
      );
    } catch (e) {
      return AssistantResult(type: AssistantResultType.unclear, debugError: e.toString());
    }
  }
}
