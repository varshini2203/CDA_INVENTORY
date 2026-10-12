// lib/services/drone_service_alert_service.dart
//
// "Service ran past its scheduled date" alerts for the Drone Services module.
//
// Two layers:
//   1. In-app alert (dialog + banner) — handled by the dashboard screen using
//      the helpers below. Works everywhere, including Chrome / web.
//   2. Device notification — on Android / iOS a local notification is
//      scheduled for the booking's scheduled date & time. It is cancelled
//      automatically when the service is completed, cancelled, deleted or
//      rescheduled. Windows is initialized safely, but scheduled device
//      notifications are skipped there.

import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/drone_service_record.dart';

class DroneServiceAlertService {
  DroneServiceAlertService._();

  static final DroneServiceAlertService instance =
  DroneServiceAlertService._();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static final Int64List _vibration =
  Int64List.fromList([0, 400, 200, 400, 200, 600]);

  // Windows notification settings.
  static const String _windowsAppName = 'CDA Inventory';
  static const String _windowsAppUserModelId = 'CDA.CDAInventory';

  static const String _windowsGuid =
      '6f2c8e1a-7b4d-4f9c-9d31-5a8e2c6b7410';

  // ── Helpers used by the dashboard ───────────────────────────────────────

  /// Services that are still open (Scheduled / In Progress) but whose
  /// scheduled date & time has already passed — most overdue first.
  static List<DroneServiceRecord> overdueOf(
      List<DroneServiceRecord> all,
      ) {
    final list = all.where((s) => s.isPastSchedule).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    return list;
  }

  /// "2d 3h", "5h 20m", "12m" …
  static String formatOverdue(Duration d) {
    if (d.inMinutes < 1) return 'just now';

    if (d.inDays >= 1) {
      final h = d.inHours % 24;
      return h == 0 ? '${d.inDays}d' : '${d.inDays}d ${h}h';
    }

    if (d.inHours >= 1) {
      final m = d.inMinutes % 60;
      return m == 0 ? '${d.inHours}h' : '${d.inHours}h ${m}m';
    }

    return '${d.inMinutes}m';
  }

  // ── Device notification scheduling ──────────────────────────────────────

  Future<void> init() async {
    if (_initialized || kIsWeb) return;

    tzdata.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosSettings = DarwinInitializationSettings();

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

    // Android permissions.
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
    }

    // iOS permissions.
    else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

      await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // Windows does not require Android/iOS permission requests.
    else if (defaultTargetPlatform == TargetPlatform.windows) {
      debugPrint(
        'Windows drone service alert notifications initialized.',
      );
    }

    _initialized = true;
  }

  int _id(String serviceId) {
    return ('svc_$serviceId').hashCode & 0x7FFFFFFF;
  }

  /// Schedules (or re-schedules) the alert for [r].
  ///
  /// Does nothing for finished / cancelled bookings and cancels any alert
  /// that was already pending for them.
  Future<void> schedule(DroneServiceRecord r) async {
    if (kIsWeb || r.id.isEmpty) return;

    try {
      if (!_initialized) {
        await init();
      }

      await _plugin.cancel(_id(r.id));

      if (r.status != 'Scheduled' && r.status != 'In Progress') {
        return;
      }

      final fireAt = tz.TZDateTime.from(
        r.scheduledAt,
        tz.local,
      );

      if (fireAt.isBefore(tz.TZDateTime.now(tz.local))) {
        return;
      }

      // ------------------------------------------------------------
      // WINDOWS
      // ------------------------------------------------------------
      //
      // The in-app overdue alert continues to work through the
      // dashboard. We don't use Android's exact alarm scheduling
      // mode on Windows.
      //
      if (defaultTargetPlatform == TargetPlatform.windows) {
        debugPrint(
          'Windows drone service reminder requested for '
              '"${r.serviceType} — ${r.droneName}".',
        );

        return;
      }

      // ------------------------------------------------------------
      // ANDROID / iOS
      // ------------------------------------------------------------

      await _plugin.zonedSchedule(
        _id(r.id),
        'Drone service overdue',
        '"${r.serviceType} — ${r.droneName}" has passed its '
            'scheduled date and is not completed yet.',
        fireAt,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'drone_service_overdue',
            'Drone service overdue',
            channelDescription:
            'Alerts when a drone service goes past its scheduled date.',
            importance: Importance.high,
            priority: Priority.high,
            enableVibration: true,
            vibrationPattern: _vibration,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: r.id,
      );
    } catch (_) {
      // Notifications are best-effort.
      // Never block saving a booking.
    }
  }

  Future<void> cancel(String serviceId) async {
    if (kIsWeb || serviceId.isEmpty) return;

    try {
      if (!_initialized) {
        await init();
      }

      await _plugin.cancel(_id(serviceId));
    } catch (_) {}
  }
}