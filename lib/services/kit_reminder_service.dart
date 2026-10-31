// lib/services/kit_reminder_service.dart
//
// Device reminders for kits that still have PENDING parts.
//
// For every kit that is not complete and has a promised date, a local
// notification is scheduled for the promised date at kKitReminderHour
// (default 10:00 AM) and then REPEATS EVERY DAY at that time until the kit
// is completed (or deleted) — so a forgotten propeller / bag keeps nagging
// until it is actually handed over.
//
//   * schedule(kit)  – (re)schedules, or cancels if the kit is complete
//   * cancel(kitId)  – cancels
//   * syncAll(kits)  – called whenever the kit list changes, so kits made
//                      on another device also remind this device
//
// Android / iOS: scheduled local notification.
// Windows / Web: device notifications are skipped (same as the Drone
// reminders) — the dashboard bell + badge still shows the pending kits.

import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../constants/kit_templates.dart';
import '../models/kit_delivery.dart';

class KitReminderService {
  KitReminderService._();

  static final KitReminderService instance = KitReminderService._();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// kitId -> fingerprint of what is currently scheduled. Lets syncAll()
  /// skip kits that have not changed instead of re-scheduling on every
  /// Firestore snapshot.
  final Map<String, String> _scheduled = {};

  static final Int64List _vibration =
  Int64List.fromList([0, 400, 200, 400, 200, 600]);

  // Same Windows identity as the other reminder services.
  static const String _windowsAppName = 'CDA Inventory';
  static const String _windowsAppUserModelId = 'CDA.CDAInventory';
  static const String _windowsGuid = '6f2c8e1a-7b4d-4f9c-9d31-5a8e2c6b7410';

  /// Call once from main() before runApp(). Safe to call repeatedly.
  Future<void> init() async {
    if (_initialized || kIsWeb) return;

    try {
      tzdata.initializeTimeZones();

      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
          windows: WindowsInitializationSettings(
            appName: _windowsAppName,
            appUserModelId: _windowsAppUserModelId,
            guid: _windowsGuid,
          ),
        ),
      );

      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await android?.requestNotificationsPermission();
        await android?.requestExactAlarmsPermission();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        debugPrint('Windows kit reminder notifications initialized.');
      }

      _initialized = true;
    } catch (e) {
      // Notifications are best-effort — never stop the app from starting.
      debugPrint('KitReminderService.init failed: $e');
    }
  }

  /// Stable per-kit notification id (namespaced so it never collides with
  /// the drone / movement reminder ids).
  int _id(String kitId) => ('kit_$kitId').hashCode & 0x7FFFFFFF;

  /// The first moment the reminder should fire: the promised date at the
  /// reminder time, or — if that is already in the past (overdue kit) — the
  /// next occurrence of the reminder time (today if still ahead, otherwise
  /// tomorrow). Because the notification repeats daily at the same clock
  /// time, an overdue kit is nagged every day at 10:00.
  tz.TZDateTime _firstFire(KitDelivery kit) {
    final now = tz.TZDateTime.now(tz.local);
    final promised = kit.reminderAt!;
    var fire = tz.TZDateTime(
      tz.local,
      promised.year,
      promised.month,
      promised.day,
      kKitReminderHour,
      kKitReminderMinute,
    );
    if (fire.isAfter(now)) return fire;

    fire = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      kKitReminderHour,
      kKitReminderMinute,
    );
    if (!fire.isAfter(now)) fire = fire.add(const Duration(days: 1));
    return fire;
  }

  String _fingerprint(KitDelivery kit) =>
      '${kit.promisedDate?.millisecondsSinceEpoch}|${kit.pendingSummary}|'
          '${kit.customerName}';

  /// Schedules (or re-schedules) the daily reminder for [kit]. A complete
  /// kit, or one without a promised date, has its reminder cancelled.
  Future<void> schedule(KitDelivery kit) async {
    if (kIsWeb || kit.id.isEmpty) return;

    try {
      if (!_initialized) await init();
      if (!_initialized) return;

      await _plugin.cancel(_id(kit.id));
      _scheduled.remove(kit.id);

      if (kit.isComplete || kit.reminderAt == null) return;

      // Windows: skip device scheduling (matches the other reminder
      // services). The in-app bell still shows the pending kit.
      if (defaultTargetPlatform == TargetPlatform.windows) return;

      final who = kit.customerName.isEmpty ? 'A customer' : kit.customerName;

      await _plugin.zonedSchedule(
        _id(kit.id),
        'Kit parts pending — $who',
        'Still to deliver: ${kit.pendingSummary}. '
            'Tap to open Kit Deliveries.',
        _firstFire(kit),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'kit_pending_reminders_v1',
            'Kit pending parts',
            channelDescription:
            'Daily reminder while a customer kit still has parts '
                '(drone, propellers, bag...) left to deliver.',
            importance: Importance.high,
            priority: Priority.high,
            enableVibration: true,
            vibrationPattern: _vibration,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // Repeat every day at the same time until cancelled.
        matchDateTimeComponents: DateTimeComponents.time,
        payload: kit.id,
      );

      _scheduled[kit.id] = _fingerprint(kit);
    } catch (e) {
      debugPrint('KitReminderService.schedule failed: $e');
    }
  }

  Future<void> cancel(String kitId) async {
    if (kIsWeb || kitId.isEmpty) return;
    try {
      if (!_initialized) await init();
      if (!_initialized) return;
      await _plugin.cancel(_id(kitId));
      _scheduled.remove(kitId);
    } catch (_) {}
  }

  /// Brings the device's scheduled reminders in line with [kits]. Cheap to
  /// call on every Firestore snapshot: unchanged kits are skipped.
  Future<void> syncAll(List<KitDelivery> kits) async {
    if (kIsWeb) return;

    for (final kit in kits) {
      if (kit.id.isEmpty) continue;

      final needsReminder = kit.isPending && kit.reminderAt != null;

      if (!needsReminder) {
        // Complete (possibly finished on another device) -> make sure
        // nothing is left scheduled on this one.
        if (_scheduled.containsKey(kit.id) || !_everSeen.contains(kit.id)) {
          await cancel(kit.id);
        }
        _everSeen.add(kit.id);
        continue;
      }

      _everSeen.add(kit.id);
      if (_scheduled[kit.id] == _fingerprint(kit)) continue;
      await schedule(kit);
    }
  }

  // Kits we have already processed once in this app run (so a completed kit
  // is only cancelled once instead of on every snapshot).
  final Set<String> _everSeen = {};
}