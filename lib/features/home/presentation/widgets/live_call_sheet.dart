import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
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

  static const double _minCushionSeconds = 0.25;
  static const double _maxCushionSeconds = 1.0;
  double _cushionSeconds = _minCushionSeconds;
  int get _cushionBytes => (_sampleRateOut * _bytesPerSample * _cushionSeconds).round();
  bool _bufferingTurn = true;
  final BytesBuilder _jitterBuffer = BytesBuilder(copy: false);
  DateTime? _lastChunkArrival;
  final List<int> _turnGapsMs = [];

  DateTime? _turnPlaybackStart;
  int _turnBytesFed = 0;
  void _resetFeedPacing() {
    _turnPlaybackStart = null;
    _turnBytesFed = 0;
  }

  static const double _speechAmplitudeThreshold = 3000 / 32767;
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
            'silenceDurationMs': 400,
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
    final stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: _sampleRateIn,
      numChannels: 1,
      echoCancel: true,
      noiseSuppress: true,
      autoGain: true,
    ));
    _micSub = stream.listen((chunk) {
      if (_channel == null || _isMuted) return;

      final amplitude = _peakAmplitude(chunk);
      if (_aiIsSpeaking && amplitude > _speechAmplitudeThreshold) {
        _handleBargeIn();
      }

      _send({
        'realtimeInput': {
          'audio': {'mimeType': 'audio/pcm;rate=$_sampleRateIn', 'data': base64Encode(chunk)},
        },
      });
    });
  }

  void _handleBargeIn() {
    if (!_aiIsSpeaking) return;
    HapticFeedback.selectionClick();
    _aiIsSpeaking = false;
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
    _resetFeedPacing();
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

  void _queueFeed(Uint8List bytes) {
    final generation = _playbackGeneration;
    _feedChain = _feedChain.then((_) async {
      if (generation != _playbackGeneration) return;
      _turnPlaybackStart ??= DateTime.now();
      _turnBytesFed += bytes.length;
      final audioSecondsFed = _turnBytesFed / (_sampleRateOut * _bytesPerSample);
      final wallSecondsElapsed = DateTime.now().difference(_turnPlaybackStart!).inMilliseconds / 1000;
      final lead = audioSecondsFed - wallSecondsElapsed;
      final maxLead = _cushionSeconds + 1.0;
      if (lead > maxLead) {
        await Future.delayed(Duration(milliseconds: ((lead - maxLead) * 1000).round()));
      }
      if (generation != _playbackGeneration) return;
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
      _send({
        'clientContent': {
          'turns': [
            {
              'role': 'user',
              'parts': [
                {'text': "Greet the buyer briefly and ask what they'd like to order today."}
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
            _resetFeedPacing();
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
