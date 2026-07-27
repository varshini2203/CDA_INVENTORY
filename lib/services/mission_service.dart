// lib/services/mission_service.dart
//
// Daily missions. Progress is stored per user per calendar day in
// `staff_daily_missions/{userId}_{yyyyMMdd}`.
//
// Deliberately does NOT import StaffRewardService — same one-way pattern
// as AchievementService, so bonus XP from a newly-completed mission is
// returned to the caller (StaffRewardService) instead of written here,
// avoiding a circular dependency between the two services.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/gamification_constants.dart';
import '../models/staff_reward_model.dart';

class MissionService {
  MissionService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _missions =>
      _db.collection('staff_daily_missions');

  static String _todayKey(DateTime now) =>
      '${now.year.toString().padLeft(4, '0')}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}';

  static String _docId(String userId, String dateKey) => '${userId}_$dateKey';

  /// Updates today's mission progress for [userId] based on [action], and
  /// returns the bonus XP earned from any mission that became complete on
  /// this exact call (0 if none did). Creates today's mission doc on the
  /// first call of the day. Wrapped in a transaction so concurrent
  /// activities the same second can't clobber each other's progress.
  static Future<int> updateProgress({
    required String userId,
    required StaffAction action,
    DateTime? now,
  }) async {
    final ts = now ?? DateTime.now();
    final dateKey = _todayKey(ts);
    final docRef = _missions.doc(_docId(userId, dateKey));

    return _db.runTransaction<int>((txn) async {
      final snap = await txn.get(docRef);
      final existing = snap.exists
          ? DailyMissionProgressModel.fromDoc(snap)
          : DailyMissionProgressModel(userId: userId, date: dateKey);

      final updated = Map<String, MissionProgress>.from(existing.missions);
      var bonusXp = 0;

      for (final def in dailyMissionCatalog) {
        final current =
            updated[def.id] ?? MissionProgress(progress: 0, target: def.target);
        if (current.completed || !def.matchesAction(action)) {
          updated[def.id] = current;
          continue;
        }
        final newProgress = current.progress + 1;
        final justCompleted = newProgress >= def.target;
        updated[def.id] = current.copyWith(
          progress: newProgress,
          completed: justCompleted,
        );
        if (justCompleted) bonusXp += def.xpReward;
      }

      final toSave = DailyMissionProgressModel(
        userId: userId,
        date: dateKey,
        missions: updated,
      );
      txn.set(docRef, toSave.toMap());
      return bonusXp;
    });
  }

  /// Live view of today's missions for a user — for a future missions
  /// checklist widget.
  static Stream<DailyMissionProgressModel> watchToday(String userId) {
    final dateKey = _todayKey(DateTime.now());
    return _missions.doc(_docId(userId, dateKey)).snapshots().map((doc) {
      return doc.exists
          ? DailyMissionProgressModel.fromDoc(doc)
          : DailyMissionProgressModel(userId: userId, date: dateKey);
    });
  }
}