// lib/services/achievement_service.dart
//
// Evaluates achievement unlocks against a staff member's current counters
// and writes any newly-unlocked achievements to `staff_achievements`.
//
// Deliberately does NOT import StaffRewardService — StaffRewardService
// calls into this one-way, so the two services never form a circular
// dependency. Bonus XP for a new unlock is returned to the caller, which
// is responsible for actually applying it to staff_rewards.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/gamification_constants.dart';
import '../models/staff_reward_model.dart';

class AchievementService {
  AchievementService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _achievements =>
      _db.collection('staff_achievements');

  static String _docId(String userId, String achievementId) =>
      '${userId}_$achievementId';

  static Future<Set<String>> _unlockedIds(String userId) async {
    final snapshot =
    await _achievements.where('userId', isEqualTo: userId).get();
    return snapshot.docs
        .map((d) => (d.data()['achievementId'] as String?) ?? '')
        .toSet();
  }

  /// Compares [reward]'s counters against [achievementCatalog], unlocks any
  /// achievement newly met (writes one `staff_achievements` doc per
  /// unlock), and returns the total bonus XP earned from this evaluation.
  /// Safe to call after every reward update — already-unlocked
  /// achievements are skipped, so repeated calls are cheap no-ops once a
  /// staff member has unlocked everything they qualify for.
  static Future<int> evaluateAndUnlock({
    required String userId,
    required StaffRewardModel reward,
  }) async {
    final alreadyUnlocked = await _unlockedIds(userId);
    var bonusXp = 0;
    final batch = _db.batch();
    var wroteAny = false;

    for (final def in achievementCatalog) {
      if (alreadyUnlocked.contains(def.id)) continue;
      final current = reward.countFor(def.metric);
      if (current >= def.threshold) {
        final docRef = _achievements.doc(_docId(userId, def.id));
        batch.set(
          docRef,
          AchievementUnlockModel(
            userId: userId,
            achievementId: def.id,
            title: def.title,
            description: def.description,
          ).toMap(),
        );
        bonusXp += def.bonusXp;
        wroteAny = true;
      }
    }

    if (wroteAny) await batch.commit();
    return bonusXp;
  }

  /// Live list of unlocked achievements for a user — for a future
  /// badges/profile screen.
  static Stream<List<AchievementUnlockModel>> watchUnlocked(String userId) {
    return _achievements
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((s) => s.docs.map(AchievementUnlockModel.fromDoc).toList());
  }
}