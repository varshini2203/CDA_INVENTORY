// lib/services/gamification_service.dart
//
// Backend for the Staff Gamification System. This is a brand-new,
// self-contained service — it does not read from, write to, or modify
// any existing collection (users, inventory, invoices, etc.) and does
// not touch any existing service file. It only owns these new
// Firestore collections:
//
//   gamification_profiles/{uid}
//   gamification_profiles/{uid}/activity/{autoId}
//   gamification_missions/{uid}_{yyyy-MM-dd}
//
// Other parts of the app (e.g. add-product / stock-update flows) are
// NOT modified to call into this service — per the "do not modify
// existing services" instruction. Instead, GamificationService exposes
// static hook methods (recordProductAdded, recordStockUpdate, etc.)
// that can be wired in later, from wherever the product/stock actions
// live, with a single one-line call. Until then, the dashboard still
// works end-to-end against real Firestore data seeded by
// ensureTodayMissions()/ensureProfile().

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../models/gamification_models.dart';

class GamificationService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> get _profiles =>
      _db.collection('gamification_profiles');

  static CollectionReference<Map<String, dynamic>> get _missionDocs =>
      _db.collection('gamification_missions');

  static String _todayKey() => DateFormat('yyyy-MM-dd').format(DateTime.now());
  static String _monthKey([DateTime? d]) => DateFormat('yyyy-MM').format(d ?? DateTime.now());

  static CollectionReference<Map<String, dynamic>> _monthlyBadges(String uid) =>
      _profiles.doc(uid).collection('monthly_badges');

  // ── Static achievement catalog ─────────────────────────────────
  static const List<AchievementDef> achievementCatalog = [
    AchievementDef(
      id: 'inventory_starter',
      title: 'Inventory Starter',
      description: 'Add your first product to inventory',
      iconKey: 'seedling',
      tier: 1,
    ),
    AchievementDef(
      id: 'stock_master',
      title: 'Stock Master',
      description: 'Perform 50 stock updates',
      iconKey: 'inventory',
      tier: 2,
    ),
    AchievementDef(
      id: 'drone_expert',
      title: 'Drone Expert',
      description: 'Log 25 drone in/out entries',
      iconKey: 'flight',
      tier: 2,
    ),
    AchievementDef(
      id: 'accuracy_champion',
      title: 'Accuracy Champion',
      description: 'Complete 10 missions with zero corrections',
      iconKey: 'target',
      tier: 3,
    ),
    AchievementDef(
      id: 'consistency_king',
      title: 'Consistency King',
      description: 'Reach a 7-day streak',
      iconKey: 'flame',
      tier: 2,
    ),
    AchievementDef(
      id: 'inventory_hero',
      title: 'Inventory Hero',
      description: 'Reach Level 10',
      iconKey: 'shield',
      tier: 3,
    ),
    AchievementDef(
      id: 'cda_legend',
      title: 'CDA Legend',
      description: 'Reach a 30-day streak',
      iconKey: 'crown',
      tier: 4,
    ),
  ];

  // ── Default mission templates (rotated daily) ──────────────────
  static const List<Map<String, dynamic>> _missionTemplates = [
    {'id': 'add_products', 'title': 'Add 2 Products', 'icon': 'add_box', 'targetCount': 2, 'xpReward': 50},
    {'id': 'upload_invoice', 'title': 'Upload Invoice', 'icon': 'receipt', 'targetCount': 1, 'xpReward': 40},
    {'id': 'update_stock', 'title': 'Update Stock', 'icon': 'inventory', 'targetCount': 1, 'xpReward': 30},
  ];

  // ── PROFILE ──────────────────────────────────────────────────
  static Stream<GamificationProfile> watchProfile({String? uidOverride}) {
    final uid = uidOverride ?? _uid;
    if (uid == null) {
      return Stream.value(GamificationProfile.empty(''));
    }
    return _profiles.doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return GamificationProfile.empty(uid);
      }
      return GamificationProfile.fromMap(uid, doc.data()!);
    });
  }

  /// Creates the profile doc the first time a staff member opens the
  /// gamification module, and applies the daily-streak check. Safe to
  /// call every time the dashboard loads.
  static Future<void> ensureProfile({required String name, required String branch}) async {
    final uid = _uid;
    if (uid == null) return;

    await _db.runTransaction((txn) async {
      final ref = _profiles.doc(uid);
      final snap = await txn.get(ref);
      final today = _todayKey();

      if (!snap.exists) {
        txn.set(ref, GamificationProfile(
          uid: uid,
          name: name,
          branch: branch,
          totalXP: 0,
          currentStreak: 1,
          longestStreak: 1,
          lastActivityDate: today,
          achievementIds: const [],
          missionsCompletedTotal: 0,
          productsAdded: 0,
          stockUpdates: 0,
        ).toMap());
        return;
      }

      final data = snap.data()!;
      final profile = GamificationProfile.fromMap(uid, data);
      final updated = _applyStreakLogic(profile, today).copyWithName(name, branch);
      txn.update(ref, updated.toMap());
    });
  }

  static GamificationProfile _applyStreakLogic(GamificationProfile profile, String today) {
    if (profile.lastActivityDate == today) {
      // Already visited today — leave streak untouched.
      return profile;
    }

    final yesterday = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(const Duration(days: 1)));

    int newStreak;
    if (profile.lastActivityDate == yesterday) {
      newStreak = profile.currentStreak + 1; // consecutive day
    } else if (profile.lastActivityDate.isEmpty) {
      newStreak = 1;
    } else {
      newStreak = 1; // streak broken, restart
    }

    final newLongest = max(profile.longestStreak, newStreak);

    return GamificationProfile(
      uid: profile.uid,
      name: profile.name,
      branch: profile.branch,
      totalXP: profile.totalXP,
      currentStreak: newStreak,
      longestStreak: newLongest,
      lastActivityDate: today,
      achievementIds: profile.achievementIds,
      missionsCompletedTotal: profile.missionsCompletedTotal,
      productsAdded: profile.productsAdded,
      stockUpdates: profile.stockUpdates,
    );
  }

  // ── XP + ACHIEVEMENTS ───────────────────────────────────────────
  static Future<void> _awardXP(String uid, int xp, {String? title, String? description, String? iconKey}) async {
    final ref = _profiles.doc(uid);
    await ref.set({
      'totalXP': FieldValue.increment(xp),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (title != null) {
      await ref.collection('activity').add({
        'title': title,
        'description': description ?? '',
        'xp': xp,
        'icon': iconKey ?? 'star',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await _checkAndUnlockAchievements(uid);
    await _applyMonthlyBadgeXp(uid, xp);
  }

  // ── MONTHLY BADGES ──────────────────────────────────────────────
  /// Adds [xpDelta] to the current calendar month's XP bucket for
  /// [uid] and unlocks that month's badge the first time the running
  /// total crosses [MonthlyBadge.xpThreshold] (250). Safe to call
  /// repeatedly — once earned, a badge never gets un-earned.
  static Future<void> _applyMonthlyBadgeXp(String uid, int xpDelta) async {
    if (xpDelta == 0) return;
    final key = _monthKey();
    final ref = _monthlyBadges(uid).doc(key);

    await _db.runTransaction((txn) async {
      final snap = await txn.get(ref);
      final current = snap.exists && snap.data() != null
          ? MonthlyBadge.fromMap(key, snap.data()!)
          : MonthlyBadge.empty(key);

      final newXp = current.xp + xpDelta;
      final justEarned = !current.earned && newXp >= MonthlyBadge.xpThreshold;
      final nowEarned = current.earned || justEarned;

      txn.set(
        ref,
        {
          'month': key,
          'xp': newXp,
          'earned': nowEarned,
          if (justEarned) 'earnedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  /// Live stream of every month's badge for [year] (defaults to the
  /// current year), Jan (index 0) through Dec (index 11), so the
  /// Monthly Badges screen can render a full 12-tile grid — earned
  /// months colored, not-yet-earned months shown locked/greyscale.
  static Stream<List<MonthlyBadge>> watchMonthlyBadges({String? uidOverride, int? year}) {
    final uid = uidOverride ?? _uid;
    final y = year ?? DateTime.now().year;
    if (uid == null) {
      return Stream.value(List.generate(12, (i) =>
          MonthlyBadge.empty('$y-${(i + 1).toString().padLeft(2, '0')}')));
    }
    return _monthlyBadges(uid).snapshots().map((snap) {
      final byKey = {for (final d in snap.docs) d.id: d.data()};
      return List.generate(12, (i) {
        final key = '$y-${(i + 1).toString().padLeft(2, '0')}';
        final data = byKey[key];
        return data != null ? MonthlyBadge.fromMap(key, data) : MonthlyBadge.empty(key);
      });
    });
  }

  /// One-shot fetch of the current month's badge (used for quick
  /// "X XP to your badge" style summaries without holding a stream).
  static Future<MonthlyBadge> getCurrentMonthBadge({String? uidOverride}) async {
    final uid = uidOverride ?? _uid;
    final key = _monthKey();
    if (uid == null) return MonthlyBadge.empty(key);
    final snap = await _monthlyBadges(uid).doc(key).get();
    if (!snap.exists || snap.data() == null) return MonthlyBadge.empty(key);
    return MonthlyBadge.fromMap(key, snap.data()!);
  }

  static Future<void> _checkAndUnlockAchievements(String uid) async {
    final snap = await _profiles.doc(uid).get();
    if (!snap.exists) return;
    final profile = GamificationProfile.fromMap(uid, snap.data()!);
    final unlocked = <String>{...profile.achievementIds};

    if (profile.productsAdded >= 1) unlocked.add('inventory_starter');
    if (profile.stockUpdates >= 50) unlocked.add('stock_master');
    if (profile.currentStreak >= 7) unlocked.add('consistency_king');
    if (profile.level >= 10) unlocked.add('inventory_hero');
    if (profile.currentStreak >= 30) unlocked.add('cda_legend');
    if (profile.missionsCompletedTotal >= 10) unlocked.add('accuracy_champion');

    if (unlocked.length != profile.achievementIds.length) {
      await _profiles.doc(uid).update({'achievementIds': unlocked.toList()});
    }
  }

  // ── DAILY MISSIONS ──────────────────────────────────────────────
  static String _missionDocId(String uid, String date) => '${uid}_$date';

  static Stream<DailyMissionSet> watchTodayMissions({String? uidOverride}) {
    final uid = uidOverride ?? _uid;
    if (uid == null) {
      return Stream.value(DailyMissionSet(uid: '', date: _todayKey(), missions: const []));
    }
    final today = _todayKey();
    return _missionDocs.doc(_missionDocId(uid, today)).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return DailyMissionSet(
          uid: uid,
          date: today,
          missions: _missionTemplates.map((t) => Mission.fromMap({...t, 'currentCount': 0})).toList(),
        );
      }
      return DailyMissionSet.fromMap(uid, today, doc.data()!);
    });
  }

  /// Seeds today's mission doc if it doesn't exist yet. Safe to call
  /// every time the missions screen or dashboard loads.
  static Future<void> ensureTodayMissions() async {
    final uid = _uid;
    if (uid == null) return;
    final today = _todayKey();
    final ref = _missionDocs.doc(_missionDocId(uid, today));
    final snap = await ref.get();
    if (!snap.exists) {
      final set = DailyMissionSet(
        uid: uid,
        date: today,
        missions: _missionTemplates.map((t) => Mission.fromMap({...t, 'currentCount': 0})).toList(),
      );
      await ref.set(set.toMap());
    }
  }

  /// Increments progress on a mission by [id] (e.g. 'add_products') by
  /// [amount]. Awards XP automatically the moment the mission flips to
  /// completed. Intended to be called from product/invoice/stock flows
  /// once wired in — has no effect on any existing screen until then.
  static Future<void> incrementMissionProgress(String missionId, {int amount = 1}) async {
    final uid = _uid;
    if (uid == null) return;
    final today = _todayKey();
    final ref = _missionDocs.doc(_missionDocId(uid, today));

    await _db.runTransaction((txn) async {
      final snap = await txn.get(ref);
      DailyMissionSet set;
      if (!snap.exists || snap.data() == null) {
        set = DailyMissionSet(
          uid: uid,
          date: today,
          missions: _missionTemplates.map((t) => Mission.fromMap({...t, 'currentCount': 0})).toList(),
        );
      } else {
        set = DailyMissionSet.fromMap(uid, today, snap.data()!);
      }

      bool justCompleted = false;
      int xpReward = 0;
      String missionTitle = '';
      final updatedMissions = set.missions.map((m) {
        if (m.id == missionId && !m.isCompleted) {
          final newCount = (m.currentCount + amount).clamp(0, m.targetCount);
          final updated = m.copyWith(currentCount: newCount);
          if (updated.isCompleted) {
            justCompleted = true;
            xpReward = updated.xpReward;
            missionTitle = updated.title;
          }
          return updated;
        }
        return m;
      }).toList();

      txn.set(ref, DailyMissionSet(uid: uid, date: today, missions: updatedMissions).toMap());

      if (justCompleted) {
        txn.set(_profiles.doc(uid), {
          'missionsCompletedTotal': FieldValue.increment(1),
        }, SetOptions(merge: true));
      }

      if (justCompleted) {
        // fire-and-forget outside the transaction, after commit
        Future.microtask(() => _awardXP(
          uid,
          xpReward,
          title: 'Mission Complete',
          description: missionTitle,
          iconKey: 'check_circle',
        ));
      }
    });
  }

  // ── ACTION HOOKS (call these from product/stock/invoice flows) ──
  static Future<void> recordProductAdded() async {
    final uid = _uid;
    if (uid == null) return;
    await _profiles.doc(uid).set({
      'productsAdded': FieldValue.increment(1),
    }, SetOptions(merge: true));
    await incrementMissionProgress('add_products');
  }

  static Future<void> recordStockUpdate() async {
    final uid = _uid;
    if (uid == null) return;
    await _profiles.doc(uid).set({
      'stockUpdates': FieldValue.increment(1),
    }, SetOptions(merge: true));
    await incrementMissionProgress('update_stock');
  }

  static Future<void> recordInvoiceUploaded() async {
    await incrementMissionProgress('upload_invoice');
  }

  // ── RECENT ACTIVITY / REWARD LOG ────────────────────────────────
  static Stream<List<RewardLogEntry>> watchRecentActivity({int limit = 10, String? uidOverride}) {
    final uid = uidOverride ?? _uid;
    if (uid == null) return Stream.value(const []);
    return _profiles
        .doc(uid)
        .collection('activity')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => RewardLogEntry.fromDoc(d.id, d.data())).toList());
  }

  // ── LEADERBOARD ──────────────────────────────────────────────────
  static Stream<List<LeaderboardEntry>> watchLeaderboard({int limit = 50}) {
    return _profiles
        .orderBy('totalXP', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => LeaderboardEntry.fromMap(d.id, d.data()))
        .toList());
  }
}

extension on GamificationProfile {
  GamificationProfile copyWithName(String name, String branch) {
    return GamificationProfile(
      uid: uid,
      name: name.isNotEmpty ? name : this.name,
      branch: branch.isNotEmpty ? branch : this.branch,
      totalXP: totalXP,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      lastActivityDate: lastActivityDate,
      achievementIds: achievementIds,
      missionsCompletedTotal: missionsCompletedTotal,
      productsAdded: productsAdded,
      stockUpdates: stockUpdates,
    );
  }
}