import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:record/record.dart';
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

/// Wraps a single Gemini Live API voice session — one continuous,
/// interruptible, streaming conversation instead of a record → send →
/// wait → play cycle. The model listens continuously (it decides when
/// the buyer has finished a thought, not a fixed pauseFor timer), can
/// be talked over mid-reply, and speaks back with almost no perceptible
/// delay, because audio flows both directions on one open connection —
/// this is what actually makes it feel like a phone call.
///
/// Ordering still works the same way conceptually as before: the model
/// is given the live catalog and a single "addToCart" tool it can
/// call whenever the buyer names something to order. This class
/// surfaces those calls via [onOrderCall] so the widget can update the
/// cart and show it on screen, while the model keeps talking.
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

  /// Called with the model's live transcript text as it speaks, if
  /// available — used to show a rough "what it's saying" caption.
  void Function(String text)? onModelText;

  /// Called if the session drops or errors for any reason.
  void Function(String error)? onError;

  bool get isActive => _session != null;

  static const _appFaq = '''
GaonHaat एक गाँव का बाज़ार ऐप है जो खरीदारों को सीधे स्थानीय दुकानदारों से जोड़ता है। ये जानकारी बदल भी सकती है, इसे पक्का नियम मत मानो:
- भुगतान: अभी Cash on Delivery उपलब्ध है।
- डिलीवरी: पास के दुकानदार से आम तौर पर 20-60 मिनट में पहुंचता है।
- विक्रेता बनना: प्रोफ़ाइल में "विक्रेता बनें" पर टैप करके।
''';

  /// Starts a live conversation. [products] should be the buyer's
  /// current catalog (from CatalogProvider) so the model knows exactly
  /// what's available right now — this is rebuilt fresh every time a
  /// session starts, never hardcoded.
  Future<void> start(List<Product> products) async {
    if (!_playerReady) {
      await _player.init();
      _playerReady = true;
    }

    final catalogLines = products
        .where((p) => p.isActive && p.stock > 0)
        .map((p) => '${p.id} | ${p.nameHi} / ${p.nameEn} | ₹${p.priceValue}${p.unit} | tags: ${p.tags.join(', ')} | ${p.description}')
        .join('\n');

    final systemInstruction = Content.system('''
तुम GaonHaat के लिए आवाज़ से मदद करने वाले एक असली, समझदार सहायक हो — किसी स्क्रिप्ट को पढ़ने वाले रोबोट की तरह नहीं। खरीदार हिंदी या हिंग्लिश में, टूटी-फूटी भाषा में भी बोल सकता है — मतलब समझो, शब्द वैसे ही मिलने ज़रूरी नहीं।

ऐप के बारे में आज की जानकारी:
$_appFaq

अभी उपलब्ध सामान (लाइव डेटाबेस से):
${catalogLines.isEmpty ? '(अभी कोई सामान उपलब्ध नहीं है)' : catalogLines}

जब खरीदार कोई सामान मंगवाए, addToCart फ़ंक्शन कॉल करो — मात्रा न बताई तो 1 मानो। जब सवाल ऐप, ऑर्डर, सामान से जुड़ा हो, अपनी समझ से खुलकर स्वाभाविक जवाब दो, हर बार अलग शब्दों में। सिर्फ बिल्कुल unrelated चीज़ों (क्रिकेट, राजनीति, आदि) के लिए विनम्रता से मना करो कि तुम सिर्फ GaonHaat से जुड़ी बातों में मदद कर सकते हो। जवाब छोटे और बोलचाल जैसे रखो।
''');

    final addToCartTool = Tool.functionDeclarations([
      FunctionDeclaration(
        'addToCart',
        'खरीदार द्वारा मांगे गए सामान को कार्ट में जोड़ता है',
        parameters: {
          'productId': Schema.string(description: 'ऊपर दी गई सामान लिस्ट में से चुना गया exact id'),
          'quantity': Schema.integer(description: 'कितनी मात्रा मंगाई, न बताई तो 1'),
        },
      ),
    ]);

    final model = FirebaseAI.googleAI().liveGenerativeModel(
      model: 'gemini-3.1-flash-live-preview',
      liveGenerationConfig: LiveGenerationConfig(
        responseModalities: [ResponseModalities.audio],
        speechConfig: SpeechConfig(voiceName: 'Kore'),
      ),
      tools: [addToCartTool],
      systemInstruction: systemInstruction,
    );

    _session = await model.connect();

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
            _player.addAudioDataStream(_playbackSource!, part.bytes);
          } else if (part is TextPart) {
            onModelText?.call(part.text);
          }
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
          }
        }
      }
    }, onError: (e) => onError?.call(e.toString()));

    // Stream the mic straight to the session — 16kHz mono PCM is what
    // the Live API expects for input audio.
    final micStream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
    ));
    _micSub = micStream.listen((chunk) {
      _session?.sendAudioRealtime(InlineDataPart('audio/pcm', chunk));
    });
  }

  /// Ends the call — stops the mic, closes the session, stops playback.
  Future<void> stop() async {
    await _micSub?.cancel();
    _micSub = null;
    await _recorder.stop();
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
  }

  void dispose() {
    stop();
    _recorder.dispose();
  }
}
