// lib/services/push_notification_service.dart
//
// Full push-notification pipeline:
//
// Android / iOS:
//   - Firebase Cloud Messaging (FCM) receives messages.
//   - Background / terminated notifications are handled by the OS.
//   - Foreground notifications are shown using
//     flutter_local_notifications.
//   - Foreground messages are also sent to the in-app banner stream.
//
// Windows:
//   - flutter_local_notifications is initialized with Windows settings.
//   - Firebase Messaging operations are skipped because FCM is not
//     supported on Windows in the same way as Android/iOS.
//
// This prevents the Windows startup error:
// "Windows settings must be set when targeting Windows platform."

import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Simple data class the in-app banner and notification tap navigation
/// logic consume.
class PushMessageData {
  final String title;
  final String body;
  final Map<String, dynamic> payload;

  PushMessageData({
    required this.title,
    required this.body,
    required this.payload,
  });

  factory PushMessageData.fromRemoteMessage(RemoteMessage message) {
    return PushMessageData(
      title: message.notification?.title ?? message.data['title'] ?? '',
      body: message.notification?.body ?? message.data['body'] ?? '',
      payload: message.data,
    );
  }
}

/// Must be a TOP-LEVEL function.
///
/// Android calls this in a separate isolate when a data message arrives
/// while the application is fully killed.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message,
    ) async {
  debugPrint(
    'Background message received: ${message.messageId}',
  );
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance =
  PushNotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  /// Global navigation key.
  ///
  /// Assign this to MaterialApp:
  ///
  /// navigatorKey: PushNotificationService.instance.navigatorKey
  final GlobalKey<NavigatorState> navigatorKey =
  GlobalKey<NavigatorState>();

  /// Foreground notification stream.
  ///
  /// Your in-app banner widget can listen to this stream.
  final StreamController<PushMessageData>
  _foregroundMessageController =
  StreamController<PushMessageData>.broadcast();

  Stream<PushMessageData> get foregroundMessages =>
      _foregroundMessageController.stream;

  // ------------------------------------------------------------
  // Notification channel
  // ------------------------------------------------------------

  static const String _channelId =
      'push_notifications_channel';

  static const String _channelName =
      'General Notifications';

  // ------------------------------------------------------------
  // Windows notification configuration
  // ------------------------------------------------------------

  static const String _windowsAppName =
      'CDA Inventory';

  static const String _windowsAppUserModelId =
      'CDA.CDAInventory';

  static const String _windowsGuid =
      '6f2c8e1a-7b4d-4f9c-9d31-5a8e2c6b7410';

  bool _initialized = false;

  // ============================================================
  // INITIALIZATION
  // ============================================================

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    _initialized = true;

    // Web: dart:io Platform is unsupported and flutter_local_notifications
    // has no web implementation. Skip push setup on web.
    if (kIsWeb) {
      debugPrint('Web detected: push notification setup skipped.');
      return;
    }

    // ----------------------------------------------------------
    // 1. LOCAL NOTIFICATION INITIALIZATION
    // ----------------------------------------------------------

    const AndroidInitializationSettings androidInit =
    AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const DarwinInitializationSettings iosInit =
    DarwinInitializationSettings();

    // IMPORTANT:
    //
    // WindowsInitializationSettings MUST be supplied when the
    // application is built for Windows.
    //
    // Without this, flutter_local_notifications throws:
    //
    // Invalid argument(s):
    // Windows settings must be set when targeting Windows platform.
    //
    const WindowsInitializationSettings windowsInit =
    WindowsInitializationSettings(
      appName: _windowsAppName,
      appUserModelId: _windowsAppUserModelId,
      guid: _windowsGuid,
    );

    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: androidInit,
      iOS: iosInit,
      windows: windowsInit,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse:
      _onLocalNotificationTapped,
    );

    // ----------------------------------------------------------
    // 2. ANDROID NOTIFICATION CHANNEL
    // ----------------------------------------------------------

    if (defaultTargetPlatform != TargetPlatform.windows) {
      const AndroidNotificationChannel androidChannel =
      AndroidNotificationChannel(
        _channelId,
        _channelName,
        description:
        'Push notifications delivered while the app is open',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
        androidChannel,
      );
    }

    // ----------------------------------------------------------
    // 3. WINDOWS
    // ----------------------------------------------------------

    if (defaultTargetPlatform == TargetPlatform.windows) {
      debugPrint(
        'Windows platform detected.',
      );

      debugPrint(
        'Windows local notifications initialized.',
      );

      // Firebase Cloud Messaging setup is intentionally skipped
      // on Windows.
      //
      // The Windows application can now start normally without
      // the Firebase Messaging / Windows platform conflict.
      return;
    }

    // ----------------------------------------------------------
    // 4. FIREBASE CLOUD MESSAGING
    // ----------------------------------------------------------

    final FirebaseMessaging messaging =
        FirebaseMessaging.instance;

    // Ask notification permission.
    //
    // iOS requires this explicitly.
    // Android 13+ also requires notification permission.
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // ----------------------------------------------------------
    // 5. BACKGROUND FCM HANDLER
    // ----------------------------------------------------------

    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );

    // ----------------------------------------------------------
    // 6. FOREGROUND FCM
    // ----------------------------------------------------------

    FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );

    // ----------------------------------------------------------
    // 7. NOTIFICATION OPENED FROM BACKGROUND
    // ----------------------------------------------------------

    FirebaseMessaging.onMessageOpenedApp.listen(
      _handleNotificationTapNavigation,
    );

    // ----------------------------------------------------------
    // 8. NOTIFICATION OPENED FROM TERMINATED STATE
    // ----------------------------------------------------------

    final RemoteMessage? initialMessage =
    await messaging.getInitialMessage();

    if (initialMessage != null) {
      _handleNotificationTapNavigation(
        initialMessage,
      );
    }

    // ----------------------------------------------------------
    // 9. FCM TOKEN
    // ----------------------------------------------------------

    try {
      final String? token =
      await messaging.getToken();

      debugPrint(
        'FCM token: $token',
      );

      // TODO:
      //
      // Upload the token to Firestore under the current
      // user's document so your Cloud Function/server
      // can target this device.
    } catch (e) {
      debugPrint(
        'Unable to get FCM token: $e',
      );
    }

    // ----------------------------------------------------------
    // 10. TOKEN REFRESH
    // ----------------------------------------------------------

    messaging.onTokenRefresh.listen(
          (String newToken) {
        debugPrint(
          'FCM token refreshed: $newToken',
        );

        // TODO:
        //
        // Upload newToken to Firestore.
      },
    );
  }

  // ============================================================
  // FOREGROUND MESSAGE
  // ============================================================

  void _handleForegroundMessage(
      RemoteMessage message,
      ) {
    final PushMessageData data =
    PushMessageData.fromRemoteMessage(
      message,
    );

    // ----------------------------------------------------------
    // SHOW SYSTEM NOTIFICATION
    // ----------------------------------------------------------

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
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(
        data.payload,
      ),
    );

    // ----------------------------------------------------------
    // IN-APP BANNER
    // ----------------------------------------------------------

    _foregroundMessageController.add(
      data,
    );
  }

  // ============================================================
  // LOCAL NOTIFICATION TAP
  // ============================================================

  void _onLocalNotificationTapped(
      NotificationResponse response,
      ) {
    final String? payload =
        response.payload;

    if (payload == null || payload.isEmpty) {
      return;
    }

    try {
      final Map<String, dynamic> data =
      jsonDecode(payload) as Map<String, dynamic>;

      _navigateForPayload(data);
    } catch (e) {
      debugPrint(
        'Unable to parse notification payload: $e',
      );
    }
  }

  // ============================================================
  // FCM NOTIFICATION TAP
  // ============================================================

  void _handleNotificationTapNavigation(
      RemoteMessage message,
      ) {
    _navigateForPayload(
      message.data,
    );
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _navigateForPayload(
      Map<String, dynamic> data,
      ) {
    final dynamic screen =
    data['screen'];

    if (screen == null) {
      return;
    }

    if (screen is! String || screen.isEmpty) {
      return;
    }

    navigatorKey.currentState?.pushNamed(
      screen,
      arguments: data,
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  void dispose() {
    if (!_foregroundMessageController.isClosed) {
      _foregroundMessageController.close();
    }
  }
}