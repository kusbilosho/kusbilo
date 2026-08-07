import 'dart:async';
import 'dart:convert';
import 'package:audio_session/audio_session.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:just_audio/just_audio.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Thin wrapper around speech input (on-device, free) and speech output
/// (natural voice via the synthesizeSpeech Cloud Function — Google
/// Cloud TTS Neural2, not the phone's built-in robotic engine).
///
/// IMPORTANT: [speak] awaits the audio *actually finishing playback*
/// before returning. Without that, calling [listen] right after
/// [speak] would start the microphone while the phone is still talking
/// through its own speaker — the mic then picks up the phone's own
/// voice, which is what caused the garbled noise/feedback bug.
class VoiceOrderService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final AudioPlayer _player = AudioPlayer();
  final _functions = FirebaseFunctions.instance;
  bool _speechReady = false;

  /// Set whenever [speak] fails, cleared on the next successful call —
  /// a temporary diagnostic so the UI can show what actually went
  /// wrong instead of the failure disappearing silently.
  String? lastError;

  Future<bool> init() async {
    _speechReady = await _speech.initialize(onError: (_) {}, onStatus: (_) {});

    // Explicitly configure a "media playback" audio session. Without
    // this, using the microphone (speech_to_text) can leave Android's
    // audio routing on "communication" mode afterward, which silently
    // sends any following playback to the earpiece (very quiet)
    // instead of the loudspeaker — the actual cause of "nothing seems
    // to be speaking" even though playback technically succeeds.
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
    ));

    return _speechReady;
  }

  bool get isAvailable => _speechReady;
  bool get isListening => _speech.isListening;

  /// Starts listening and calls [onResult] once with the final
  /// recognized text — an empty string means nothing was understood or
  /// the buyer stayed silent for [listenFor]/[pauseFor].
  ///
  /// [pauseFor] stays short (this is "how long a silence means you're
  /// done talking", not "how long you can go without talking at all")
  /// — a long value here just makes every single turn feel sluggish.
  /// The overall session (via the sheet auto-relistening after each
  /// exchange) is what avoids needing to re-tap the mic between turns.
  Future<void> listen({
    required void Function(String text) onResult,
    Duration listenFor = const Duration(minutes: 2),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    if (!_speechReady) return;
    await _speech.listen(
      localeId: 'hi_IN',
      onResult: (result) {
        if (result.finalResult) onResult(result.recognizedWords);
      },
      listenFor: listenFor,
      pauseFor: pauseFor,
      // A brief background noise burst shouldn't kill the whole
      // listening session on a lower-end phone with a noisier mic —
      // let it keep listening through minor recognition hiccups
      // rather than cancelling immediately.
      cancelOnError: false,
      partialResults: false,
    );
  }

  Future<void> stopListening() async {
    if (_speech.isListening) await _speech.stop();
  }

  /// Fetches natural speech audio for [text] from the synthesizeSpeech
  /// Cloud Function and plays it. Prefer [playAudioBase64] when audio
  /// already came bundled with another response (e.g. askAssistant) —
  /// this method exists as a fallback for text that has no pre-made
  /// audio yet.
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    try {
      final result = await _functions.httpsCallable('synthesizeSpeech').call({'text': text});
      final data = Map<String, dynamic>.from(result.data as Map);
      await playAudioBase64(data['audioBase64'] as String);
    } catch (e) {
      lastError = e.toString();
    }
  }

  /// Plays audio that's already been synthesized (as base64 MP3) —
  /// used when the audio arrived bundled with the askAssistant
  /// response, saving a whole extra network round trip compared to
  /// calling synthesizeSpeech separately. This is what actually fixed
  /// the "feels slow" complaint on a rural connection: one call
  /// instead of two.
  Future<void> playAudioBase64(String audioBase64) async {
    try {
      final bytes = base64Decode(audioBase64);
      await _player.setAudioSource(_BytesAudioSource(bytes));
      final session = await AudioSession.instance;
      await session.setActive(true);
      final completion = Completer<void>();
      late final StreamSubscription sub;
      sub = _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          sub.cancel();
          if (!completion.isCompleted) completion.complete();
        }
      });
      await _player.play();
      await completion.future;
      // Give the mic back fully — without this, the *next* listen()
      // call can silently fail to actually capture audio (the
      // playback session was still technically holding it), which is
      // what made every turn after the first one seem to "cut off"
      // immediately instead of really listening.
      await session.setActive(false);
      lastError = null;
    } catch (e) {
      lastError = e.toString();
    }
  }

  void dispose() {
    _speech.cancel();
    _player.dispose();
  }
}

/// Lets just_audio play straight from in-memory MP3 bytes instead of
/// needing a URL or a temp file on disk.
class _BytesAudioSource extends StreamAudioSource {
  final List<int> bytes;
  _BytesAudioSource(this.bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= bytes.length;
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(bytes.sublist(start, end)),
      contentType: 'audio/mpeg',
    );
  }
}
