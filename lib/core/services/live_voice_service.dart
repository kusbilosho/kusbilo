import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../localization/app_strings.dart';
import '../../features/home/data/models/product.dart';

/// A function call the model made mid-conversation — e.g. "the buyer
/// wants 2kg of onions, add product X with quantity 2 to their cart."
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

/// The buyer told the model they're done and want to actually place
/// the order. Unlike [LiveOrderCall], finishing this one needs real
/// async work (GPS location + the placeOrder Cloud Function) that only
/// the screen/providers can do — so the service just hands over the
/// [functionCallId] and waits for [LiveVoiceService.respondToConfirmOrder]
/// to be called once that work is done, instead of answering the tool
/// call immediately like addToCart does.
class LiveConfirmOrderCall {
  final String functionCallId;
  const LiveConfirmOrderCall({required this.functionCallId});
}

/// Coarse call state for driving the call UI — connecting spinner,
/// pulsing mic while the buyer can speak, a different animation while
/// the AI is talking, etc.
enum LiveCallPhase { connecting, listening, aiSpeaking, ended, error }

/// Thrown when Firestore has no usable Gemini API key configured yet
/// (e.g. `config/geminiLiveApi.apiKey` is missing or empty) — lets the
/// screen show a clear "not set up" message instead of a raw socket
/// error.
class NoApiKeyConfiguredException implements Exception {
  @override
  String toString() => 'No Gemini API key is configured.';
}

/// Wraps a single Gemini Live API voice session over a direct
/// WebSocket connection — one continuous, interruptible, streaming
/// conversation instead of a record → send → wait → play cycle. The
/// model listens continuously (it decides when the buyer has finished
/// a thought), can be talked over mid-reply, and speaks back with
/// almost no perceptible delay, because audio flows both directions on
/// one open connection — this is what actually makes it feel like a
/// phone call.
///
/// Deliberately NOT Firebase AI Logic: that requires the Firebase
/// project to be on the paid Blaze plan just to open a Live session.
/// This talks to `generativelanguage.googleapis.com` directly with a
/// plain Gemini API key — except the key itself lives in a Firestore
/// document (`config/geminiLiveApi`, field `apiKey`) instead of being
/// hardcoded in the app or entered by each buyer. That's what lets the
/// web admin panel swap the key the moment one runs out of quota, with
/// zero app update needed and nothing for a buyer to set up.
///
/// Ordering works via two tools the model can call whenever the buyer
/// names something or is ready to check out:
///  - addToCart: applied immediately, no confirmation needed.
///  - confirmOrder: surfaced via [onConfirmOrder] so the screen can run
///    the same location-detect + placeOrder flow the old checkout used,
///    then report back success/failure with [respondToConfirmOrder].
class LiveVoiceService {
  static const _model = 'gemini-3.1-flash-live-preview';

  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;
  final AudioRecorder _recorder = AudioRecorder();
  final SoLoud _player = SoLoud.instance;
  StreamSubscription<Uint8List>? _micSub;
  AudioSource? _playbackSource;
  SoundHandle? _playbackHandle;
  bool _playerReady = false;
  bool _setupComplete = false;
  bool _manualDisconnect = false;
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 2;

  // Mic streams continuously, even while the AI is talking — that's
  // what makes it feel like a real call instead of a walkie-talkie.
  // Barge-in relies on two layers: on-device echoCancel (set on the
  // recorder below) stops the AI's own voice from being picked back
  // up off the speaker, and Gemini's own server-side VAD reports
  // `interrupted: true` the moment it hears the buyer actually
  // talking, which _handleBargeIn() uses to cut AI playback instantly.
  // NOTE: on a phone with weak echo cancellation over loudspeaker,
  // this can occasionally make the AI hear its own voice as an
  // interruption. If that turns out to be a real problem for buyers,
  // the fix is prompting a headset/earpiece, not muting the mic —
  // muting it is what caused the multi-second "recorded but never
  // arrives" gaps.

  // If the socket opens fine but Gemini never sends setupComplete back
  // (a stuck negotiation, not a socket error/close) the call used to sit
  // on the connecting spinner forever with no way out. This forces an
  // error after a reasonable wait instead.
  static const _connectTimeout = Duration(seconds: 15);
  Timer? _connectTimeoutTimer;

  // Remembered so a silent reconnect can rebuild the exact same session.
  String? _lastApiKey;
  String? _lastSystemPrompt;

  // Gemini Live sessions die every ~10 minutes no matter what — that's
  // a hard platform limit, not something any client-side fix can avoid.
  // sessionResumption is Google's own answer to it: the server hands
  // us a handle we can replay on the *next* connection to restore full
  // conversation context (cart items discussed, what's already been
  // said) instead of the buyer sounding like they're talking to a
  // stranger who forgot everything the moment the socket reopens.
  String? _sessionResumeHandle;

  /// Called whenever the model asks to add something to the cart.
  void Function(LiveOrderCall call)? onOrderCall;

  /// Called when the buyer says they're ready to place the order.
  void Function(LiveConfirmOrderCall call)? onConfirmOrder;

  /// Called with the model's live transcript text as it speaks, if
  /// available — used to show a rough "what it's saying" caption.
  void Function(String text)? onModelText;

  /// Called with a transcript of what the model heard the BUYER say —
  /// lets the call screen show quick "सुन लिया" style feedback so a
  /// buyer isn't left wondering whether their voice actually reached
  /// the model at all.
  void Function(String text)? onUserText;

  /// Called if the session drops or errors for any reason.
  void Function(String error)? onError;

  final _phaseController = StreamController<LiveCallPhase>.broadcast();
  Stream<LiveCallPhase> get phaseStream => _phaseController.stream;

  bool _isMuted = false;
  bool get isMuted => _isMuted;
  final _muteController = StreamController<bool>.broadcast();
  Stream<bool> get muteStream => _muteController.stream;

  void toggleMute() {
    _isMuted = !_isMuted;
    _muteController.add(_isMuted);
  }

  bool get isActive => _channel != null;

  /// Starts a live conversation. [products] should be the buyer's
  /// current catalog (from CatalogProvider) so the model knows exactly
  /// what's available right now — this is rebuilt fresh every time a
  /// session starts, never hardcoded. [strings]/[isHindi] pick the
  /// language the model should actually speak, matching whatever the
  /// buyer has the app set to.
  ///
  /// Throws [NoApiKeyConfiguredException] if nobody has set an API key
  /// in the admin panel yet.
  Future<void> start(
    List<Product> products,
    AppStrings strings, {
    required bool isHindi,
  }) async {
    _manualDisconnect = false;
    _phaseController.add(LiveCallPhase.connecting);

    final config = await _fetchConfig();
    final apiKey = config['apiKey'];
    if (apiKey == null || apiKey.trim().isEmpty) {
      _phaseController.add(LiveCallPhase.error);
      throw NoApiKeyConfiguredException();
    }

    final hasMicPermission = await _recorder.hasPermission();
    if (!hasMicPermission) {
      _phaseController.add(LiveCallPhase.error);
      throw Exception('Microphone permission denied');
    }

    if (!_playerReady) {
      await _player.init();
      _playerReady = true;
    }

    // Playback engine has to be alive and already playing *before* the
    // socket even opens — not after setupComplete like it used to be.
    // That old order created a real, silent-failure race: setupComplete
    // triggered _startMicStreaming() asynchronously and unawaited, which
    // is what actually built the buffer stream. If Gemini's first audio
    // chunk arrived before that await finished (easy — Gemini can reply
    // fast), _playbackSource was still null, the `if (_playbackSource !=
    // null)` guard quietly skipped it, and the AI's reply was simply
    // never heard — no error anywhere, connect looked totally fine. This
    // guarantees the buffer exists ahead of time, no matter how fast the
    // model answers.
    await _initPlayback();

    final systemPrompt = _buildSystemPrompt(
      products,
      strings,
      isHindi: isHindi,
      customInstructions: config['instructions'],
    );
    await _connect(apiKey: apiKey, systemPrompt: systemPrompt);
  }

  Future<void> _initPlayback() async {
    _playbackSource = await _player.setBufferStream(
      sampleRate: 24000,
      channels: Channels.mono,
      format: BufferType.s16le,
      bufferingType: BufferingType.released,
      // flutter_soloud defaults bufferingTimeNeeds to 2 FULL SECONDS if
      // left unset — meaning playback silently waits for 2s of audio
      // to accumulate before making a sound at all. That's the single
      // biggest source of "AI's reply arrives late" on a call: every
      // single reply eats a hidden 2s tax before the buyer hears
      // anything. 0.1s is enough to avoid stutter on a steady stream
      // without the delay feeling like a real phone call.
      bufferingTimeNeeds: 0.1,
    );
    _playbackHandle = await _player.play(_playbackSource!);
  }

  /// Reads `config/geminiLiveApi` fresh from Firestore every call (not
  /// cached) so both the key *and* the admin's custom instructions
  /// always reflect whatever was most recently saved in the admin
  /// panel, with no app restart needed. Returns `{apiKey, instructions}`
  /// — either value may be null if unset.
  Future<Map<String, String?>> _fetchConfig() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('geminiLiveApi').get();
      final data = doc.data();
      return {
        'apiKey': data?['apiKey'] as String?,
        'instructions': data?['instructions'] as String?,
      };
    } catch (_) {
      return {'apiKey': null, 'instructions': null};
    }
  }

  String _buildSystemPrompt(
    List<Product> products,
    AppStrings strings, {
    required bool isHindi,
    String? customInstructions,
  }) {
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

    final languageLine = isHindi
        ? 'खरीदार ने हिंदी चुनी है — हमेशा हिंदी में बोलो (हिंग्लिश ठीक है), टूटी-फूटी भाषा में भी मतलब समझो।'
        : 'The buyer has chosen English — always reply in English, plain and conversational.';

    final trimmedExtra = customInstructions?.trim() ?? '';
    // Kept as its own clearly-labelled block, appended after the core
    // rules rather than mixed into them, so an admin's wording can
    // never accidentally override the tool-calling behaviour above —
    // it can only add to it (tone, extra store info, current offers,
    // festival greetings, etc.).
    final extraBlock = trimmedExtra.isEmpty
        ? ''
        : '''

Extra instructions from the shop admin — follow these too, on top of everything above:
$trimmedExtra''';

    return '''
You are Kusbilo's real, sensible voice assistant on a live phone call with a buyer — not a robot reading a script. $languageLine

What's true about the app today (this can change, don't treat it as a rigid rulebook):
$appFaq

What's available right now (from the live catalog):
${catalogLines.isEmpty ? '(nothing available right now)' : catalogLines}

Tools:
- addToCart: call this the moment the buyer names something they want. If they don't say a quantity, assume 1. You can call it multiple times in one call for multiple items.
- confirmOrder: call this only when the buyer clearly says they're done and want to place the order (e.g. "bas order kar do", "that's all, place the order"). After you call it, wait for its result before speaking about the order's outcome:
  - status "empty": the cart has nothing in it — tell the buyer and ask what they'd like to add.
  - status "success": the order was placed — congratulate them briefly and mention delivery usually takes 20-60 minutes.
  - status "location_error": their location couldn't be detected — tell them to finish the order from the checkout screen instead.
  - status "failed": something went wrong — apologise briefly and ask them to try again in a moment.

For anything about the app, an order, or a product, answer naturally and helpfully in your own words — vary your phrasing, don't recite a script. Only for things totally unrelated to Kusbilo (cricket, politics, etc.) politely say you can only help with Kusbilo. Keep replies short and conversational, like a real phone call.$extraBlock
''';
  }

  Future<void> _connect({required String apiKey, required String systemPrompt}) async {
    _lastApiKey = apiKey;
    _lastSystemPrompt = systemPrompt;
    _setupComplete = false;

    _connectTimeoutTimer?.cancel();
    _connectTimeoutTimer = Timer(_connectTimeout, () {
      if (_setupComplete || _manualDisconnect) return;
      onError?.call('Connection timed out. Check your internet and try again.');
      _phaseController.add(LiveCallPhase.error);
      _channel?.sink.close();
    });

    final uri = Uri.parse(
      'wss://generativelanguage.googleapis.com/ws/'
      'google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent'
      '?key=$apiKey',
    );

    try {
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;
    } catch (e) {
      _connectTimeoutTimer?.cancel();
      _phaseController.add(LiveCallPhase.error);
      onError?.call('Could not connect: $e');
      return;
    }

    final setupMessage = {
      'setup': {
        'model': 'models/$_model',
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {'voiceName': 'Kore'},
            },
          },
        },
        // Lets the server send back a transcript of what it heard the
        // buyer say (handled below as inputTranscription) — without
        // this, there's no way to show the buyer "haan, sun liya"
        // confirmation, so any bit of lag makes it feel like their
        // voice never reached the model at all, even though the audio
        // was streaming the whole time.
        'inputAudioTranscription': {},
        'systemInstruction': {
          'parts': [
            {'text': systemPrompt},
          ],
        },
        'tools': [
          {
            'functionDeclarations': [
              {
                'name': 'addToCart',
                'description': "Adds the item the buyer asked for to their cart",
                'parameters': {
                  'type': 'OBJECT',
                  'properties': {
                    'productId': {
                      'type': 'STRING',
                      'description': 'The exact id from the catalog list above',
                    },
                    'quantity': {
                      'type': 'INTEGER',
                      'description': "How much they asked for; 1 if not said",
                    },
                  },
                  'required': ['productId'],
                },
              },
              {
                'name': 'confirmOrder',
                'description':
                    'Called when the buyer confirms they want to place the order with whatever is currently in the cart',
                'parameters': {'type': 'OBJECT', 'properties': {}},
              },
            ],
          },
        ],
        // Tunes how Gemini decides when you've started/stopped talking —
        // LOW sensitivity behaves more like a real call: it won't flinch
        // at background noise, but still responds promptly on a pause.
        'realtimeInputConfig': {
          'automaticActivityDetection': {
            'disabled': false,
            // Was START_SENSITIVITY_HIGH — that's what was actually
            // causing background noise (fan, TV, bazaar sounds) to get
            // misread as "the buyer started talking", which triggers
            // activityHandling below and cuts the AI off mid-sentence.
            // LOW needs a clearer, more speech-like sound before it
            // decides someone started talking, so stray noise stops
            // false-triggering barge-in. A real "buyer talked over the
            // AI" still gets caught fine — that's a much louder,
            // clearer signal than ambient noise.
            'startOfSpeechSensitivity': 'START_SENSITIVITY_LOW',
            'endOfSpeechSensitivity': 'END_SENSITIVITY_LOW',
            'prefixPaddingMs': 150,
            'silenceDurationMs': 350,
          },
          'activityHandling': 'START_OF_ACTIVITY_INTERRUPTS',
        },
        // Enables the server to hand us SessionResumptionUpdate
        // messages. Passing the last handle we were given makes THIS
        // connection continue the previous one's memory instead of
        // starting blank — omit `handle` on the very first connect of
        // a call (nothing to resume yet), always include it after.
        'sessionResumption': _sessionResumeHandle != null
            ? {'handle': _sessionResumeHandle}
            : <String, dynamic>{},
        // Without this, an audio-only session is hard-capped at 15
        // minutes of conversation total (token limit), full stop, no
        // resumption trick gets around it. This lets Gemini quietly
        // summarize/compress older turns once the context grows past
        // triggerTokens, instead of the call just dying mid-order once
        // the buyer's been chatting for a while.
        'contextWindowCompression': {
          'triggerTokens': '10000',
          'slidingWindow': {'targetTokens': '2000'},
        },
      },
    };
    _channel!.sink.add(jsonEncode(setupMessage));

    _wsSub = _channel!.stream.listen(
      _handleServerMessage,
      onError: (e) {
        _phaseController.add(LiveCallPhase.error);
        onError?.call('Connection error: $e');
      },
      onDone: () => _handleSocketClosed(),
    );
  }

  void _handleSocketClosed() {
    // A goAway swap already tore this subscription down deliberately
    // via _reconnectForContinuity — skip the generic drop-handling
    // below entirely so it doesn't show "Call ended" or double-connect.
    if (_swappingForContinuity) return;

    final code = _channel?.closeCode;
    _micSub?.cancel();
    _micSub = null;
    _recorder.stop().catchError((_) => null);
    _channel = null;

    final unexpected = code != null && code != 1000;
    if (!_manualDisconnect && unexpected && _reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      _phaseController.add(LiveCallPhase.connecting);
      final key = _lastApiKey;
      final prompt = _lastSystemPrompt;
      Future.delayed(Duration(milliseconds: 800 * _reconnectAttempts), () {
        if (_manualDisconnect || key == null || prompt == null) return;
        _connect(apiKey: key, systemPrompt: prompt);
      });
      return;
    }

    if (!_manualDisconnect) {
      onError?.call(unexpected ? 'Call dropped (code: $code)' : 'Call ended');
    }
    _phaseController.add(LiveCallPhase.ended);
  }

  /// Proactively swaps to a brand new connection when Gemini's `goAway`
  /// warns the current one is about to be force-closed. Cancels the old
  /// socket's own listener first so [_handleSocketClosed] never fires
  /// for it — this is a deliberate, planned swap, not a drop, so none
  /// of that method's "unexpected disconnect" handling should run.
  bool _swappingForContinuity = false;
  Future<void> _reconnectForContinuity() async {
    if (_manualDisconnect || _swappingForContinuity) return;
    final key = _lastApiKey;
    final prompt = _lastSystemPrompt;
    if (key == null || prompt == null) return;

    _swappingForContinuity = true;
    await _micSub?.cancel();
    _micSub = null;
    await _wsSub?.cancel();
    _wsSub = null;
    await _channel?.sink.close(1000);
    _channel = null;
    try {
      await _recorder.stop();
    } catch (_) {}

    await _connect(apiKey: key, systemPrompt: prompt);
    _swappingForContinuity = false;
  }

  void _handleServerMessage(dynamic raw) {
    Map<String, dynamic> msg;
    try {
      final text = raw is String ? raw : utf8.decode(raw as List<int>);
      msg = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    if (msg.containsKey('error')) {
      _phaseController.add(LiveCallPhase.error);
      onError?.call('Server error: ${msg['error']}');
      return;
    }

    // Server hands us a fresh handle roughly every time it's safe to
    // do so — save the latest one so whichever connection comes next
    // (proactive goAway swap, or a plain dropped-socket reconnect) can
    // pick the conversation back up instead of starting over.
    if (msg.containsKey('sessionResumptionUpdate')) {
      final update = msg['sessionResumptionUpdate'] as Map<String, dynamic>;
      if (update['resumable'] == true && update['newHandle'] != null) {
        _sessionResumeHandle = update['newHandle'] as String;
      }
      return;
    }

    // Google's ~60s warning before it force-closes this connection
    // (the ~10 minute hard cap). Swap to a new connection right now,
    // on our terms, using the resumption handle above — instead of
    // waiting for the abrupt close and having the buyer hear dead air
    // while the existing reconnect-on-drop logic kicks in.
    if (msg.containsKey('goAway')) {
      _reconnectForContinuity();
      return;
    }

    if (msg.containsKey('setupComplete')) {
      _connectTimeoutTimer?.cancel();
      _setupComplete = true;
      _reconnectAttempts = 0;
      _startMicStreaming().catchError((e) {
        _phaseController.add(LiveCallPhase.error);
        onError?.call('Microphone streaming failed: $e');
      });
      _phaseController.add(LiveCallPhase.listening);
      return;
    }

    if (msg.containsKey('toolCall')) {
      final toolCall = msg['toolCall'] as Map<String, dynamic>;
      final calls = toolCall['functionCalls'] as List<dynamic>? ?? [];
      for (final raw in calls) {
        final call = raw as Map<String, dynamic>;
        final name = call['name'] as String?;
        final id = call['id'] as String? ?? '';
        final args = call['args'] as Map<String, dynamic>? ?? {};

        if (name == 'addToCart') {
          final productId = args['productId']?.toString() ?? '';
          final quantity = int.tryParse(args['quantity']?.toString() ?? '1') ?? 1;
          onOrderCall?.call(LiveOrderCall(functionCallId: id, productId: productId, quantity: quantity));
          _sendToolResponse(id, 'addToCart', {'status': 'added'});
        } else if (name == 'confirmOrder') {
          onConfirmOrder?.call(LiveConfirmOrderCall(functionCallId: id));
          // No response yet — the screen answers via respondToConfirmOrder
          // once it's actually tried to place the order.
        }
      }
      return;
    }

    final serverContent = msg['serverContent'] as Map<String, dynamic>?;
    if (serverContent == null) return;

    if (serverContent['interrupted'] == true) {
      _handleBargeIn();
    }

    final outputTranscription = serverContent['outputTranscription'] as Map<String, dynamic>?;
    if (outputTranscription != null && outputTranscription['text'] != null) {
      onModelText?.call(outputTranscription['text'] as String);
    }

    // What the model heard the BUYER say — separate from
    // outputTranscription above (that's the model's own reply). Surfaced
    // so the call screen can show "सुन लिया: <text>" the instant it's
    // heard, instead of the buyer having no idea their voice registered
    // until the AI actually starts answering a few hundred ms later.
    final inputTranscription = serverContent['inputTranscription'] as Map<String, dynamic>?;
    if (inputTranscription != null && inputTranscription['text'] != null) {
      onUserText?.call(inputTranscription['text'] as String);
    }

    final modelTurn = serverContent['modelTurn'] as Map<String, dynamic>?;
    if (modelTurn != null) {
      final parts = modelTurn['parts'] as List<dynamic>? ?? [];
      for (final part in parts) {
        final inlineData = (part as Map<String, dynamic>)['inlineData'] as Map<String, dynamic>?;
        if (inlineData != null && inlineData['data'] != null) {
          final bytes = base64Decode(inlineData['data'] as String);
          _phaseController.add(LiveCallPhase.aiSpeaking);
          if (_playbackSource != null) {
            _player.addAudioDataStream(_playbackSource!, bytes);
          }
        }
        final textPart = (part)['text'] as String?;
        if (textPart != null && textPart.isNotEmpty) {
          onModelText?.call(textPart);
        }
      }
    }

    if (serverContent['turnComplete'] == true) {
      _phaseController.add(LiveCallPhase.listening);
    }
  }

  /// The buyer started talking over the AI — Google's own barge-in
  /// detection already stopped the model server-side; here we just
  /// need to stop *our* playback immediately instead of finishing
  /// whatever audio is already buffered, so it actually feels
  /// interrupted rather than talking over them for another second.
  Future<void> _handleBargeIn() async {
    if (_playbackHandle != null) {
      await _player.stop(_playbackHandle!);
    }
    if (_playbackSource != null) {
      await _player.disposeSource(_playbackSource!);
    }
    _playbackSource = await _player.setBufferStream(
      sampleRate: 24000,
      channels: Channels.mono,
      format: BufferType.s16le,
      bufferingType: BufferingType.released,
      bufferingTimeNeeds: 0.1,
    );
    _playbackHandle = await _player.play(_playbackSource!);
  }

  Future<void> _startMicStreaming() async {
    final micStream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
      // These three run on-device, before any audio ever leaves the
      // phone — they clean up the signal at the source instead of
      // relying only on Gemini's server-side VAD to guess what's
      // speech and what's a fan/TV/street noise in the background.
      // echoCancel matters most on speaker calls: without it, the
      // mic picks the AI's own voice back up off the speaker and the
      // model reacts to itself as if the buyer just spoke.
      noiseSuppress: true,
      echoCancel: true,
      autoGain: true,
    ));
    _micSub = micStream.listen((chunk) {
      // Mic keeps recording while muted (instant unmute, no restart)
      // but a muted buyer's audio shouldn't reach the model at all.
      if (_isMuted || _channel == null) return;
      final message = {
        'realtimeInput': {
          'audio': {
            'data': base64Encode(chunk),
            'mimeType': 'audio/pcm;rate=16000',
          },
        },
      };
      _channel?.sink.add(jsonEncode(message));
    });
  }

  void _sendToolResponse(String id, String name, Map<String, dynamic> response) {
    _channel?.sink.add(jsonEncode({
      'toolResponse': {
        'functionResponses': [
          {'id': id, 'name': name, 'response': response},
        ],
      },
    }));
  }

  /// Answers a pending confirmOrder tool call once the screen has
  /// actually tried to place the order (or found the cart empty /
  /// location undetectable). [status] should be one of "success",
  /// "empty", "location_error", or "failed" — the system prompt tells
  /// the model what to say for each.
  void respondToConfirmOrder(String functionCallId, String status) {
    _sendToolResponse(functionCallId, 'confirmOrder', {'status': status});
  }

  /// Ends the call — stops the mic, closes the socket, stops playback.
  Future<void> stop() async {
    _manualDisconnect = true;
    _sessionResumeHandle = null;
    _connectTimeoutTimer?.cancel();
    _connectTimeoutTimer = null;
    await _micSub?.cancel();
    _micSub = null;
    try {
      await _recorder.stop();
    } catch (_) {}
    await _wsSub?.cancel();
    _wsSub = null;
    await _channel?.sink.close();
    _channel = null;
    if (_playbackHandle != null) {
      await _player.stop(_playbackHandle!);
      _playbackHandle = null;
    }
    if (_playbackSource != null) {
      await _player.disposeSource(_playbackSource!);
      _playbackSource = null;
    }
    _phaseController.add(LiveCallPhase.ended);
  }

  void dispose() {
    stop();
    _recorder.dispose();
    _phaseController.close();
    _muteController.close();
  }
}
