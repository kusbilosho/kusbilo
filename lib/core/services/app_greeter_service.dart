import 'package:flutter_tts/flutter_tts.dart';

/// Speaks the "welcome, what would you like to order?" greeting the
/// moment the home screen opens — every app open, not just when the
/// buyer taps the mic.
///
/// This deliberately owns its own [FlutterTts] instance rather than
/// touching [VoiceOrderService] at all — that service's init() also
/// initializes speech-to-text, which triggers the microphone
/// permission prompt. Greeting the buyer shouldn't ask for mic access
/// before they've chosen to speak an order — only TTS is needed here.
class AppGreeterService {
  final FlutterTts _tts = FlutterTts();
  bool _configured = false;

  Future<void> greet(String text, {required bool isHindi}) async {
    if (!_configured) {
      await _tts.setLanguage(isHindi ? 'hi-IN' : 'en-IN');
      await _tts.setPitch(1.05);
      await _tts.setSpeechRate(0.48);
      // Prefer a female voice if the device exposes one for this
      // locale — falls back silently to the platform default otherwise.
      try {
        final voices = await _tts.getVoices as List<dynamic>?;
        final match = voices?.cast<Map<dynamic, dynamic>>().firstWhere(
              (v) => (v['name'] as String? ?? '').toLowerCase().contains('female'),
              orElse: () => {},
            );
        if (match != null && match.isNotEmpty) {
          await _tts.setVoice({'name': match['name'], 'locale': match['locale']});
        }
      } catch (_) {
        // Voice listing isn't supported on every platform — safe to ignore.
      }
      _configured = true;
    }
    await _tts.stop();
    await _tts.speak(text);
  }

  void dispose() {
    _tts.stop();
  }
}
