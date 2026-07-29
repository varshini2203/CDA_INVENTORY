// lib/services/drone_reminder_service.dart
//
// Fires a local device reminder 1 hour after a drone's IN/OUT status is
// changed, in case whoever took it OUT (or brought it back IN) forgets to
// register the matching return entry. If the status is changed again for
// that drone before the hour is up, the pending reminder is cancelled.
//
// Requires two packages in pubspec.yaml (already added):
//
//   dependencies:
//     flutter_local_notifications: ^19.4.0
//     timezone: ^0.10.1
//
// Android also needs (AndroidManifest.xml, inside <manifest>):
//   <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
//   <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
// and inside <application>, alongside the existing <activity>:
//   <receiver android:exported="false"
//       android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
//   <receiver android:exported="false"
//       android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
//     <intent-filter>
//       <action android:name="android.intent.action.BOOT_COMPLETED"/>
//     </intent-filter>
//   </receiver>
//
// iOS needs nothing extra beyond the usual notification permission prompt,
// which requestPermissions() below triggers on first launch.

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
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

  // Distinct "long-short-long-short-long" buzz so a drone reminder feels
  // different in the hand from every other notification in the app —
  // no mistaking it for a generic alert. Format: [pause, buzz, pause,
  // buzz, ...] in milliseconds.
  static final Int64List _droneVibrationPattern = Int64List.fromList(
    [0, 500, 200, 200, 200, 500, 200, 200, 200, 700],
  );

  /// Call once from main() before runApp(). Safe to call multiple times.
  Future<void> init() async {
    if (_initialized || kIsWeb) return;

    tzdata.initializeTimeZones();

    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _plugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    _initialized = true;
  }

  /// Stable per-drone notification id so a re-schedule for the same drone
  /// overwrites/cancels the previous one instead of stacking reminders.
  int _notificationId(String droneId) => droneId.hashCode & 0x7FFFFFFF;

  /// Schedules a "did you forget to register the return?" reminder
  /// [reminderDelay] after [actionTime] for [droneId]. Call this every time
  /// a drone's status is toggled — it replaces any earlier pending
  /// reminder for the same drone.
  Future<void> scheduleReminder({
    required String droneId,
    required String droneName,
    required String newStatus, // 'IN' or 'OUT'
    required DateTime actionTime,
    String? purpose,
  }) async {
    if (kIsWeb) return;
    if (!_initialized) await init();

    final id = _notificationId(droneId);
    await _plugin.cancel(id);

    // Coming back IN closes the loop — nothing to remind about. Only an
    // OUT needs a "did you forget to bring it back?" follow-up.
    if (newStatus.toUpperCase() != 'OUT') return;

    final fireAt = tz.TZDateTime.from(
      actionTime.add(reminderDelay),
      tz.local,
    );
    // If the computed fire time has already passed (e.g. a backdated
    // entry), don't schedule a reminder that would fire immediately.
    if (fireAt.isBefore(tz.TZDateTime.now(tz.local))) return;

    final purposeText = (purpose != null && purpose.isNotEmpty) ? ' for $purpose' : '';

    await _plugin.zonedSchedule(
      id,
      'Drone overdue for return',
      '"$droneName" was taken OUT$purposeText 4 hours ago and hasn\'t been marked IN yet. Please update it in the fleet screen.',
      fireAt,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'drone_status_reminders_v2',
          'Drone status reminders',
          channelDescription:
          'Reminds you when a drone has been OUT for 4+ hours without being marked back IN.',
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

  /// Cancels any pending reminder for [droneId] — call this whenever the
  /// drone's status changes again before the hour is up, or the drone is
  /// deleted.
  Future<void> cancelReminder(String droneId) async {
    if (kIsWeb) return;
    await _plugin.cancel(_notificationId(droneId));
  }
}