// lib/constants/gamification_constants.dart
//
// Central catalog for the staff engagement / gamification system.
// Pure data + pure functions only — no Firestore calls in this file.

/// Every action across the app that counts toward staff engagement
/// (streaks, missions, achievements). Not all of these carry XP —
/// see [staffActionXp] below.
enum StaffAction {
  addProduct,
  editProduct,
  deleteProduct,
  stockUpdate,
  purchaseEntry,
  invoiceUpload,
  droneInOut,
  droneService,
  completeVerification,
}

extension StaffActionKey on StaffAction {
  /// Stable string key stored in Firestore docs (staff_activity_points.action,
  /// staff_rewards.actionCounts map keys). Never rename existing enum
  /// values without a migration — this string gets persisted to Firestore.
  String get key {
    switch (this) {
      case StaffAction.addProduct:
        return 'add_product';
      case StaffAction.editProduct:
        return 'edit_product';
      case StaffAction.deleteProduct:
        return 'delete_product';
      case StaffAction.stockUpdate:
        return 'stock_update';
      case StaffAction.purchaseEntry:
        return 'purchase_entry';
      case StaffAction.invoiceUpload:
        return 'invoice_upload';
      case StaffAction.droneInOut:
        return 'drone_in_out';
      case StaffAction.droneService:
        return 'drone_service';
      case StaffAction.completeVerification:
        return 'complete_verification';
    }
  }

  static StaffAction? fromKey(String key) {
    for (final a in StaffAction.values) {
      if (a.key == key) return a;
    }
    return null;
  }
}

/// XP awarded per action. Actions not listed here (purchaseEntry,
/// droneInOut, droneService) still count toward streaks/missions/
/// achievements but carry 0 XP — add an entry here if that changes.
const Map<StaffAction, int> staffActionXp = {
  StaffAction.addProduct: 10,
  StaffAction.editProduct: 5,
  StaffAction.deleteProduct: 2,
  StaffAction.stockUpdate: 5,
  StaffAction.invoiceUpload: 10,
  StaffAction.completeVerification: 20,
};

int xpForAction(StaffAction action) => staffActionXp[action] ?? 0;

/// Level thresholds: total XP required to REACH each level. Level is the
/// count of thresholds passed, +1. e.g. 0-99 XP = level 1, 100-249 = level 2.
const List<int> levelXpThresholds = [
  0, 100, 250, 500, 900, 1500, 2500, 4000, 6000, 9000,
];

int levelForXp(int xp) {
  var level = 1;
  for (var i = 1; i < levelXpThresholds.length; i++) {
    if (xp >= levelXpThresholds[i]) level = i + 1;
  }
  return level;
}

/// Which counter on staff_rewards an achievement's threshold is compared
/// against.
enum AchievementMetric {
  addProductCount,
  stockUpdateCount,
  totalActiveDays,
  droneTransactionCount,
}

class AchievementDefinition {
  final String id;
  final String title;
  final String description;
  final AchievementMetric metric;
  final int threshold;
  final int bonusXp;

  const AchievementDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.metric,
    required this.threshold,
    this.bonusXp = 0,
  });
}

const List<AchievementDefinition> achievementCatalog = [
  AchievementDefinition(
    id: 'inventory_starter',
    title: 'Inventory Starter',
    description: 'Add your first product',
    metric: AchievementMetric.addProductCount,
    threshold: 1,
    bonusXp: 10,
  ),
  AchievementDefinition(
    id: 'stock_master',
    title: 'Stock Master',
    description: 'Complete 100 stock updates',
    metric: AchievementMetric.stockUpdateCount,
    threshold: 100,
    bonusXp: 50,
  ),
  AchievementDefinition(
    id: 'accuracy_champion',
    title: 'Accuracy Champion',
    description: 'Stay active for 30 days',
    metric: AchievementMetric.totalActiveDays,
    threshold: 30,
    bonusXp: 100,
  ),
  AchievementDefinition(
    id: 'drone_expert',
    title: 'Drone Expert',
    description: 'Log 50 drone transactions',
    metric: AchievementMetric.droneTransactionCount,
    threshold: 50,
    bonusXp: 75,
  ),
];

/// Daily mission catalog. `matchesAction` decides which StaffActions count
/// toward that mission's progress for the day.
class MissionDefinition {
  final String id;
  final String title;
  final String description;
  final int target;
  final int xpReward;
  final bool Function(StaffAction action) matchesAction;

  const MissionDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.target,
    required this.xpReward,
    required this.matchesAction,
  });
}

final List<MissionDefinition> dailyMissionCatalog = [
  MissionDefinition(
    id: 'daily_active',
    title: 'Show Up',
    description: 'Do at least 1 activity today',
    target: 1,
    xpReward: 5,
    matchesAction: (a) => true,
  ),
  MissionDefinition(
    id: 'daily_products',
    title: 'Product Handler',
    description: 'Add or edit 3 products today',
    target: 3,
    xpReward: 15,
    matchesAction: (a) =>
    a == StaffAction.addProduct || a == StaffAction.editProduct,
  ),
  MissionDefinition(
    id: 'daily_stock',
    title: 'Stock Keeper',
    description: 'Perform 2 stock updates today',
    target: 2,
    xpReward: 10,
    matchesAction: (a) => a == StaffAction.stockUpdate,
  ),
];