// lib/screens/gamification/gamification_dashboard.dart

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/gamification_models.dart';
import '../../services/auth_service.dart';
import '../../services/gamification_service.dart';
import 'reward_widgets.dart';
import 'dashboard_fun_widgets.dart';
import 'premium_dashboard_widgets.dart';
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
  String? _bootstrapError;

  // Best-effort "member since" date. This is purely a presentation
  // detail for the new hero card — it reads a field ('createdAt')
  // that AuthService.getUserProfile() already returns from the
  // existing `users/{uid}` document (set at registration time). No
  // service, model, or Firestore collection is touched or changed to
  // get this; if it's ever missing/absent we simply fall back to a
  // generic label below.
  DateTime? _memberSince;

  // Created once and reused for the lifetime of this screen. Previously
  // these Streams were constructed inline as the `stream:` argument of
  // each StreamBuilder, which meant a brand-new Firestore .snapshots()
  // listener was opened every time build() ran. Because the three
  // StreamBuilders are nested, every emission from the profile stream
  // re-ran the builder callback and recreated the missions stream below
  // it, and every emission from that recreated the activity stream below
  // that — a cascade of listeners opening and closing in quick succession
  // that was exhausting the Firestore connection quota (429
  // resource-exhausted errors). Holding one instance per stream here means
  // StreamBuilder sees the same Stream object across rebuilds and never
  // resubscribes.
  late final Stream<GamificationProfile> _profileStream =
  GamificationService.watchProfile();
  late final Stream<DailyMissionSet> _missionsStream =
  GamificationService.watchTodayMissions();
  late final Stream<List<RewardLogEntry>> _activityStream =
  GamificationService.watchRecentActivity(limit: 6);
  // Same reasoning as above — held once so the new "Top Performers"
  // section and the profile card's rank chip don't cause repeated
  // leaderboard listeners to open/close on every rebuild.
  late final Stream<List<LeaderboardEntry>> _leaderboardStream =
  GamificationService.watchLeaderboard(limit: 50);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  // Previously any failure here (e.g. a transient Firestore
  // resource-exhausted/429 error, or no network) propagated as an
  // uncaught exception because nothing awaited or caught this Future.
  // _initializing was only ever set to false on the success path, so a
  // single failed call left the screen showing the loading spinner
  // forever with no way to recover short of leaving and reopening the
  // screen. It's now wrapped in try/catch: on failure we stop showing the
  // spinner, keep the error message so the UI can show a retry button,
  // and _bootstrap() can simply be called again.
  Future<void> _bootstrap() async {
    if (mounted) setState(() => _bootstrapError = null);
    try {
      final profile = await AuthService.getUserProfile();
      final rawCreatedAt = profile?['createdAt'];
      if (mounted) {
        setState(() {
          _memberSince = rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : null;
        });
      }
      await GamificationService.ensureProfile(
        name: (profile?['name'] as String?) ?? 'Staff',
        branch: (profile?['branch'] as String?) ?? '',
      );
      await GamificationService.ensureTodayMissions();
      if (mounted) setState(() => _initializing = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _bootstrapError = e.toString();
        });
      }
    }
  }

  void _push(BuildContext context, String name, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(settings: RouteSettings(name: name), builder: (_) => screen),
    );
  }

  Widget _bootstrapErrorState() {
    final quotaHit = _bootstrapError?.contains('resource-exhausted') == true;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded, color: GKColors.coral, size: 44),
          const SizedBox(height: 16),
          Text(
            quotaHit
                ? 'Too many requests right now — please wait a moment and try again.'
                : 'Could not load Staff Rewards.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: GKColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            _bootstrapError ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(color: GKColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              setState(() => _initializing = true);
              _bootstrap();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: GKColors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
      ),
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
          const Positioned.fill(child: AmbientDecor()),
          const Positioned.fill(child: ConfettiDrift()),
          _initializing
              ? const Center(child: CircularProgressIndicator(color: GKColors.teal))
              : _bootstrapError != null
              ? _bootstrapErrorState()
              : StreamBuilder<GamificationProfile>(
            stream: _profileStream,
            builder: (context, profileSnap) {
              final profile = profileSnap.data ?? GamificationProfile.empty('');
              return StreamBuilder<DailyMissionSet>(
                stream: _missionsStream,
                builder: (context, missionSnap) {
                  final missions = missionSnap.data?.missions ?? const <Mission>[];
                  return StreamBuilder<List<RewardLogEntry>>(
                    stream: _activityStream,
                    builder: (context, activitySnap) {
                      final activity = activitySnap.data ?? const <RewardLogEntry>[];
                      return StreamBuilder<List<LeaderboardEntry>>(
                        stream: _leaderboardStream,
                        builder: (context, leaderboardSnap) {
                          final leaderboard = leaderboardSnap.data ?? const <LeaderboardEntry>[];
                          return _buildBody(context, profile, missions, activity, leaderboard);
                        },
                      );
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
      List<LeaderboardEntry> leaderboard,
      ) {
    final width = MediaQuery.of(context).size.width;
    final maxContentWidth = width > 900 ? 900.0 : width;
    final rank = rankOf(leaderboard, profile.uid);
    final memberSinceLabel =
    _memberSince != null ? 'Since ${DateFormat('MMM yyyy').format(_memberSince!)}' : 'New member';
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final loggedInToday = profile.lastActivityDate == todayKey;

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
                // ── Premium hero section: greeting, name, and the
                // profile card (avatar + XP ring, level, rank, XP,
                // member since) sit on a soft gradient backdrop with
                // drifting glow particles and a faint trophy mark.
                FadeScaleIn(
                  child: PremiumHeroBackdrop(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pickFunnyGreeting(),
                            style: const TextStyle(color: GKColors.textSecondary, fontSize: 14)),
                        const SizedBox(height: 6),
                        Row(
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
                        const SizedBox(height: 20),
                        ProfileHeroCard(
                          profile: profile,
                          rank: rank,
                          memberSinceLabel: memberSinceLabel,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                FadeScaleIn(
                  delayMs: 160,
                  child: StreakCardPremium(
                    currentStreak: profile.currentStreak,
                    longestStreak: profile.longestStreak,
                    loggedInToday: loggedInToday,
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
                          OverviewStatCard(
                            icon: Icons.military_tech_rounded,
                            label: 'Achievements',
                            value: profile.achievementIds.length,
                            outOf: GamificationService.achievementCatalog.length,
                            color: GKColors.amber,
                          ),
                          OverviewStatCard(
                            icon: Icons.task_alt_rounded,
                            label: 'Missions Done',
                            value: profile.missionsCompletedTotal,
                            color: GKColors.teal,
                          ),
                          OverviewStatCard(
                            icon: Icons.add_box_rounded,
                            label: 'Products Added',
                            value: profile.productsAdded,
                            color: GKColors.purple,
                          ),
                          OverviewStatCard(
                            icon: Icons.inventory_2_rounded,
                            label: 'Stock Updates',
                            value: profile.stockUpdates,
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
                  const GKEmptyHint(text: 'No missions yet — the hamsters are still loading them 🐹')
                else
                  ...List.generate(missions.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FadeScaleIn(
                        delayMs: 280 + i * 40,
                        child: MissionCardPremium(mission: missions[i]),
                      ),
                    );
                  }),
                const SizedBox(height: 24),

                FadeScaleIn(
                  delayMs: 300,
                  child: GKSectionHeader(title: '🏆 Top Performers'),
                ),
                FadeScaleIn(
                  delayMs: 320,
                  child: TopPerformersSection(entries: leaderboard),
                ),
                const SizedBox(height: 24),

                FadeScaleIn(
                  delayMs: 340,
                  child: GKSectionHeader(
                    title: '📜 Recent Activity Rewards',
                    trailing: TextButton(
                      onPressed: () => _push(context, 'Achievements', const AchievementScreen()),
                      child: const Text('Badges', style: TextStyle(color: GKColors.teal)),
                    ),
                  ),
                ),
                FadeScaleIn(
                  delayMs: 360,
                  child: GlassCard(
                    child: activity.isEmpty
                        ? const GKEmptyHint(text: "Crickets 🦗 Go add a product and change that.")
                        : Column(
                      children: List.generate(activity.length, (i) {
                        return RewardTimelineTile(
                          entry: activity[i],
                          isLast: i == activity.length - 1,
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                FadeScaleIn(
                  delayMs: 380,
                  child: NavCardLarge(
                    icon: Icons.emoji_events_rounded,
                    label: 'Leaderboard',
                    subtitle: 'See how you rank against the team',
                    gradientColors: [GKColors.amber, GKColors.amber.withOpacity(0.6)],
                    onTap: () => _push(context, 'Leaderboard', const LeaderboardScreen()),
                  ),
                ),
                const SizedBox(height: 12),
                FadeScaleIn(
                  delayMs: 400,
                  child: NavCardLarge(
                    icon: Icons.military_tech_rounded,
                    label: 'Achievements',
                    subtitle: 'Unlock badges as you level up',
                    gradientColors: GKColors.purpleGradient,
                    onTap: () => _push(context, 'Achievements', const AchievementScreen()),
                  ),
                ),
                const SizedBox(height: 12),
                FadeScaleIn(
                  delayMs: 420,
                  child: NavCardLarge(
                    icon: Icons.workspace_premium_rounded,
                    label: 'Monthly Badges',
                    subtitle: 'Track this month\'s progress',
                    gradientColors: [GKColors.teal, GKColors.teal.withOpacity(0.6)],
                    onTap: () => _push(context, 'Monthly Badges', const MonthlyBadgesScreen()),
                  ),
                ),
                const SizedBox(height: 24),

                FadeScaleIn(
                  delayMs: 440,
                  child: GKSectionHeader(title: '🏅 Your Badges'),
                ),
                FadeScaleIn(
                  delayMs: 460,
                  child: BadgeShowcase(
                    profile: profile,
                    catalog: GamificationService.achievementCatalog,
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