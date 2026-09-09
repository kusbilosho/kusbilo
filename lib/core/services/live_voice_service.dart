import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
import 'package:flutter_nnnoiseless/flutter_nnnoiseless.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../localization/app_strings.dart';
import '../../features/home/data/models/product.dart';

class LiveOrderCall {
  final String functionCallId;
  final String productId;
  final int quantity;
  const LiveOrderCall({
    required this.functionCallId,
    required this.productId,
    required this.quantity,
  });
}

class LiveConfirmOrderCall {
  final String functionCallId;
  const LiveConfirmOrderCall({required this.functionCallId});
}

enum LiveCallPhase { connecting, listening, aiSpeaking, ended, error }

class NoApiKeyConfiguredException implements Exception {
  @override
  String toString() => 'Voice call is not configured yet.';
}

class LiveVoiceService {
  static const String _model = 'gemini-3.1-flash-live-preview';
  static const int _sampleRateOut = 24000;
  static const int _sampleRateIn = 16000;
  static const int _bytesPerSample = 2;

  static const MethodChannel _audioModeChannel = MethodChannel('kusbilo/audio_mode');
  bool _audioSessionConfigured = false;

  // --- Audio focus + interruption handling (real phone call, another app
  // grabbing audio, etc.) ---
  // The native platform channel above puts the OS into "voice call" mode,
  // but never actually REQUESTS audio focus — so nothing tells this app
  // when a real phone call rings in or another app grabs the speaker.
  // audio_session does both: requesting focus with the same "voice
  // communication" attributes as a real VoIP call, and giving us a
  // callback for exactly those interruptions so we can pause the mic
  // instead of talking over a real call or capturing ringtone audio.
  AudioSession? _audioSession;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  bool _autoMutedByInterruption = false;

  WebSocketChannel? _channel;
  StreamSubscription<Uint8List>? _micSub;
  StreamSubscription? _wsSub;
  final AudioRecorder _recorder = AudioRecorder();

  bool _isMuted = false;
  bool get isMuted => _isMuted;
  final _muteController = StreamController<bool>.broadcast();
  Stream<bool> get muteStream => _muteController.stream;

  final _phaseController = StreamController<LiveCallPhase>.broadcast();
  Stream<LiveCallPhase> get phaseStream => _phaseController.stream;

  bool get isActive => _channel != null;

  bool Function(LiveOrderCall call)? onOrderCall;
  void Function(LiveConfirmOrderCall call)? onConfirmOrder;
  void Function(String text)? onModelText;
  void Function(String text)? onUserText;
  void Function(String error)? onError;

  final Map<String, Completer<String>> _pendingConfirmations = {};

  bool _pcmReady = false;
  bool _setupComplete = false;
  bool _manualDisconnect = false;
  bool _isRefreshingSession = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;

  List<Product>? _lastProducts;
  AppStrings? _lastStrings;
  bool _lastIsHindi = false;

  static const Duration _connectTimeout = Duration(seconds: 15);
  Timer? _connectTimeoutTimer;

  static const Duration _sessionRefreshAt = Duration(minutes: 9, seconds: 30);
  Timer? _sessionRefreshTimer;

  int _playbackGeneration = 0;
  bool _reinitInProgress = false;
  final List<Uint8List> _pendingAudio = [];
  Future<void> _feedChain = Future.value();
  bool _aiIsSpeaking = false;

  // --- Mic-side noise suppression (RNNoise, via flutter_nnnoiseless) ---
  // OS-level echoCancel/noiseSuppress (RecordConfig below) only catches
  // steady background hiss. A neural denoiser recognizes "this is a human
  // voice" vs. everything else, so it also kills non-steady noise — a
  // horn, a dog bark, someone else talking nearby — that the OS-level
  // toggle lets straight through. Every mic chunk is denoised BEFORE it's
  // sent to Gemini, so the AI only ever hears clean speech.
  NoiselessSession? _denoiser;
  Future<void> _micChain = Future.value();
  // How many mic chunks are currently queued waiting on the denoiser (sent
  // but not yet processed). If this grows, the denoiser is running slower
  // than real time on this device — every chunk after it inherits the same
  // growing delay, which is what breaks Gemini's turn-taking on-device
  // ("bolta bhatak ke" / goes silent), not the actual background noise.
  int _pendingMicChunks = 0;
  static const int _maxPendingMicChunks = 3;

  static const double _minCushionSeconds = 0.25;
  static const double _maxCushionSeconds = 1.0;
  double _cushionSeconds = _minCushionSeconds;
  int get _cushionBytes => (_sampleRateOut * _bytesPerSample * _cushionSeconds).round();
  bool _bufferingTurn = true;
  final BytesBuilder _jitterBuffer = BytesBuilder(copy: false);
  DateTime? _lastChunkArrival;
  final List<int> _turnGapsMs = [];

  static const double _speechAmplitudeThreshold = 3000 / 32767;
  // Raised from 0.6: on loudspeaker, the AI's own voice leaking back into
  // the mic (echo) still reads as "human speech" to RNNoise — it detects
  // voice-vs-noise, not self-vs-other. A higher bar plus the consecutive-
  // chunk check below (next field) means a stray echo spike alone can't
  // trigger a false barge-in; real speech clears both easily.
  static const double _voiceProbabilityThreshold = 0.75;
  // Echo tends to come in short, inconsistent bursts (room reflections),
  // while a person actually interrupting speaks continuously. Requiring
  // this many consecutive chunks above threshold before barging in filters
  // out most echo without adding noticeable delay to a genuine interrupt
  // (~3 chunks is well under 100ms at this sample rate).
  static const int _bargeInConsecutiveChunks = 3;
  int _consecutiveLoudChunks = 0;
  double _peakAmplitude(Uint8List chunk) {
    final samples = ByteData.sublistView(chunk);
    var peak = 0;
    for (var i = 0; i + 1 < chunk.length; i += 2) {
      final sample = samples.getInt16(i, Endian.little).abs();
      if (sample > peak) peak = sample;
    }
    return (peak / 32767).clamp(0.0, 1.0);
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    _muteController.add(_isMuted);
  }

  Future<void> _setupAudioSession() async {
    try {
      if (Platform.isAndroid) {
        await _audioModeChannel.invokeMethod('setAudioMode');
      } else if (Platform.isIOS) {
        await _audioModeChannel.invokeMethod('setupAudioSession');
      }
    } catch (e) {
      onError?.call('Could not configure call audio — echo cancellation may be weaker: $e');
    }

    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth |
            AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        // Exclusive focus, like a real phone call — other apps' audio should
        // stop or duck for us, not play over us.
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));
      // Actually requests audio focus (Android) / activates the session
      // (iOS) — without this, `interruptionEventStream` below never fires,
      // because the OS only tells you about focus you actually hold.
      await session.setActive(true);
      _audioSession = session;
      _interruptionSub = session.interruptionEventStream.listen(_handleAudioInterruption);
    } catch (e) {
      // Non-fatal — the call still works, it just won't gracefully duck for
      // a real incoming call or another app's audio.
      onError?.call('Could not set up call audio focus: $e');
    }
  }

  void _handleAudioInterruption(AudioInterruptionEvent event) {
    if (event.begin) {
      // A real phone call, Siri, another app's voice prompt, etc. is taking
      // over. Stop sending mic audio so we don't talk over it or capture
      // its sound — but don't touch _isMuted if the buyer had already
      // muted themself, so we don't un-mute them by mistake once it ends.
      if (!_isMuted) {
        _autoMutedByInterruption = true;
        _isMuted = true;
        _muteController.add(_isMuted);
      }
    } else if (_autoMutedByInterruption) {
      _autoMutedByInterruption = false;
      _isMuted = false;
      _muteController.add(_isMuted);
    }
  }

  Future<void> start(
    List<Product> products,
    AppStrings strings, {
    required bool isHindi,
  }) async {
    _phaseController.add(LiveCallPhase.connecting);
    _manualDisconnect = false;

    if (!await _recorder.hasPermission()) {
      _phaseController.add(LiveCallPhase.error);
      onError?.call('Microphone permission denied.');
      throw Exception('Microphone permission denied.');
    }

    _lastProducts = products;
    _lastStrings = strings;
    _lastIsHindi = isHindi;

    await _connect();
  }

  Future<({String token, String instructions})?> _fetchTokenAndInstructions() async {
    final products = _lastProducts;
    final strings = _lastStrings;
    if (products == null || strings == null) return null;

    final catalogLines = products
        .where((p) => p.isActive && p.stock > 0)
        .map((p) =>
            '${p.id} | ${p.nameHi} / ${p.nameEn} | ₹${p.priceValue}${p.unit} | tags: ${p.tags.join(', ')} | ${p.description}')
        .join('\n');

    final appFaq = '''
- ${strings.faqHowToOrderAnswer}
- ${strings.faqPaymentAnswer}
- ${strings.faqDeliveryTimeAnswer}
- ${strings.faqTrackOrderAnswer}
- ${strings.faqBecomeSellerAnswer}
- ${strings.faqChangeLanguageAnswer}
- ${strings.faqCancelOrderAnswer}
- ${strings.faqAppNameAnswer}
''';

    late final HttpsCallableResult result;
    try {
      result = await FirebaseFunctions.instance.httpsCallable('createGeminiEphemeralToken').call({});
    } on FirebaseFunctionsException catch (e) {
      _phaseController.add(LiveCallPhase.error);
      if (e.code == 'failed-precondition') throw NoApiKeyConfiguredException();
      onError?.call('Could not start call: ${e.message}');
      rethrow;
    }

    final data = Map<String, dynamic>.from(result.data as Map);
    final token = data['token'] as String?;
    final adminInstructions = data['adminInstructions'] as String? ?? '';
    if (token == null) {
      _phaseController.add(LiveCallPhase.error);
      throw NoApiKeyConfiguredException();
    }

    final instructions = _buildInstructions(
      isHindi: _lastIsHindi,
      catalog: catalogLines,
      appFaq: appFaq,
      adminInstructions: adminInstructions,
    );

    return (token: token, instructions: instructions);
  }

  String _buildInstructions({
    required bool isHindi,
    required String catalog,
    required String appFaq,
    required String adminInstructions,
  }) {
    final lang = isHindi ? 'Hindi' : 'English';
    final languageLine =
        'RESPOND ONLY IN $lang. YOU MUST SPEAK UNMISTAKABLY IN $lang THE ENTIRE '
        'CALL — every single sentence, no exceptions, even if the buyer speaks '
        'a different language or the catalog text below is in English. '
        'Never switch languages mid-call.';
    final adminBlock = adminInstructions.isNotEmpty
        ? '\nCurrent notes from the shop admin (offers, greetings, tone) — follow these:\n$adminInstructions\n'
        : '';
    return '''You are Kusbilo's voice ordering assistant.

$languageLine

You help the buyer pick items and place an order, entirely by voice.

Speaking style: talk like a warm, friendly local shopkeeper on a phone call,
not like a machine reading a menu. Use natural pacing, react genuinely to what
the buyer says. Use casual filler occasionally ("haan", "theek hai", "chaliye").

Available products (id | names | price | tags | description):
${catalog.isEmpty ? 'No catalog was provided for this call.' : catalog}

App FAQ, use this if the buyer asks a general question about the app:
${appFaq.isEmpty ? 'No FAQ was provided for this call.' : appFaq}
$adminBlock
Rules:
- Only offer products that appear in the catalog above. Never invent products or prices.
- When the buyer clearly wants an item, call add_to_cart with its exact product id and quantity.
- When the buyer says they're done, read back the full order (items, quantities) and
  get a clear "yes" — THEN immediately call confirm_order. Do not say the order is
  placed before calling confirm_order.
- After confirm_order returns, only tell the buyer the order is confirmed if the
  status indicates success. If it failed, say there was a problem and offer to retry.
- Only call confirm_order once per order.
- Keep responses short — this is a voice call, not a chat.
- REMINDER: speak only in $lang, no matter what.
''';
  }

  Future<void> _connect() async {
    if (!_audioSessionConfigured) {
      await _setupAudioSession();
      _audioSessionConfigured = true;
    }

    final fetched = await _fetchTokenAndInstructions();
    if (fetched == null) return;
    final token = fetched.token;
    final instructions = fetched.instructions;

    _setupComplete = false;
    _connectTimeoutTimer?.cancel();
    _connectTimeoutTimer = Timer(_connectTimeout, () {
      if (_setupComplete || _manualDisconnect) return;
      onError?.call('Connection timed out. Please try again.');
      _phaseController.add(LiveCallPhase.error);
      _channel?.sink.close();
    });

    if (!_pcmReady) {
      await FlutterPcmSound.setup(sampleRate: _sampleRateOut, channelCount: 1);
      FlutterPcmSound.setFeedCallback((_) {});
      _pcmReady = true;
    }

    final uri = Uri.parse(
      'wss://generativelanguage.googleapis.com/ws/'
      'google.ai.generativelanguage.v1beta.GenerativeService.'
      'BidiGenerateContentConstrained?access_token=$token',
    );

    const maxAttempts = 2;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        _channel = WebSocketChannel.connect(uri);
        await _channel!.ready;
        break;
      } catch (e) {
        if (attempt == maxAttempts) {
          _connectTimeoutTimer?.cancel();
          onError?.call('Could not connect: $e');
          _phaseController.add(LiveCallPhase.error);
          return;
        }
        await Future.delayed(const Duration(milliseconds: 800));
      }
    }

    _send({
      'setup': {
        'model': 'models/$_model',
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {'voiceName': 'Sulafat'},
            },
          },
        },
        'systemInstruction': {
          'parts': [
            {'text': instructions},
          ],
        },
        'realtimeInputConfig': {
          'automaticActivityDetection': {
            'disabled': false,
            'startOfSpeechSensitivity': 'START_SENSITIVITY_LOW',
            'endOfSpeechSensitivity': 'END_SENSITIVITY_LOW',
            'prefixPaddingMs': 200,
            'silenceDurationMs': 500,
          },
          'activityHandling': 'START_OF_ACTIVITY_INTERRUPTS',
        },
        'tools': [
          {
            'functionDeclarations': [
              {
                'name': 'add_to_cart',
                'description': "Add a product to the buyer's cart.",
                'parameters': {
                  'type': 'OBJECT',
                  'properties': {
                    'product_id': {'type': 'STRING'},
                    'quantity': {'type': 'INTEGER'},
                  },
                  'required': ['product_id', 'quantity'],
                },
              },
              {
                'name': 'confirm_order',
                'description':
                    'Call once the buyer agrees to place the order. Check the '
                    'returned status before telling the buyer it is confirmed.',
                'parameters': {'type': 'OBJECT', 'properties': {}},
              },
            ],
          },
        ],
      },
    });

    _wsSub = _channel!.stream.listen(
      _handleServerMessage,
      onError: (e) {
        onError?.call('Connection error: $e');
        _phaseController.add(LiveCallPhase.error);
      },
      onDone: () => _handleSocketClosed(),
    );
  }

  void _handleSocketClosed() {
    final code = _channel?.closeCode;
    final reason = _channel?.closeReason;
    print('WebSocket closed: code=$code, reason=$reason');

    if (_isRefreshingSession) {
      _isRefreshingSession = false;
      _teardownMicOnly();
      _channel = null;
      if (!_manualDisconnect) _connect();
      return;
    }

    final unexpected = code != null && code != 1000;

    if (!_manualDisconnect && unexpected && _reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      onError?.call('Call dropped — reconnecting ($_reconnectAttempts/$_maxReconnectAttempts)...');
      _phaseController.add(LiveCallPhase.connecting);
      _teardownMicOnly();
      _channel = null;
      final backoff = Duration(milliseconds: 800 * _reconnectAttempts);
      Future.delayed(backoff, () {
        if (!_manualDisconnect) _connect();
      });
      return;
    }

    if (!_ended) _phaseController.add(LiveCallPhase.ended);
  }

  void _teardownMicOnly() {
    _micSub?.cancel();
    _micSub = null;
    _recorder.stop().catchError((_) => null);
    _denoiser?.dispose();
    _denoiser = null;
    _micChain = Future.value();
    _pendingMicChunks = 0;
    _consecutiveLoudChunks = 0;
  }

  void _scheduleSessionRefresh() {
    _sessionRefreshTimer?.cancel();
    _sessionRefreshTimer = Timer(_sessionRefreshAt, () {
      if (_manualDisconnect) return;
      _isRefreshingSession = true;
      _channel?.sink.close(1000, 'proactive session refresh');
    });
  }

  void _send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  Future<void> _startMicStreaming() async {
    _denoiser = await NoiselessSession.create(sampleRate: _sampleRateIn);
    final stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: _sampleRateIn,
      numChannels: 1,
      echoCancel: true,
      noiseSuppress: true,
      autoGain: true,
      androidConfig: AndroidRecordConfig(
        // The mic source real VoIP apps use — engages the phone's own
        // call-grade AEC/NS/AGC in the audio HAL itself, underneath our
        // app-level effects above and the RNNoise pass below, instead of
        // capturing from the plain mic source and relying on the app-level
        // effects alone.
        audioSource: AndroidAudioSource.voiceCommunication,
        audioManagerMode: AudioManagerMode.modeInCommunication,
        // Route to a connected Bluetooth headset's mic (SCO) if there is
        // one, instead of silently falling back to the phone's own mic.
        manageBluetooth: true,
        speakerphone: false,
      ),
    ));
    _micSub = stream.listen((chunk) {
      if (_channel == null || _isMuted) return;

      // If chunks are already piling up waiting on the denoiser, this
      // device can't keep up with it in real time. Skip denoising THIS
      // chunk and send it raw — that keeps the chain's per-chunk work
      // near-zero so it drains the backlog instead of growing it further.
      // Sending stale-but-clean audio late is worse than sending fresh-but-
      // noisy audio on time: a growing delay is what confuses Gemini's
      // turn-taking (that's the actual cause of "bolta bhatak ke" / goes
      // silent), not a few unfiltered chunks.
      final skipDenoise = _pendingMicChunks >= _maxPendingMicChunks;
      _pendingMicChunks++;

      // Chain each chunk's denoise+send so chunks always leave in the
      // order they arrived, even though denoising is async.
      _micChain = _micChain.then((_) async {
        Uint8List clean;
        double voiceProbability;
        final denoiser = _denoiser;
        if (_channel == null) {
          _pendingMicChunks--;
          return;
        }
        if (skipDenoise || denoiser == null) {
          clean = chunk;
          voiceProbability = _peakAmplitude(chunk) > _speechAmplitudeThreshold ? 1.0 : 0.0;
        } else {
          try {
            final result = await denoiser.process(chunk);
            clean = result.audio;
            voiceProbability = result.voiceProbability;
          } catch (_) {
            // Denoiser hiccup — fall back to the raw chunk rather than
            // dropping audio and breaking the call.
            clean = chunk;
            voiceProbability = _peakAmplitude(chunk) > _speechAmplitudeThreshold ? 1.0 : 0.0;
          }
        }
        _pendingMicChunks--;

        // Real speech probability instead of a raw amplitude peak — a
        // loud non-voice noise (door slam, horn) no longer triggers a
        // false barge-in. On top of that, require several consecutive
        // loud chunks in a row — a single spike (typically the AI's own
        // echo bouncing back on loudspeaker) resets the streak instead of
        // firing immediately, so only sustained real speech interrupts.
        if (_aiIsSpeaking && voiceProbability > _voiceProbabilityThreshold) {
          _consecutiveLoudChunks++;
          if (_consecutiveLoudChunks >= _bargeInConsecutiveChunks) {
            _consecutiveLoudChunks = 0;
            _handleBargeIn();
          }
        } else {
          _consecutiveLoudChunks = 0;
        }

        _send({
          'realtimeInput': {
            'audio': {'mimeType': 'audio/pcm;rate=$_sampleRateIn', 'data': base64Encode(clean)},
          },
        });
      });
    });
  }

  void _handleBargeIn() {
    if (!_aiIsSpeaking) return;
    HapticFeedback.selectionClick();
    _aiIsSpeaking = false;
    _consecutiveLoudChunks = 0;
    _jitterBuffer.clear();
    _bufferingTurn = true;
    _turnGapsMs.clear();
    _lastChunkArrival = null;
    _reinitPlayback();
  }

  Future<void> _reinitPlayback() async {
    if (_reinitInProgress) return;
    _reinitInProgress = true;
    _playbackGeneration++;
    _pendingAudio.clear();
    try {
      await FlutterPcmSound.release();
      await FlutterPcmSound.setup(sampleRate: _sampleRateOut, channelCount: 1);
    } catch (e) {
      onError?.call('Could not reset audio playback: $e');
    } finally {
      _reinitInProgress = false;
    }
    _feedChain = Future.value();
    for (final bytes in _pendingAudio) {
      _queueFeed(bytes);
    }
    _pendingAudio.clear();
  }

  // Chunks are handed to the native player as soon as they've cleared the
  // jitter buffer, in arrival order (via the chained Future below) — no
  // artificial pacing here. Real device audio output already drains its
  // buffer at exactly the hardware sample rate on its own clock, so
  // hand-rolling a second, Dart-Timer-based pacer on top of that just adds
  // a second, *less* precise clock into the pipeline: any GC pause or UI
  // frame jank on the Dart side becomes an audible micro-stutter that the
  // native buffer alone would never have produced. Handing chunks over
  // immediately lets the OS's own real-time audio clock do the pacing.
  void _queueFeed(Uint8List bytes) {
    final generation = _playbackGeneration;
    _feedChain = _feedChain.then((_) {
      if (generation != _playbackGeneration) return Future.value();
      return FlutterPcmSound.feed(PcmArrayInt16(bytes: bytes.buffer.asByteData()))
          .catchError((e) => onError?.call('Audio feed failed: $e'));
    });
  }

  void _adaptCushion() {
    if (_turnGapsMs.isEmpty) return;
    final avgGap = _turnGapsMs.reduce((a, b) => a + b) / _turnGapsMs.length;
    final maxGap = _turnGapsMs.reduce((a, b) => a > b ? a : b);
    if (avgGap > 120 || maxGap > 400) {
      _cushionSeconds = (_cushionSeconds + 0.15).clamp(_minCushionSeconds, _maxCushionSeconds);
    } else if (avgGap < 50 && maxGap < 150) {
      _cushionSeconds = (_cushionSeconds - 0.05).clamp(_minCushionSeconds, _maxCushionSeconds);
    }
    _turnGapsMs.clear();
    _lastChunkArrival = null;
  }

  bool _ended = false;

  void _handleServerMessage(dynamic raw) {
    Map<String, dynamic> msg;
    try {
      final text = raw is String ? raw : utf8.decode(raw as List<int>);
      msg = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    if (msg.containsKey('setupComplete')) {
      _setupComplete = true;
      _connectTimeoutTimer?.cancel();
      _reconnectAttempts = 0;
      _scheduleSessionRefresh();
      _startMicStreaming().catchError((e) {
        onError?.call('Microphone streaming failed: $e');
        _phaseController.add(LiveCallPhase.error);
      });
      _phaseController.add(LiveCallPhase.listening);
      final kickoff = _lastIsHindi
          ? 'खरीदार को छोटा सा स्वागत करो और पूछो कि आज क्या ऑर्डर करना है। सिर्फ हिंदी में बोलो।'
          : "Greet the buyer briefly and ask what they'd like to order today. Speak only in English.";
      _send({
        'clientContent': {
          'turns': [
            {
              'role': 'user',
              'parts': [
                {'text': kickoff}
              ],
            }
          ],
          'turnComplete': true,
        },
      });
      return;
    }

    final serverContent = msg['serverContent'] as Map<String, dynamic>?;
    if (serverContent != null) {
      if (serverContent['interrupted'] == true) _handleBargeIn();

      final inputTranscription = serverContent['inputTranscription'] as Map<String, dynamic>?;
      if (inputTranscription?['text'] != null) onUserText?.call(inputTranscription!['text'] as String);

      final outputTranscription = serverContent['outputTranscription'] as Map<String, dynamic>?;
      if (outputTranscription?['text'] != null) onModelText?.call(outputTranscription!['text'] as String);

      final modelTurn = serverContent['modelTurn'] as Map<String, dynamic>?;
      final parts = modelTurn?['parts'] as List<dynamic>? ?? [];
      for (final part in parts) {
        final inlineData = (part as Map<String, dynamic>)['inlineData'] as Map<String, dynamic>?;
        if (inlineData?['data'] == null) continue;
        final bytes = base64Decode(inlineData!['data'] as String);

        final now = DateTime.now();
        if (_lastChunkArrival != null) _turnGapsMs.add(now.difference(_lastChunkArrival!).inMilliseconds);
        _lastChunkArrival = now;

        if (_reinitInProgress) {
          _pendingAudio.add(bytes);
        } else if (_bufferingTurn) {
          _jitterBuffer.add(bytes);
          if (_jitterBuffer.length >= _cushionBytes) {
            final cushion = _jitterBuffer.takeBytes();
            _queueFeed(cushion);
            _bufferingTurn = false;
          }
        } else {
          _queueFeed(bytes);
        }
        _aiIsSpeaking = true;
        _phaseController.add(LiveCallPhase.aiSpeaking);
      }

      if (serverContent['turnComplete'] == true) {
        if (_jitterBuffer.length > 0) _queueFeed(_jitterBuffer.takeBytes());
        _bufferingTurn = true;
        _aiIsSpeaking = false;
        _adaptCushion();
        _phaseController.add(LiveCallPhase.listening);
      }
      return;
    }

    final toolCall = msg['toolCall'] as Map<String, dynamic>?;
    if (toolCall != null) _handleToolCall(toolCall);
  }

  void _handleToolCall(Map<String, dynamic> toolCall) {
    final calls = toolCall['functionCalls'] as List<dynamic>? ?? [];
    for (final call in calls) {
      final c = call as Map<String, dynamic>;
      final id = c['id'] as String;
      final name = c['name'] as String;
      final args = Map<String, dynamic>.from(c['args'] as Map? ?? {});

      if (name == 'add_to_cart') {
        final productId = args['product_id']?.toString() ?? '';
        final quantity = int.tryParse(args['quantity']?.toString() ?? '1') ?? 1;
        final added = onOrderCall?.call(LiveOrderCall(functionCallId: id, productId: productId, quantity: quantity)) ?? false;
        _sendToolResponse(id, name, {'status': added ? 'added' : 'not_found'});
      } else if (name == 'confirm_order') {
        final completer = Completer<String>();
        _pendingConfirmations[id] = completer;
        onConfirmOrder?.call(LiveConfirmOrderCall(functionCallId: id));
        completer.future
            .timeout(const Duration(seconds: 25), onTimeout: () {
          _pendingConfirmations.remove(id);
          return 'failed';
        })
            .then((status) => _sendToolResponse(id, name, {'status': status}));
      }
    }
  }

  void _sendToolResponse(String id, String name, Map<String, dynamic> response) {
    _send({
      'toolResponse': {
        'functionResponses': [
          {'id': id, 'name': name, 'response': response},
        ],
      },
    });
  }

  void respondToConfirmOrder(String functionCallId, String status) {
    _pendingConfirmations.remove(functionCallId)?.complete(status);
  }

  Future<void> stop() async {
    _ended = true;
    _manualDisconnect = true;
    _connectTimeoutTimer?.cancel();
    _sessionRefreshTimer?.cancel();
    for (final completer in _pendingConfirmations.values) {
      if (!completer.isCompleted) completer.complete('failed');
    }
    _pendingConfirmations.clear();
    _teardownMicOnly();
    await _interruptionSub?.cancel();
    _interruptionSub = null;
    try {
      await _audioSession?.setActive(false);
    } catch (_) {
      // Best-effort — don't block call teardown on this.
    }
    _audioSession = null;
    if (Platform.isAndroid) {
      try {
        await _audioModeChannel.invokeMethod('stopAudioMode');
      } catch (_) {
        // Best-effort — don't block call teardown on this.
      }
    }
    await _wsSub?.cancel();
    _wsSub = null;
    await _channel?.sink.close();
    _channel = null;
    if (_pcmReady) {
      _playbackGeneration++;
      await FlutterPcmSound.release();
      _pcmReady = false;
    }
    if (!_phaseController.isClosed) _phaseController.add(LiveCallPhase.ended);
  }

  void dispose() {
    stop();
    _phaseController.close();
    _muteController.close();
    _recorder.dispose();
  }
}
