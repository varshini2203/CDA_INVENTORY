// lib/screens/gamification/gamification_dashboard.dart

import 'package:flutter/material.dart';

import '../../models/gamification_models.dart';
import '../../services/auth_service.dart';
import '../../services/gamification_service.dart';
import 'reward_widgets.dart';
import 'dashboard_fun_widgets.dart';
import 'achievement_screen.dart';
import 'mission_screen.dart';
import 'leaderboard_screen.dart';
import 'monthly_badges_screen.dart';

class GamificationDashboard extends StatefulWidget {
  const GamificationDashboard({super.key});

  @override
  State<GamificationDashboard> createState() => _GamificationDashboardState();
}

class _GamificationDashboardState extends State<GamificationDashboard> {
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final profile = await AuthService.getUserProfile();
    await GamificationService.ensureProfile(
      name: (profile?['name'] as String?) ?? 'Staff',
      branch: (profile?['branch'] as String?) ?? '',
    );
    await GamificationService.ensureTodayMissions();
    if (mounted) setState(() => _initializing = false);
  }

  void _push(BuildContext context, String name, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(settings: RouteSettings(name: name), builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GKColors.navyDeep,
      appBar: AppBar(
        backgroundColor: GKColors.navy,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Staff Rewards',
                style: TextStyle(color: GKColors.textPrimary, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            const WiggleIcon(
              angle: 0.35,
              period: Duration(milliseconds: 1100),
              child: Text('🏆', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: GKColors.textPrimary),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: ConfettiDrift()),
          _initializing
              ? const Center(child: CircularProgressIndicator(color: GKColors.teal))
              : StreamBuilder<GamificationProfile>(
            stream: GamificationService.watchProfile(),
            builder: (context, profileSnap) {
              final profile = profileSnap.data ?? GamificationProfile.empty('');
              return StreamBuilder<DailyMissionSet>(
                stream: GamificationService.watchTodayMissions(),
                builder: (context, missionSnap) {
                  final missions = missionSnap.data?.missions ?? const <Mission>[];
                  return StreamBuilder<List<RewardLogEntry>>(
                    stream: GamificationService.watchRecentActivity(limit: 6),
                    builder: (context, activitySnap) {
                      final activity = activitySnap.data ?? const <RewardLogEntry>[];
                      return _buildBody(context, profile, missions, activity);
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
      BuildContext context,
      GamificationProfile profile,
      List<Mission> missions,
      List<RewardLogEntry> activity,
      ) {
    final width = MediaQuery.of(context).size.width;
    final maxContentWidth = width > 900 ? 900.0 : width;

    return RefreshIndicator(
      color: GKColors.teal,
      backgroundColor: GKColors.surface,
      onRefresh: _bootstrap,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeScaleIn(
                  child: Text(pickFunnyGreeting(),
                      style: const TextStyle(color: GKColors.textSecondary, fontSize: 14)),
                ),
                FadeScaleIn(
                  delayMs: 60,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(profile.name,
                          style: const TextStyle(
                              color: GKColors.textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(width: 8),
                      const WiggleIcon(
                        angle: 0.5,
                        period: Duration(milliseconds: 700),
                        child: Text('👋', style: TextStyle(fontSize: 22)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                FadeScaleIn(
                  delayMs: 100,
                  child: XPCard(
                    level: profile.level,
                    totalXP: profile.totalXP,
                    progress: profile.levelProgress,
                    xpToNext: profile.xpRemainingToNextLevel,
                  ),
                ),
                const SizedBox(height: 14),
                FadeScaleIn(
                  delayMs: 160,
                  child: StreakCard(
                    currentStreak: profile.currentStreak,
                    longestStreak: profile.longestStreak,
                  ),
                ),
                const SizedBox(height: 20),

                FadeScaleIn(
                  delayMs: 200,
                  child: GKSectionHeader(
                    title: '📊 Overview',
                  ),
                ),
                FadeScaleIn(
                  delayMs: 220,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = gkGridColumns(constraints.maxWidth);
                      return GridView.count(
                        crossAxisCount: cols,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.35,
                        children: [
                          StatTile(
                            icon: Icons.military_tech_rounded,
                            label: 'Achievements',
                            value: '${profile.achievementIds.length}/${GamificationService.achievementCatalog.length}',
                            color: GKColors.amber,
                          ),
                          StatTile(
                            icon: Icons.task_alt_rounded,
                            label: 'Missions Done',
                            value: '${profile.missionsCompletedTotal}',
                            color: GKColors.teal,
                          ),
                          StatTile(
                            icon: Icons.add_box_rounded,
                            label: 'Products Added',
                            value: '${profile.productsAdded}',
                            color: GKColors.purple,
                          ),
                          StatTile(
                            icon: Icons.inventory_2_rounded,
                            label: 'Stock Updates',
                            value: '${profile.stockUpdates}',
                            color: GKColors.green,
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                FadeScaleIn(
                  delayMs: 260,
                  child: GKSectionHeader(
                    title: "🎯 Today's Missions",
                    trailing: TextButton(
                      onPressed: () => _push(context, 'Missions', const MissionScreen()),
                      child: const Text('View all', style: TextStyle(color: GKColors.teal)),
                    ),
                  ),
                ),
                if (missions.isEmpty)
                  const _EmptyHint(text: 'No missions yet — the hamsters are still loading them 🐹')
                else
                  ...List.generate(missions.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FadeScaleIn(
                        delayMs: 280 + i * 40,
                        child: MissionTile(mission: missions[i]),
                      ),
                    );
                  }),
                const SizedBox(height: 24),

                FadeScaleIn(
                  delayMs: 320,
                  child: GKSectionHeader(
                    title: '📜 Recent Activity Rewards',
                    trailing: TextButton(
                      onPressed: () => _push(context, 'Achievements', const AchievementScreen()),
                      child: const Text('Badges', style: TextStyle(color: GKColors.teal)),
                    ),
                  ),
                ),
                FadeScaleIn(
                  delayMs: 340,
                  child: GlassCard(
                    child: activity.isEmpty
                        ? const _EmptyHint(text: "Crickets 🦗 Go add a product and change that.")
                        : Column(
                      children: activity
                          .map((e) => RewardActivityTile(entry: e))
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                FadeScaleIn(
                  delayMs: 380,
                  child: Row(
                    children: [
                      Expanded(
                        child: _NavCard(
                          icon: Icons.emoji_events_rounded,
                          label: 'Leaderboard',
                          color: GKColors.amber,
                          onTap: () => _push(context, 'Leaderboard', const LeaderboardScreen()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _NavCard(
                          icon: Icons.military_tech_rounded,
                          label: 'Achievements',
                          color: GKColors.purple,
                          onTap: () => _push(context, 'Achievements', const AchievementScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FadeScaleIn(
                  delayMs: 400,
                  child: _NavCard(
                    icon: Icons.workspace_premium_rounded,
                    label: 'Monthly Badges',
                    color: GKColors.teal,
                    onTap: () => _push(context, 'Monthly Badges', const MonthlyBadgesScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BounceTap(
      onTap: onTap,
      child: GlassCard(
        gradientColors: [color.withOpacity(0.22), GKColors.surface],
        child: Column(
          children: [
            FloatBob(
              distance: 4,
              period: const Duration(milliseconds: 1800),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    color: GKColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(text, style: const TextStyle(color: GKColors.textSecondary, fontSize: 13)),
    );
  }
}