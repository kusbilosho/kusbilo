import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class SavedAddress {
  final String id;
  final String label;
  final double lat;
  final double lng;
  final String detectedLabel;

  const SavedAddress({
    required this.id,
    required this.label,
    required this.lat,
    required this.lng,
    required this.detectedLabel,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'lat': lat,
        'lng': lng,
        'detectedLabel': detectedLabel,
      };

  factory SavedAddress.fromMap(Map<String, dynamic> map) => SavedAddress(
        id: map['id'] as String,
        label: map['label'] as String,
        lat: (map['lat'] as num).toDouble(),
        lng: (map['lng'] as num).toDouble(),
        detectedLabel: map['detectedLabel'] as String? ?? '',
      );
}

/// A buyer's saved delivery addresses (e.g. "घर", "दुकान"), each just a
/// label plus a GPS-detected point — consistent with how location works
/// everywhere else in the app (checkout, voice ordering): the buyer
/// never types a street address, only labels a detected point so they
/// can pick it again quickly next time.
class AddressesProvider extends ChangeNotifier {
  final _firestore = FirebaseFirestore.instance;

  List<SavedAddress> _addresses = [];
  bool _loaded = false;

  List<SavedAddress> get addresses => List.unmodifiable(_addresses);

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> load() async {
    if (_loaded) return;
    final uid = _uid;
    if (uid == null) return;

    final doc = await _firestore.collection('addresses').doc(uid).get();
    final list = (doc.data()?['items'] as List<dynamic>? ?? [])
        .map((e) => SavedAddress.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    _addresses = list;
    _loaded = true;
    notifyListeners();
  }

  Future<void> add(SavedAddress address) async {
    final uid = _uid;
    if (uid == null) return;

    _addresses = [..._addresses, address];
    notifyListeners();

    await _firestore.collection('addresses').doc(uid).set({
      'items': _addresses.map((a) => a.toMap()).toList(),
    });
  }

  Future<void> remove(String id) async {
    final uid = _uid;
    if (uid == null) return;

    _addresses = _addresses.where((a) => a.id != id).toList();
    notifyListeners();

    await _firestore.collection('addresses').doc(uid).set({
      'items': _addresses.map((a) => a.toMap()).toList(),
    });
  }

  void resetSession() {
    _addresses = [];
    _loaded = false;
    notifyListeners();
  }
}
