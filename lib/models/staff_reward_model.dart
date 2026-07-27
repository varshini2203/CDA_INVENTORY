// lib/models/staff_reward_model.dart
//
// Data models for the staff engagement / gamification system. No Firestore
// writes happen here — these are pure fromDoc/toMap data classes, mirroring
// the existing model style used across the project (see ActivityLogModel
// in app_access_models.dart).

import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/gamification_constants.dart';

/// Mirrors a single doc in `staff_rewards/{userId}`.
class StaffRewardModel {
  final String userId;
  final int xp;
  final int level;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastActiveDate;
  final int totalActiveDays;
  final Map<String, int> actionCounts;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const StaffRewardModel({
    required this.userId,
    this.xp = 0,
    this.level = 1,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastActiveDate,
    this.totalActiveDays = 0,
    this.actionCounts = const {},
    this.createdAt,
    this.updatedAt,
  });

  factory StaffRewardModel.empty(String userId) =>
      StaffRewardModel(userId: userId);

  factory StaffRewardModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return StaffRewardModel(
      userId: (data['userId'] as String?) ?? doc.id,
      xp: (data['xp'] as num?)?.toInt() ?? 0,
      level: (data['level'] as num?)?.toInt() ?? 1,
      currentStreak: (data['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (data['longestStreak'] as num?)?.toInt() ?? 0,
      lastActiveDate: (data['lastActiveDate'] as Timestamp?)?.toDate(),
      totalActiveDays: (data['totalActiveDays'] as num?)?.toInt() ?? 0,
      actionCounts: data['actionCounts'] is Map
          ? Map<String, int>.from((data['actionCounts'] as Map)
          .map((k, v) => MapEntry(k.toString(), (v as num).toInt())))
          : const {},
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'xp': xp,
    'level': level,
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'lastActiveDate':
    lastActiveDate == null ? null : Timestamp.fromDate(lastActiveDate!),
    'totalActiveDays': totalActiveDays,
    'actionCounts': actionCounts,
    'createdAt': createdAt == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(createdAt!),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  /// Reads the counter that a given [AchievementMetric] cares about.
  int countFor(AchievementMetric metric) {
    switch (metric) {
      case AchievementMetric.addProductCount:
        return actionCounts[StaffAction.addProduct.key] ?? 0;
      case AchievementMetric.stockUpdateCount:
        return actionCounts[StaffAction.stockUpdate.key] ?? 0;
      case AchievementMetric.totalActiveDays:
        return totalActiveDays;
      case AchievementMetric.droneTransactionCount:
        return (actionCounts[StaffAction.droneInOut.key] ?? 0) +
            (actionCounts[StaffAction.droneService.key] ?? 0);
    }
  }

  StaffRewardModel copyWith({
    int? xp,
    int? level,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastActiveDate,
    int? totalActiveDays,
    Map<String, int>? actionCounts,
    DateTime? createdAt,
  }) {
    return StaffRewardModel(
      userId: userId,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      totalActiveDays: totalActiveDays ?? this.totalActiveDays,
      actionCounts: actionCounts ?? this.actionCounts,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

/// Mirrors one doc in `staff_activity_points` — a single XP-earning event.
class StaffActivityPointModel {
  final String id;
  final String userId;
  final String action;
  final String module;
  final int points;
  final DateTime? timestamp;

  const StaffActivityPointModel({
    required this.id,
    required this.userId,
    required this.action,
    required this.module,
    required this.points,
    this.timestamp,
  });

  factory StaffActivityPointModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return StaffActivityPointModel(
      id: doc.id,
      userId: (data['userId'] as String?) ?? '',
      action: (data['action'] as String?) ?? '',
      module: (data['module'] as String?) ?? '',
      points: (data['points'] as num?)?.toInt() ?? 0,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'action': action,
    'module': module,
    'points': points,
    'timestamp': FieldValue.serverTimestamp(),
  };
}

/// Mirrors one doc in `staff_achievements` — doc id `{userId}_{achievementId}`.
class AchievementUnlockModel {
  final String userId;
  final String achievementId;
  final String title;
  final String description;
  final DateTime? unlockedAt;

  const AchievementUnlockModel({
    required this.userId,
    required this.achievementId,
    required this.title,
    required this.description,
    this.unlockedAt,
  });

  factory AchievementUnlockModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AchievementUnlockModel(
      userId: (data['userId'] as String?) ?? '',
      achievementId: (data['achievementId'] as String?) ?? '',
      title: (data['title'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      unlockedAt: (data['unlockedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'achievementId': achievementId,
    'title': title,
    'description': description,
    'unlockedAt': FieldValue.serverTimestamp(),
  };
}

/// One mission's progress within a `DailyMissionProgressModel`.
class MissionProgress {
  final int progress;
  final int target;
  final bool completed;

  const MissionProgress({
    required this.progress,
    required this.target,
    this.completed = false,
  });

  factory MissionProgress.fromMap(Map<String, dynamic> map) => MissionProgress(
    progress: (map['progress'] as num?)?.toInt() ?? 0,
    target: (map['target'] as num?)?.toInt() ?? 0,
    completed: (map['completed'] as bool?) ?? false,
  );

  Map<String, dynamic> toMap() => {
    'progress': progress,
    'target': target,
    'completed': completed,
  };

  MissionProgress copyWith({int? progress, bool? completed}) => MissionProgress(
    progress: progress ?? this.progress,
    target: target,
    completed: completed ?? this.completed,
  );
}

/// Mirrors one doc in `staff_daily_missions` — doc id `{userId}_{yyyyMMdd}`.
class DailyMissionProgressModel {
  final String userId;
  final String date; // yyyyMMdd
  final Map<String, MissionProgress> missions;
  final DateTime? updatedAt;

  const DailyMissionProgressModel({
    required this.userId,
    required this.date,
    this.missions = const {},
    this.updatedAt,
  });

  factory DailyMissionProgressModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawMissions = data['missions'];
    final missions = <String, MissionProgress>{};
    if (rawMissions is Map) {
      rawMissions.forEach((key, value) {
        if (value is Map) {
          missions[key.toString()] =
              MissionProgress.fromMap(Map<String, dynamic>.from(value));
        }
      });
    }
    return DailyMissionProgressModel(
      userId: (data['userId'] as String?) ?? '',
      date: (data['date'] as String?) ?? '',
      missions: missions,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'date': date,
    'missions': missions.map((k, v) => MapEntry(k, v.toMap())),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}