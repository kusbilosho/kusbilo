import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:livekit_client/livekit_client.dart';

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
/// to be called once that work is done.
class LiveConfirmOrderCall {
  final String functionCallId;
  const LiveConfirmOrderCall({required this.functionCallId});
}

/// Coarse call state for driving the call UI.
enum LiveCallPhase { connecting, listening, aiSpeaking, ended, error }

/// Thrown when the `createLiveKitToken` Cloud Function reports that
/// nobody has finished setting up the voice-call backend yet.
class NoApiKeyConfiguredException implements Exception {
  @override
  String toString() => 'Voice call is not configured yet.';
}

class LiveVoiceService {
  Room? _room;
  EventsListener<RoomEvent>? _listener;

  bool _isMuted = false;
  bool get isMuted => _isMuted;
  final _muteController = StreamController<bool>.broadcast();
  Stream<bool> get muteStream => _muteController.stream;

  final _phaseController = StreamController<LiveCallPhase>.broadcast();
  Stream<LiveCallPhase> get phaseStream => _phaseController.stream;

  bool get isActive => _room != null;

  void Function(LiveOrderCall call)? onOrderCall;
  void Function(LiveConfirmOrderCall call)? onConfirmOrder;
  void Function(String text)? onModelText;
  void Function(String text)? onUserText;
  void Function(String error)? onError;

  final Map<String, Completer<String>> _pendingConfirmations = {};

  static const _connectTimeout = Duration(seconds: 15);
  static const _agentJoinTimeout = Duration(seconds: 20);
  Timer? _agentJoinTimer;

  void toggleMute() {
    _isMuted = !_isMuted;
    _room?.localParticipant?.setMicrophoneEnabled(!_isMuted);
    _muteController.add(_isMuted);
  }

  Future<void> start(
    List<Product> products,
    AppStrings strings, {
    required bool isHindi,
  }) async {
    _phaseController.add(LiveCallPhase.connecting);

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
      result = await FirebaseFunctions.instance.httpsCallable('createLiveKitToken').call({
        'isHindi': isHindi,
        'appFaq': appFaq,
        'catalog': catalogLines,
      });
    } on FirebaseFunctionsException catch (e) {
      _phaseController.add(LiveCallPhase.error);
      if (e.code == 'failed-precondition') {
        throw NoApiKeyConfiguredException();
      }
      onError?.call('Could not start call: ${e.message}');
      rethrow;
    }

    final data = Map<String, dynamic>.from(result.data as Map);
    final wsUrl = data['url'] as String?;
    final token = data['token'] as String?;
    if (wsUrl == null || token == null) {
      _phaseController.add(LiveCallPhase.error);
      throw NoApiKeyConfiguredException();
    }

    final room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultAudioCaptureOptions: AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        ),
      ),
    );
    _room = room;
    _listener = room.createListener();
    _wireEvents(room, _listener!);
    _registerRpcMethods(room);

    try {
      await room.connect(wsUrl, token).timeout(_connectTimeout);
      await room.localParticipant?.setMicrophoneEnabled(true);
    } catch (e) {
      _phaseController.add(LiveCallPhase.error);
      onError?.call('Could not connect: $e');
      await stop();
      return;
    }

    _agentJoinTimer = Timer(_agentJoinTimeout, () {
      if (room.remoteParticipants.isEmpty) {
        onError?.call('Assistant did not join. Please try again in a moment.');
        _phaseController.add(LiveCallPhase.error);
        stop();
      }
    });
  }

  void _registerRpcMethods(Room room) {
    room.registerRpcMethod('addToCart', (data) async {
      try {
        final args = jsonDecode(data.payload) as Map<String, dynamic>;
        final productId = args['productId']?.toString() ?? '';
        final quantity = int.tryParse(args['quantity']?.toString() ?? '1') ?? 1;
        onOrderCall?.call(LiveOrderCall(
          functionCallId: data.requestId,
          productId: productId,
          quantity: quantity,
        ));
        return jsonEncode({'status': 'added'});
      } catch (e) {
        return jsonEncode({'status': 'failed'});
      }
    });

    room.registerRpcMethod('confirmOrder', (data) async {
      final completer = Completer<String>();
      _pendingConfirmations[data.requestId] = completer;
      onConfirmOrder?.call(LiveConfirmOrderCall(functionCallId: data.requestId));
      return completer.future.timeout(
        const Duration(seconds: 25),
        onTimeout: () {
          _pendingConfirmations.remove(data.requestId);
          return jsonEncode({'status': 'failed'});
        },
      );
    });
  }

  void _wireEvents(Room room, EventsListener<RoomEvent> listener) {
    listener
      ..on<RoomDisconnectedEvent>((event) {
        _phaseController.add(LiveCallPhase.ended);
      })
      ..on<ParticipantConnectedEvent>((event) {
        _agentJoinTimer?.cancel();
        _phaseController.add(LiveCallPhase.listening);
      })
      ..on<ActiveSpeakersChangedEvent>((event) {
        final agentSpeaking = event.speakers.any((p) => p is RemoteParticipant);
        _phaseController.add(agentSpeaking ? LiveCallPhase.aiSpeaking : LiveCallPhase.listening);
      })
      ..on<DataReceivedEvent>((event) {
        try {
          final msg = jsonDecode(utf8.decode(event.data)) as Map<String, dynamic>;
          final text = msg['text'] as String?;
          if (text == null) return;
          if (msg['type'] == 'model') {
            onModelText?.call(text);
          } else if (msg['type'] == 'user') {
            onUserText?.call(text);
          }
        } catch (_) {}
      });
  }

  void respondToConfirmOrder(String functionCallId, String status) {
    _pendingConfirmations.remove(functionCallId)?.complete(jsonEncode({'status': status}));
  }

  Future<void> stop() async {
    _agentJoinTimer?.cancel();
    _agentJoinTimer = null;
    for (final completer in _pendingConfirmations.values) {
      if (!completer.isCompleted) completer.complete(jsonEncode({'status': 'failed'}));
    }
    _pendingConfirmations.clear();
    await _listener?.dispose();
    _listener = null;
    await _room?.disconnect();
    await _room?.dispose();
    _room = null;
    _phaseController.add(LiveCallPhase.ended);
  }

  void dispose() {
    stop();
    _phaseController.close();
    _muteController.close();
  }
}
