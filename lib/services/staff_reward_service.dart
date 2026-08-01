// lib/services/staff_reward_service.dart
//
// Central entry point for the staff engagement / gamification system.
// Every module (products, stock, purchases, invoices, drones, ...) calls
// StaffRewardService.recordActivity(...) right after its own Firestore
// write completes — mirrors how ActivityLogService.logAdd/logEdit/
// logDelete is already called from those same services.
//
// Responsibilities:
//  - Award XP for the action (staff_activity_points log + staff_rewards
//    running totals), inside a Firestore transaction.
//  - Delegate streak math to StreakService (pure function, no I/O).
//  - Delegate achievement + daily-mission evaluation to AchievementService
//    / MissionService, then apply any bonus XP they report back.
//  - De-duplicate XP: pass a stable [refId] (e.g.
//    '${module}_${docId}_${action}') for actions that must only ever pay
//    out once (add/edit/delete of one specific record). A repeat call
//    with the same refId is a no-op.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants/gamification_constants.dart';
import '../models/staff_reward_model.dart';
import 'achievement_service.dart';
import 'gamification_service.dart';
import 'mission_service.dart';
import 'streak_service.dart';

class StaffRewardService {
  StaffRewardService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _rewards =>
      _db.collection('staff_rewards');

  static CollectionReference<Map<String, dynamic>> get _points =>
      _db.collection('staff_activity_points');

  // Dedupe ledger — one doc per refId. The doc's existence means the XP
  // for that specific event has already been paid out.
  static CollectionReference<Map<String, dynamic>> get _xpLedger =>
      _db.collection('staff_xp_ledger');

  static String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  /// Records one staff activity: awards XP + updates streak/action-count
  /// totals inside a transaction, then checks for newly-unlocked
  /// achievements and completed daily missions and applies any bonus XP
  /// they earned.
  ///
  /// [action]  which activity occurred — drives XP amount and streak/
  ///           mission/achievement eligibility (see gamification_constants.dart).
  /// [module]  human-readable module name for the activity log, e.g.
  ///           'Products', 'Stock', 'Purchases', 'Drones'.
  /// [refId]   OPTIONAL stable id for this specific event (e.g. the
  ///           product's doc id + action, `'products_$productId\_add'`).
  ///           When provided, calling this again with the same refId is a
  ///           no-op — prevents duplicate XP from retries, double-taps, or
  ///           widget rebuilds. Omit only for actions that are
  ///           legitimately repeatable per call (e.g. stock updates on the
  ///           same item, where every call is a genuinely new event).
  /// [userId]  defaults to the currently signed-in Firebase Auth user.
  static Future<void> recordActivity({
    required StaffAction action,
    required String module,
    String? refId,
    String? userId,
  }) async {
    final uid = userId ?? _currentUserId;
    if (uid == null) return; // nobody signed in — nothing to award

    final now = DateTime.now();
    final rewardRef = _rewards.doc(uid);
    final ledgerRef = refId == null ? null : _xpLedger.doc(refId);

    // The canonical currentStreak/longestStreak now live in
    // gamification_profiles/{uid}, computed once by GamificationService
    // (Firestore doesn't support nested transactions, so this has to run
    // before/outside the staff_rewards transaction below). Previously
    // this method computed its own, second, independent streak here —
    // the two could silently drift apart since one only advanced when the
    // Gamification Dashboard was opened and this one advanced on real
    // actions. Now there's one calculation and staff_rewards just mirrors
    // it, so every screen shows the same number.
    final canonicalStreak =
    await GamificationService.recordDailyActivity(uidOverride: uid);

    StaffRewardModel? updatedReward;

    await _db.runTransaction((txn) async {
      // Dedupe check first — all reads in a transaction must happen
      // before any writes.
      if (ledgerRef != null) {
        final ledgerSnap = await txn.get(ledgerRef);
        if (ledgerSnap.exists) return; // already awarded for this event
      }

      final rewardSnap = await txn.get(rewardRef);
      final current = rewardSnap.exists
          ? StaffRewardModel.fromDoc(rewardSnap)
          : StaffRewardModel.empty(uid);

      // totalActiveDays is local bookkeeping (feeds
      // AchievementMetric.totalActiveDays) — still counted per unique
      // calendar day using the same StreakService rules, but the
      // currentStreak/longestStreak below come from the canonical
      // calculation above instead of being computed a second time.
      final localDayInfo = StreakService.calculate(
        lastActiveDate: current.lastActiveDate,
        currentStreak: current.currentStreak,
        longestStreak: current.longestStreak,
        totalActiveDays: current.totalActiveDays,
        now: now,
      );

      final earnedXp = xpForAction(action);
      final newXp = current.xp + earnedXp;

      final counts = Map<String, int>.from(current.actionCounts);
      counts[action.key] = (counts[action.key] ?? 0) + 1;

      updatedReward = current.copyWith(
        xp: newXp,
        level: levelForXp(newXp),
        currentStreak: canonicalStreak.currentStreak,
        longestStreak: canonicalStreak.longestStreak,
        totalActiveDays: localDayInfo.totalActiveDays,
        lastActiveDate: localDayInfo.lastActiveDate,
        actionCounts: counts,
        createdAt: current.createdAt ?? now,
      );

      txn.set(rewardRef, updatedReward!.toMap(), SetOptions(merge: true));

      if (earnedXp > 0) {
        txn.set(
          _points.doc(),
          StaffActivityPointModel(
            id: '',
            userId: uid,
            action: action.key,
            module: module,
            points: earnedXp,
          ).toMap(),
        );
      }

      if (ledgerRef != null) {
        txn.set(ledgerRef, {
          'userId': uid,
          'action': action.key,
          'module': module,
          'points': earnedXp,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    });

    if (updatedReward == null) return; // transaction bailed out (dedupe hit)

    // Achievements + missions run after the main transaction commits. They
    // do their own small writes and report back bonus XP, which is applied
    // in a second update here rather than pulling them into the
    // transaction above — keeps the dependency direction one-way (this
    // service depends on them, never the reverse), avoiding the circular
    // dependency that a tighter coupling would create.
    final achievementBonus = await AchievementService.evaluateAndUnlock(
      userId: uid,
      reward: updatedReward!,
    );
    final missionBonus = await MissionService.updateProgress(
      userId: uid,
      action: action,
      now: now,
    );

    final totalBonus = achievementBonus + missionBonus;
    if (totalBonus > 0) {
      await rewardRef.update({
        'xp': FieldValue.increment(totalBonus),
        'level': levelForXp(updatedReward!.xp + totalBonus),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// One-shot fetch of a user's current reward stats (XP, level, streak).
  static Future<StaffRewardModel> getRewards(String userId) async {
    final doc = await _rewards.doc(userId).get();
    return doc.exists
        ? StaffRewardModel.fromDoc(doc)
        : StaffRewardModel.empty(userId);
  }

  /// Live stream of a user's reward stats — for a future profile/dashboard
  /// widget showing XP, level, and streak in real time.
  static Stream<StaffRewardModel> watchRewards(String userId) {
    return _rewards.doc(userId).snapshots().map(
          (doc) => doc.exists
          ? StaffRewardModel.fromDoc(doc)
          : StaffRewardModel.empty(userId),
    );
  }

  /// Recent XP-earning events for a user (activity points feed). Sorted
  /// client-side to avoid requiring a composite Firestore index, same
  /// approach already used by ActivityLogService.streamForUser.
  static Stream<List<StaffActivityPointModel>> watchRecentPoints(
      String userId, {
        int limit = 30,
      }) {
    return _points.where('userId', isEqualTo: userId).snapshots().map((s) {
      final docs = s.docs.map(StaffActivityPointModel.fromDoc).toList()
        ..sort((a, b) {
          final at = a.timestamp;
          final bt = b.timestamp;
          if (at == null && bt == null) return 0;
          if (at == null) return 1;
          if (bt == null) return -1;
          return bt.compareTo(at);
        });
      return docs.length > limit ? docs.sublist(0, limit) : docs;
    });
  }
}