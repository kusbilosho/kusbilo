import 'package:firebase_core/firebase_core.dart';

/// Firebase config for Kusbilo, built from the google-services.json
/// values for the `com.kusbilo` Android app. If you ever run
/// `flutterfire configure`, let it regenerate this file instead —
/// this hand-written version covers Android only.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => android;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD6agrtsXIXG5Ex5oWGOOmX1n9W4EWhN3c',
    appId: '1:90426342126:android:dc3e758aad2a96dd4591ff',
    messagingSenderId: '90426342126',
    projectId: 'wintrix-ac752',
    storageBucket: 'wintrix-ac752.firebasestorage.app',
  );
}
