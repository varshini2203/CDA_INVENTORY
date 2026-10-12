// lib/services/drone_reminder_service.dart

import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

class DroneReminderService {
  DroneReminderService._();

  static final DroneReminderService instance = DroneReminderService._();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const Duration reminderDelay = Duration(hours: 5);

  // Drone reminder vibration pattern.
  static final Int64List _droneVibrationPattern = Int64List.fromList(
    [0, 500, 200, 200, 200, 500, 200, 200, 200, 700],
  );

  // Windows notification settings.
  //
  // These values identify CDA Inventory as the Windows application.
  static const String _windowsAppName = 'CDA Inventory';
  static const String _windowsAppUserModelId = 'CDA.CDAInventory';

  static const String _windowsGuid =
      '6f2c8e1a-7b4d-4f9c-9d31-5a8e2c6b7410';

  /// Call once from main() before runApp().
  /// Safe to call multiple times.
  Future<void> init() async {
    if (_initialized || kIsWeb) return;

    tzdata.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Windows initialization settings.
    const windowsSettings = WindowsInitializationSettings(
      appName: _windowsAppName,
      appUserModelId: _windowsAppUserModelId,
      guid: _windowsGuid,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        windows: windowsSettings,
      ),
    );

    // Android-specific permissions.
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _plugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      await _plugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();
    }

    // iOS-specific permissions.
    else if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // Windows does not need Android/iOS permission requests.
    else if (defaultTargetPlatform == TargetPlatform.windows) {
      debugPrint('Windows drone reminder notifications initialized.');
    }

    _initialized = true;
  }

  /// Stable per-drone notification ID.
  int _notificationId(String droneId) {
    return droneId.hashCode & 0x7FFFFFFF;
  }

  /// Schedules a reminder after a drone is marked OUT.
  Future<void> scheduleReminder({
    required String droneId,
    required String droneName,
    required String newStatus,
    required DateTime actionTime,
    String? purpose,
  }) async {
    if (kIsWeb) return;

    if (!_initialized) {
      await init();
    }

    final id = _notificationId(droneId);

    // Cancel any previous reminder for this drone.
    await _plugin.cancel(id);

    // If drone is IN, there is nothing to remind about.
    if (newStatus.toUpperCase() != 'OUT') {
      return;
    }

    final fireAt = tz.TZDateTime.from(
      actionTime.add(reminderDelay),
      tz.local,
    );

    // Don't schedule reminders in the past.
    if (fireAt.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    final purposeText =
    (purpose != null && purpose.isNotEmpty) ? ' for $purpose' : '';

    final notificationBody =
        '"$droneName" was taken OUT$purposeText 4 hours ago and '
        'hasn\'t been marked IN yet. Please update it in the fleet screen.';

    // ------------------------------------------------------------
    // WINDOWS
    // ------------------------------------------------------------
    //
    // Do not use AndroidScheduleMode on Windows.
    //
    // For now, the Windows app is allowed to run normally without
    // attempting Android-specific scheduled notification behavior.
    //
    // This prevents Windows startup/runtime crashes.
    //
    if (defaultTargetPlatform == TargetPlatform.windows) {
      debugPrint(
        'Windows drone reminder requested for: $droneName',
      );

      return;
    }

    // ------------------------------------------------------------
    // ANDROID / iOS
    // ------------------------------------------------------------

    await _plugin.zonedSchedule(
      id,
      'Drone overdue for return',
      notificationBody,
      fireAt,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'drone_status_reminders_v2',
          'Drone status reminders',
          channelDescription:
          'Reminds you when a drone has been OUT for 4+ hours '
              'without being marked back IN.',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
          vibrationPattern: _droneVibrationPattern,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: droneId,
    );
  }

  /// Cancels any pending reminder for [droneId].
  Future<void> cancelReminder(String droneId) async {
    if (kIsWeb) return;

    if (!_initialized) {
      await init();
    }

    await _plugin.cancel(_notificationId(droneId));
  }
}