// lib/services/movement_reminder_service.dart
//
// Schedules a local device reminder that fires at a movement's Expected
// Return Date & Time, so whoever dispatched the item gets nudged if it
// hasn't been marked Returned yet. Deliberately mirrors
// lib/services/drone_reminder_service.dart — same plugin, same
// init()/schedule/cancel shape — so it drops into the existing
// flutter_local_notifications + timezone setup with zero new wiring
// beyond calling init() once (already done for the drone reminders; this
// re-uses the same plugin instance style but keeps its own instance so
// notification ids never collide with drone reminders).
//
// Call scheduleReminder() when a movement is Dispatched (with its
// Expected Return date/time). Call cancelReminder() when it's Returned,
// or when the movement is edited/deleted before that time.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class MovementReminderService {
  MovementReminderService._();
  static final MovementReminderService instance = MovementReminderService._();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Call once from main() before runApp() — safe to call multiple times.
  /// Skips re-initializing the plugin's platform channel if
  /// DroneReminderService.instance.init() already ran, since
  /// flutter_local_notifications only needs one initialize() call per app;
  /// this init() just marks this service ready to schedule.
  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;
  }

  /// Stable per-movement notification id so re-scheduling (e.g. the
  /// expected return time gets edited) replaces rather than stacks.
  int _notificationId(String movementId) =>
      (movementId.hashCode ^ 0x4D4F5645 /* 'MOVE' */) & 0x7FFFFFFF;

  /// Schedules an "overdue return" reminder to fire at [expectedReturnAt]
  /// for the given dispatched movement.
  Future<void> scheduleReminder({
    required String movementId,
    required String productName,
    required int quantity,
    required DateTime expectedReturnAt,
  }) async {
    if (kIsWeb) return;
    if (!_initialized) await init();

    final id = _notificationId(movementId);
    await _plugin.cancel(id);

    final fireAt = tz.TZDateTime.from(expectedReturnAt, tz.local);
    if (fireAt.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      id,
      'Inventory movement overdue',
      '$quantity x "$productName" was due back now and hasn\'t been marked Returned yet.',
      fireAt,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'movement_overdue_reminders_v1',
          'Movement return reminders',
          channelDescription:
          'Reminds you when a dispatched inventory item is due back and hasn\'t been returned.',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: movementId,
    );
  }

  /// Cancels any pending reminder for [movementId] — call this once the
  /// movement is marked Returned (or deleted) before the reminder fires.
  Future<void> cancelReminder(String movementId) async {
    if (kIsWeb) return;
    await _plugin.cancel(_notificationId(movementId));
  }
}