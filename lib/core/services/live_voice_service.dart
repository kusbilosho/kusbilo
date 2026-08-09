import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:record/record.dart';
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

/// Wraps a single Gemini Live API voice session — one continuous,
/// interruptible, streaming conversation instead of a record → send →
/// wait → play cycle. The model listens continuously (it decides when
/// the buyer has finished a thought, not a fixed pauseFor timer), can
/// be talked over mid-reply, and speaks back with almost no perceptible
/// delay, because audio flows both directions on one open connection —
/// this is what actually makes it feel like a phone call.
///
/// This goes through Firebase AI Logic (FirebaseAI.googleAI()), not a
/// raw WebSocket with an API key baked into the app — Firebase's own
/// backend holds the Gemini credentials, so nothing secret ever ships
/// inside the APK/IPA.
///
/// Ordering works via two tools the model can call whenever the buyer
/// names something or is ready to check out:
///  - addToCart: applied immediately, no confirmation needed.
///  - confirmOrder: surfaced via [onConfirmOrder] so the screen can run
///    the same location-detect + placeOrder flow the old checkout used,
///    then report back success/failure with [respondToConfirmOrder].
class LiveVoiceService {
  LiveSession? _session;
  final AudioRecorder _recorder = AudioRecorder();
  final SoLoud _player = SoLoud.instance;
  StreamSubscription<Uint8List>? _micSub;
  StreamSubscription? _receiveSub;
  AudioSource? _playbackSource;
  SoundHandle? _playbackHandle;
  bool _playerReady = false;

  /// Called whenever the model asks to add something to the cart.
  void Function(LiveOrderCall call)? onOrderCall;

  /// Called when the buyer says they're ready to place the order.
  void Function(LiveConfirmOrderCall call)? onConfirmOrder;

  /// Called with the model's live transcript text as it speaks, if
  /// available — used to show a rough "what it's saying" caption.
  void Function(String text)? onModelText;

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

  bool get isActive => _session != null;

  /// Starts a live conversation. [products] should be the buyer's
  /// current catalog (from CatalogProvider) so the model knows exactly
  /// what's available right now — this is rebuilt fresh every time a
  /// session starts, never hardcoded. [strings]/[isHindi] pick the
  /// language the model should actually speak, matching whatever the
  /// buyer has the app set to.
  Future<void> start(
    List<Product> products,
    AppStrings strings, {
    required bool isHindi,
  }) async {
    _phaseController.add(LiveCallPhase.connecting);

    if (!_playerReady) {
      await _player.init();
      _playerReady = true;
    }

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

    final systemInstruction = Content.system('''
You are GaonHaat's real, sensible voice assistant on a live phone call with a buyer — not a robot reading a script. $languageLine

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

For anything about the app, an order, or a product, answer naturally and helpfully in your own words — vary your phrasing, don't recite a script. Only for things totally unrelated to GaonHaat (cricket, politics, etc.) politely say you can only help with GaonHaat. Keep replies short and conversational, like a real phone call.
''');

    final addToCartTool = FunctionDeclaration(
      'addToCart',
      "Adds the item the buyer asked for to their cart",
      parameters: {
        'productId': Schema.string(description: 'The exact id from the catalog list above'),
        'quantity': Schema.integer(description: 'How much they asked for; 1 if not said'),
      },
    );

    final confirmOrderTool = FunctionDeclaration(
      'confirmOrder',
      'Called when the buyer confirms they want to place the order with whatever is currently in the cart',
      parameters: {},
    );

    final model = FirebaseAI.googleAI().liveGenerativeModel(
      model: 'gemini-3.1-flash-live-preview',
      liveGenerationConfig: LiveGenerationConfig(
        responseModalities: [ResponseModalities.audio],
        speechConfig: SpeechConfig(voiceName: 'Kore'),
      ),
      tools: [
        Tool.functionDeclarations([addToCartTool, confirmOrderTool]),
      ],
      systemInstruction: systemInstruction,
    );

    try {
      _session = await model.connect();
    } catch (e) {
      _phaseController.add(LiveCallPhase.error);
      onError?.call(e.toString());
      return;
    }

    // Play back whatever audio the model streams to us as it arrives —
    // flutter_soloud supports feeding raw PCM chunks into a live audio
    // stream source so playback starts almost the instant the first
    // chunk lands, instead of waiting for the whole reply.
    _playbackSource = await _player.setBufferStream(
      sampleRate: 24000,
      channels: Channels.mono,
      format: BufferType.s16le,
      bufferingType: BufferingType.released,
    );
    _playbackHandle = await _player.play(_playbackSource!);

    _receiveSub = _session!.receive().listen((response) {
      final message = response.message;

      if (message is LiveServerContent) {
        final parts = message.modelTurn?.parts ?? [];
        for (final part in parts) {
          if (part is InlineDataPart && part.mimeType.startsWith('audio/pcm')) {
            _phaseController.add(LiveCallPhase.aiSpeaking);
            _player.addAudioDataStream(_playbackSource!, part.bytes);
          } else if (part is TextPart) {
            onModelText?.call(part.text);
          }
        }
        if (message.turnComplete == true) {
          _phaseController.add(LiveCallPhase.listening);
        }
      } else if (message is LiveServerToolCall) {
        for (final call in message.functionCalls ?? []) {
          if (call.name == 'addToCart') {
            final productId = call.args['productId']?.toString() ?? '';
            final quantity = int.tryParse(call.args['quantity']?.toString() ?? '1') ?? 1;
            onOrderCall?.call(LiveOrderCall(
              functionCallId: call.id ?? '',
              productId: productId,
              quantity: quantity,
            ));
            // Let the model know the tool call succeeded so it can
            // continue the conversation naturally ("ठीक है, और कुछ?").
            _session?.sendToolResponse([
              FunctionResponse(call.name, {'status': 'added'}, id: call.id),
            ]);
          } else if (call.name == 'confirmOrder') {
            onConfirmOrder?.call(LiveConfirmOrderCall(functionCallId: call.id ?? ''));
            // No tool response yet — placing the order needs GPS +
            // a network call, so the screen answers via
            // respondToConfirmOrder once that finishes.
          }
        }
      }
    }, onError: (e) {
      _phaseController.add(LiveCallPhase.error);
      onError?.call(e.toString());
    });

    // Stream the mic straight to the session — 16kHz mono PCM is what
    // the Live API expects for input audio.
    final micStream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
    ));
    _micSub = micStream.listen((chunk) {
      // Mic keeps recording while muted (instant unmute, no restart)
      // but a muted buyer's audio shouldn't reach the model at all.
      if (_isMuted) return;
      _session?.sendAudioRealtime(InlineDataPart('audio/pcm', chunk));
    });

    _phaseController.add(LiveCallPhase.listening);
  }

  /// Answers a pending confirmOrder tool call once the screen has
  /// actually tried to place the order (or found the cart empty /
  /// location undetectable). [status] should be one of "success",
  /// "empty", "location_error", or "failed" — the system prompt tells
  /// the model what to say for each.
  void respondToConfirmOrder(String functionCallId, String status) {
    _session?.sendToolResponse([
      FunctionResponse('confirmOrder', {'status': status}, id: functionCallId),
    ]);
  }

  /// Ends the call — stops the mic, closes the session, stops playback.
  Future<void> stop() async {
    await _micSub?.cancel();
    _micSub = null;
    try {
      await _recorder.stop();
    } catch (_) {}
    await _receiveSub?.cancel();
    _receiveSub = null;
    await _session?.close();
    _session = null;
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
