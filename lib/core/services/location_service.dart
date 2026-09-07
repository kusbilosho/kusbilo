import 'dart:async';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Result of a successful location lookup: raw coordinates (stored on
/// the order so a delivery person can navigate to the exact spot) plus
/// a human-readable label built from the device's own reverse-geocoder
/// (village/town, district, state) so the buyer can see and confirm
/// what was detected.
class DetectedLocation {
  final double latitude;
  final double longitude;
  final String label;

  const DetectedLocation({
    required this.latitude,
    required this.longitude,
    required this.label,
  });
}

/// Thrown when location can't be determined, with a reason the UI can
/// turn into a friendly bilingual message instead of a raw exception.
enum LocationFailureReason { serviceDisabled, permissionDenied, permissionDeniedForever, unknown }

class LocationFailure implements Exception {
  final LocationFailureReason reason;
  const LocationFailure(this.reason);
}

/// Everything needed to auto-fill a delivery address from GPS, so the
/// buyer never has to type one. Both underlying packages are free and
/// run entirely on-device — GPS hardware + the phone OS's own geocoder,
/// no paid API key involved.
class LocationService {
  /// Requests permission if needed, reads the device's current GPS fix,
  /// and reverse-geocodes it into a short address label. Call this from
  /// a single "मेरी जगह पता लगाएं / Detect my location" button — most
  /// users in Gao won't type an address manually, so this should be the
  /// primary path on the checkout screen, not a fallback.
  static Future<DetectedLocation> detectCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationFailure(LocationFailureReason.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationFailure(LocationFailureReason.permissionDenied);
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(LocationFailureReason.permissionDeniedForever);
    }

    final position = await _getPositionWithFallback();

    final label = await _reverseGeocode(position.latitude, position.longitude);

    return DetectedLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      label: label,
    );
  }

  /// A high-accuracy GPS fix has no upper bound on its own — indoors or
  /// in low-signal rural areas it can take well over a minute. During a
  /// live voice call, [detectCurrentLocation] sits on the critical path
  /// of order confirmation, which the voice agent only waits ~25s for;
  /// past that it gives up and tells the buyer there was a technical
  /// problem, even though the app was still working in the background.
  /// So: try a high-accuracy fix with a short time budget first, and if
  /// that doesn't land in time, fall back to the last known position
  /// (near-instant) or, failing that, a faster medium-accuracy read —
  /// coordinates a little less precise are far better than the order
  /// silently timing out.
  static Future<Position> _getPositionWithFallback() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } on TimeoutException {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 6),
        ),
      );
    }
  }

  static Future<String> _reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return '$lat, $lng';
      final p = placemarks.first;
      // Prefer village/locality first (most relevant for rural
      // delivery), fall back through the next-most-specific fields if
      // any are empty — devices/regions don't always fill every field.
      final parts = [p.subLocality, p.locality, p.subAdministrativeArea, p.administrativeArea]
          .where((part) => part != null && part.trim().isNotEmpty)
          .toSet() // drop duplicates when two fields return the same value
          .take(3)
          .join(', ');
      return parts.isEmpty ? '$lat, $lng' : parts;
    } catch (_) {
      // Reverse geocoding can fail (no network, unsupported region) —
      // coordinates alone are still enough for delivery, so degrade
      // gracefully instead of blocking the order.
      return '$lat, $lng';
    }
  }
}
