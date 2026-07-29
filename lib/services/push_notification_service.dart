// lib/services/push_notification_service.dart
//
// Full push-notification pipeline:
//   - Firebase Cloud Messaging (FCM) receives the message from the server.
//   - When the app is BACKGROUNDED or TERMINATED, Android/iOS shows the
//     system banner automatically — nothing to do on our end for that case.
//   - When the app is in the FOREGROUND, FCM does NOT show a banner by
//     itself, so we catch it in onMessage and:
//       1. show a system notification via flutter_local_notifications
//          (so it still appears in the tray / matches the lock-screen look), and
//       2. push it onto a stream that the in-app banner widget listens to,
//          so the user also sees a slide-down banner without leaving the app.
//
// This reuses the same flutter_local_notifications instance style as
// DroneReminderService so there's only one notification channel setup
// to maintain.

import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Simple data class the in-app banner and any "tap to open" navigation
/// logic both consume.
class PushMessageData {
  final String title;
  final String body;
  final Map<String, dynamic> payload;

  PushMessageData({required this.title, required this.body, required this.payload});

  factory PushMessageData.fromRemoteMessage(RemoteMessage message) {
    return PushMessageData(
      title: message.notification?.title ?? message.data['title'] ?? '',
      body: message.notification?.body ?? message.data['body'] ?? '',
      payload: message.data,
    );
  }
}

/// Must be a TOP-LEVEL (or static) function — this is what Android calls
/// in a separate isolate when a data message arrives while the app is
/// fully killed. Keep it lightweight; you don't have BuildContext here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you need to do work here (e.g. update local DB), initialize only
  // what's needed — Firebase.initializeApp() must be called again since
  // this runs in a separate isolate.
  debugPrint('Background message received: ${message.messageId}');
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  /// Global key so a notification tap can navigate even if there's no
  /// BuildContext handy (e.g. app was terminated and just launched).
  /// Assign this to your MaterialApp(navigatorKey: ...).
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// The in-app banner widget listens to this to show a slide-down banner
  /// while the app is open and in the foreground.
  final StreamController<PushMessageData> _foregroundMessageController =
  StreamController<PushMessageData>.broadcast();
  Stream<PushMessageData> get foregroundMessages =>
      _foregroundMessageController.stream;

  static const _channelId = 'push_notifications_channel';
  static const _channelName = 'General Notifications';

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Ask for permission (iOS requires this explicitly; Android 13+ too).
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Register the background handler BEFORE runApp finishes — this is
    // why it must be a top-level function, and why init() should be
    // called early in main(), same as DroneReminderService.instance.init().
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 3. Set up the local-notifications channel used to show a system
    // banner while the app is in the foreground.
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );

    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Push notifications delivered while the app is open',
      importance: Importance.high, // required for heads-up / pop-over style
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // 4. FOREGROUND: app open and visible -> show tray notification +
    // notify the in-app banner stream.
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 5. User tapped a notification while app was backgrounded (not killed).
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTapNavigation);

    // 6. App was fully terminated and got opened BY tapping a notification.
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTapNavigation(initialMessage);
    }

    // 7. FCM token — send this to your backend so it knows where to push to.
    final token = await messaging.getToken();
    debugPrint('FCM token: $token');
    // TODO: upload `token` to Firestore under the current user's doc so
    // your server/Cloud Function can target this device.
    messaging.onTokenRefresh.listen((newToken) {
      // TODO: re-upload newToken the same way.
    });
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final data = PushMessageData.fromRemoteMessage(message);

    // Show it in the system tray so it looks identical to the
    // backgrounded/terminated case (matches the reference screenshots).
    _localNotifications.show(
      message.hashCode,
      data.title,
      data.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      payload: jsonEncode(data.payload),
    );

    // Also drive the in-app slide-down banner.
    _foregroundMessageController.add(data);
  }

  void _onLocalNotificationTapped(NotificationResponse response) {
    if (response.payload == null) return;
    final data = jsonDecode(response.payload!) as Map<String, dynamic>;
    _navigateForPayload(data);
  }

  void _handleNotificationTapNavigation(RemoteMessage message) {
    _navigateForPayload(message.data);
  }

  void _navigateForPayload(Map<String, dynamic> data) {
    // Route the tap based on whatever your server sends in the data
    // payload, e.g. {"screen": "/bills", "billId": "123"}.
    final screen = data['screen'];
    if (screen != null) {
      navigatorKey.currentState?.pushNamed(screen as String, arguments: data);
    }
  }

  void dispose() {
    _foregroundMessageController.close();
  }
}