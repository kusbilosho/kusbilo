import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:geolocator/geolocator.dart';

/// Streams the seller's GPS position into `orders/{orderId}` while they're
/// out delivering. Written directly to Firestore (not through a Cloud
/// Function) since this fires every few seconds/meters — going through a
/// callable each time would be slow and needlessly expensive. Firestore
/// security rules restrict this write to the order's assignedMerchantId,
/// and only the liveLat/liveLng/liveUpdatedAt fields (see firestore.rules).
class LiveLocationService {
  static StreamSubscription<Position>? _positionSub;
  static String? _activeOrderId;

  /// Starts broadcasting the seller's position for this order. Safe to
  /// call again if already broadcasting a different order — it swaps.
  static Future<void> start(String orderId) async {
    await stop();

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return;
    }

    _activeOrderId = orderId;
    final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);

    // Update roughly every 25 metres of movement — frequent enough for a
    // buyer watching the map, cheap enough on battery/data for a rural
    // network connection.
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 12),
    ).listen((position) {
      orderRef.update({
        'liveLat': position.latitude,
        'liveLng': position.longitude,
        'liveUpdatedAt': DateTime.now().toIso8601String(),
      });
    });
  }

  /// Stops broadcasting — call this once the order is marked delivered
  /// (or cancelled), and clears the last-known point so the buyer's map
  /// doesn't show a stale marker after delivery.
  static Future<void> stop({bool clearLastPoint = false}) async {
    await _positionSub?.cancel();
    _positionSub = null;

    if (clearLastPoint && _activeOrderId != null) {
      await FirebaseFirestore.instance.collection('orders').doc(_activeOrderId).update({
        'liveLat': null,
        'liveLng': null,
        'liveUpdatedAt': null,
      });
    }
    _activeOrderId = null;
  }

  static bool get isBroadcasting => _positionSub != null;
}
