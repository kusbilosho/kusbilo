import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Holds the current user's editable profile info (right now just their
/// display name), backed by the `users/{uid}` Firestore document — one
/// doc per user, keyed by their Firebase Auth uid. Phone number itself
/// isn't stored here since Firebase Auth already persists it; this is
/// only for things Firebase Auth doesn't track.
class UserProfileProvider extends ChangeNotifier {
  final _firestore = FirebaseFirestore.instance;

  String? _name;
  bool _loaded = false;

  String? get name => _name;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Loads the saved name, if any. Safe to call multiple times — only
  /// fetches once per session unless [forceRefresh] is set.
  Future<void> load({bool forceRefresh = false}) async {
    if (_loaded && !forceRefresh) return;
    final uid = _uid;
    if (uid == null) return;

    final doc = await _firestore.collection('users').doc(uid).get();
    _name = doc.data()?['name'] as String?;
    _loaded = true;
    notifyListeners();
  }

  Future<void> updateName(String name) async {
    final uid = _uid;
    if (uid == null) return;

    _name = name;
    notifyListeners();

    await _firestore.collection('users').doc(uid).set(
      {'name': name},
      SetOptions(merge: true),
    );
  }

  /// Resets local state on logout — does NOT delete the saved name in
  /// Firestore, only clears what's held in memory for this session.
  void resetSession() {
    _name = null;
    _loaded = false;
    notifyListeners();
  }
}
