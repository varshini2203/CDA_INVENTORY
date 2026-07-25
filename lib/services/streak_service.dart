// lib/services/streak_service.dart
//
// Pure streak calculation logic — no Firestore access. Given the staff
// member's current streak state and "now", returns the updated state.
// Called by StaffRewardService inside its own Firestore transaction, so
// the calculation itself stays a plain, unit-testable function with no
// side effects.

class StreakUpdateResult {
  final int currentStreak;
  final int longestStreak;
  final int totalActiveDays;
  final DateTime lastActiveDate;
  final bool isNewDay; // true when this call represents a new calendar day

  const StreakUpdateResult({
    required this.currentStreak,
    required this.longestStreak,
    required this.totalActiveDays,
    required this.lastActiveDate,
    required this.isNewDay,
  });
}

class StreakService {
  StreakService._();

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Computes the new streak state after an activity at [now], given the
  /// previous [lastActiveDate] / [currentStreak] / [longestStreak] /
  /// [totalActiveDays].
  static StreakUpdateResult calculate({
    required DateTime? lastActiveDate,
    required int currentStreak,
    required int longestStreak,
    required int totalActiveDays,
    DateTime? now,
  }) {
    final today = _dateOnly(now ?? DateTime.now());

    if (lastActiveDate == null) {
      // First ever activity for this user.
      return StreakUpdateResult(
        currentStreak: 1,
        longestStreak: longestStreak < 1 ? 1 : longestStreak,
        totalActiveDays: totalActiveDays + 1,
        lastActiveDate: today,
        isNewDay: true,
      );
    }

    final lastDay = _dateOnly(lastActiveDate);
    final dayDiff = today.difference(lastDay).inDays;

    if (dayDiff <= 0) {
      // Already active today (or a clock skew put "now" before lastDay) —
      // no streak change, no new-day bonus, but guard against a stored 0.
      return StreakUpdateResult(
        currentStreak: currentStreak == 0 ? 1 : currentStreak,
        longestStreak: longestStreak == 0 ? 1 : longestStreak,
        totalActiveDays: totalActiveDays == 0 ? 1 : totalActiveDays,
        lastActiveDate: lastDay,
        isNewDay: false,
      );
    }

    if (dayDiff == 1) {
      // Consecutive calendar day — streak continues.
      final newStreak = currentStreak + 1;
      return StreakUpdateResult(
        currentStreak: newStreak,
        longestStreak: newStreak > longestStreak ? newStreak : longestStreak,
        totalActiveDays: totalActiveDays + 1,
        lastActiveDate: today,
        isNewDay: true,
      );
    }

    // Gap of 2+ days — streak resets to 1, longest-streak record kept.
    return StreakUpdateResult(
      currentStreak: 1,
      longestStreak: longestStreak,
      totalActiveDays: totalActiveDays + 1,
      lastActiveDate: today,
      isNewDay: true,
    );
  }
}