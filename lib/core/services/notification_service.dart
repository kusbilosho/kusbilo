import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Registers this device to receive order-alert push notifications, and
/// makes sure those alerts actually show up as a system-tray-style
/// notification whether the app is closed, backgrounded, or open.
///
/// FCM shows a system notification automatically ONLY when the app is
/// backgrounded or killed. When the app is open (foreground), FCM stays
/// silent by design — [initForegroundHandler] plugs that gap using
/// flutter_local_notifications, so a merchant staring at their dashboard
/// still sees/hears the same alert a closed app would show.
class NotificationService {
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _foregroundHandlerReady = false;

  static const _channel = AndroidNotificationChannel(
    'order_alerts', // must match the channel id used below when showing
    'Order Alerts',
    description: 'नए ऑर्डर और ऑर्डर स्टेटस की सूचनाएँ',
    importance: Importance.high,
  );

  /// Call this once, early — right after Firebase.initializeApp() in
  /// main.dart. Safe to call multiple times; only sets up once.
  static Future<void> initForegroundHandler() async {
    if (_foregroundHandlerReady) return;
    _foregroundHandlerReady = true;

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _localNotifications.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;

      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    });
  }

  static Future<void> registerMerchantDevice() => _register('merchants');

  static Future<void> registerBuyerDevice() => _register('users');

  static Future<void> _register(String collection) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await messaging.getToken();
    if (token == null) return;

    await FirebaseFirestore.instance.collection(collection).doc(uid).set(
      {'fcmToken': token},
      SetOptions(merge: true),
    );

    messaging.onTokenRefresh.listen((newToken) {
      FirebaseFirestore.instance.collection(collection).doc(uid).set(
        {'fcmToken': newToken},
        SetOptions(merge: true),
      );
    });
  }
}
