// lib/models/gamification_models.dart
//
// Data models for the Staff Gamification System.
// Firestore layout used by these models (all new collections — nothing
// here touches or renames any existing collection):
//
//   gamification_profiles/{uid}
//       name, branch, totalXP, level, currentStreak, longestStreak,
//       lastActivityDate ("yyyy-MM-dd"), achievementIds: [...],
//       missionsCompletedTotal, productsAdded, stockUpdates, updatedAt
//
//   gamification_profiles/{uid}/activity/{autoId}
//       title, description, xp, icon (string key), createdAt
//
//   gamification_missions/{uid}_{yyyy-MM-dd}
//       uid, date, missions: [ { id, title, icon, targetCount,
//       currentCount, xpReward, completed } ]
//
// Everything below is a plain data class with fromMap/toMap — no
// Firestore imports here, so these models stay easy to unit test.

import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────
// LEVEL / XP CURVE
// ─────────────────────────────────────────────────────────────────
// Level N requires N * 250 XP more than level N-1 needed in total.
// Level 1 -> 0 XP, Level 2 -> 250 XP, Level 3 -> 750 XP, Level 4 ->
// 1500 XP, Level 5 -> 2500 XP, etc. (triangular growth, so the grind
// gets a little longer each level — feels fair for daily habits).
class XPCurve {
  static int xpRequiredForLevel(int level) {
    if (level <= 1) return 0;
    int total = 0;
    for (int i = 2; i <= level; i++) {
      total += (i - 1) * 250;
    }
    return total;
  }

  static int levelForXP(int totalXP) {
    int level = 1;
    while (totalXP >= xpRequiredForLevel(level + 1)) {
      level++;
    }
    return level;
  }

  static int xpIntoCurrentLevel(int totalXP) {
    final level = levelForXP(totalXP);
    return totalXP - xpRequiredForLevel(level);
  }

  static int xpNeededForNextLevel(int totalXP) {
    final level = levelForXP(totalXP);
    return xpRequiredForLevel(level + 1) - xpRequiredForLevel(level);
  }

  static double progressToNextLevel(int totalXP) {
    final needed = xpNeededForNextLevel(totalXP);
    if (needed <= 0) return 1.0;
    return (xpIntoCurrentLevel(totalXP) / needed).clamp(0.0, 1.0);
  }
}

// ─────────────────────────────────────────────────────────────────
// PROFILE
// ─────────────────────────────────────────────────────────────────
class GamificationProfile {
  final String uid;
  final String name;
  final String branch;
  final int totalXP;
  final int currentStreak;
  final int longestStreak;
  final String lastActivityDate;
  final List<String> achievementIds;
  final int missionsCompletedTotal;
  final int productsAdded;
  final int stockUpdates;

  GamificationProfile({
    required this.uid,
    required this.name,
    required this.branch,
    required this.totalXP,
    required this.currentStreak,
    required this.longestStreak,
    required this.lastActivityDate,
    required this.achievementIds,
    required this.missionsCompletedTotal,
    required this.productsAdded,
    required this.stockUpdates,
  });

  int get level => XPCurve.levelForXP(totalXP);
  int get xpIntoLevel => XPCurve.xpIntoCurrentLevel(totalXP);
  int get xpForNextLevel => XPCurve.xpNeededForNextLevel(totalXP);
  double get levelProgress => XPCurve.progressToNextLevel(totalXP);
  int get xpRemainingToNextLevel => xpForNextLevel - xpIntoLevel;

  factory GamificationProfile.empty(String uid, {String name = 'Staff', String branch = ''}) {
    return GamificationProfile(
      uid: uid,
      name: name,
      branch: branch,
      totalXP: 0,
      currentStreak: 0,
      longestStreak: 0,
      lastActivityDate: '',
      achievementIds: const [],
      missionsCompletedTotal: 0,
      productsAdded: 0,
      stockUpdates: 0,
    );
  }

  factory GamificationProfile.fromMap(String uid, Map<String, dynamic> map) {
    return GamificationProfile(
      uid: uid,
      name: (map['name'] as String?) ?? 'Staff',
      branch: (map['branch'] as String?) ?? '',
      totalXP: (map['totalXP'] as num?)?.toInt() ?? 0,
      currentStreak: (map['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (map['longestStreak'] as num?)?.toInt() ?? 0,
      lastActivityDate: (map['lastActivityDate'] as String?) ?? '',
      achievementIds: List<String>.from(map['achievementIds'] ?? const []),
      missionsCompletedTotal: (map['missionsCompletedTotal'] as num?)?.toInt() ?? 0,
      productsAdded: (map['productsAdded'] as num?)?.toInt() ?? 0,
      stockUpdates: (map['stockUpdates'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'branch': branch,
      'totalXP': totalXP,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastActivityDate': lastActivityDate,
      'achievementIds': achievementIds,
      'missionsCompletedTotal': missionsCompletedTotal,
      'productsAdded': productsAdded,
      'stockUpdates': stockUpdates,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

// ─────────────────────────────────────────────────────────────────
// MISSION
// ─────────────────────────────────────────────────────────────────
class Mission {
  final String id;
  final String title;
  final String iconKey;
  final int targetCount;
  final int currentCount;
  final int xpReward;

  Mission({
    required this.id,
    required this.title,
    required this.iconKey,
    required this.targetCount,
    required this.currentCount,
    required this.xpReward,
  });

  bool get isCompleted => currentCount >= targetCount;
  double get progress => targetCount <= 0 ? 0 : (currentCount / targetCount).clamp(0.0, 1.0);

  factory Mission.fromMap(Map<String, dynamic> map) {
    return Mission(
      id: (map['id'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      iconKey: (map['icon'] as String?) ?? 'task',
      targetCount: (map['targetCount'] as num?)?.toInt() ?? 1,
      currentCount: (map['currentCount'] as num?)?.toInt() ?? 0,
      xpReward: (map['xpReward'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'icon': iconKey,
      'targetCount': targetCount,
      'currentCount': currentCount,
      'xpReward': xpReward,
      'completed': isCompleted,
    };
  }

  Mission copyWith({int? currentCount}) {
    return Mission(
      id: id,
      title: title,
      iconKey: iconKey,
      targetCount: targetCount,
      currentCount: currentCount ?? this.currentCount,
      xpReward: xpReward,
    );
  }
}

class DailyMissionSet {
  final String uid;
  final String date;
  final List<Mission> missions;

  DailyMissionSet({required this.uid, required this.date, required this.missions});

  int get completedCount => missions.where((m) => m.isCompleted).length;
  bool get allCompleted => missions.isNotEmpty && completedCount == missions.length;

  factory DailyMissionSet.fromMap(String uid, String date, Map<String, dynamic> map) {
    final rawMissions = (map['missions'] as List<dynamic>? ?? []);
    return DailyMissionSet(
      uid: uid,
      date: date,
      missions: rawMissions
          .map((m) => Mission.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'date': date,
      'missions': missions.map((m) => m.toMap()).toList(),
    };
  }
}

// ─────────────────────────────────────────────────────────────────
// ACHIEVEMENT (catalog is static — defined in GamificationService)
// ─────────────────────────────────────────────────────────────────
class AchievementDef {
  final String id;
  final String title;
  final String description;
  final String iconKey;
  final int tier; // 1 = bronze .. 4 = legendary, purely for badge color

  const AchievementDef({
    required this.id,
    required this.title,
    required this.description,
    required this.iconKey,
    required this.tier,
  });
}

// ─────────────────────────────────────────────────────────────────
// RECENT ACTIVITY / REWARD LOG ENTRY
// ─────────────────────────────────────────────────────────────────
class RewardLogEntry {
  final String id;
  final String title;
  final String description;
  final int xp;
  final String iconKey;
  final DateTime? createdAt;

  RewardLogEntry({
    required this.id,
    required this.title,
    required this.description,
    required this.xp,
    required this.iconKey,
    required this.createdAt,
  });

  factory RewardLogEntry.fromDoc(String id, Map<String, dynamic> map) {
    final ts = map['createdAt'];
    return RewardLogEntry(
      id: id,
      title: (map['title'] as String?) ?? 'Activity',
      description: (map['description'] as String?) ?? '',
      xp: (map['xp'] as num?)?.toInt() ?? 0,
      iconKey: (map['icon'] as String?) ?? 'star',
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// LEADERBOARD ENTRY
// ─────────────────────────────────────────────────────────────────
class LeaderboardEntry {
  final String uid;
  final String name;
  final String branch;
  final int totalXP;
  final int currentStreak;

  LeaderboardEntry({
    required this.uid,
    required this.name,
    required this.branch,
    required this.totalXP,
    required this.currentStreak,
  });

  int get level => XPCurve.levelForXP(totalXP);

  factory LeaderboardEntry.fromMap(String uid, Map<String, dynamic> map) {
    return LeaderboardEntry(
      uid: uid,
      name: (map['name'] as String?) ?? 'Staff',
      branch: (map['branch'] as String?) ?? '',
      totalXP: (map['totalXP'] as num?)?.toInt() ?? 0,
      currentStreak: (map['currentStreak'] as num?)?.toInt() ?? 0,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// MONTHLY BADGE
// ─────────────────────────────────────────────────────────────────
// Firestore layout:
//   gamification_profiles/{uid}/monthly_badges/{yyyy-MM}
//       month, xp, earned, earnedAt
//
// A month's badge is unlocked the first time that month's accumulated
// XP crosses [xpThreshold] (250). Once earned it stays earned even if
// nothing else happens that month.
class MonthlyBadge {
  static const int xpThreshold = 250;

  final String month; // "yyyy-MM"
  final int xp;
  final bool earned;
  final DateTime? earnedAt;

  MonthlyBadge({
    required this.month,
    required this.xp,
    required this.earned,
    required this.earnedAt,
  });

  int get year => int.parse(month.split('-')[0]);
  int get monthNumber => int.parse(month.split('-')[1]);
  double get progress => (xp / xpThreshold).clamp(0.0, 1.0);
  int get xpRemaining => (xpThreshold - xp).clamp(0, xpThreshold);

  factory MonthlyBadge.empty(String month) {
    return MonthlyBadge(month: month, xp: 0, earned: false, earnedAt: null);
  }

  factory MonthlyBadge.fromMap(String month, Map<String, dynamic> map) {
    final ts = map['earnedAt'];
    return MonthlyBadge(
      month: month,
      xp: (map['xp'] as num?)?.toInt() ?? 0,
      earned: (map['earned'] as bool?) ?? false,
      earnedAt: ts is Timestamp ? ts.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'month': month,
      'xp': xp,
      'earned': earned,
    };
  }
}