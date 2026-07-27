// lib/screens/gamification/monthly_badges_screen.dart
//
// Shows one badge per calendar month. A month's badge unlocks the
// first time that month's accumulated XP reaches 250 (see
// MonthlyBadge.xpThreshold / GamificationService._applyMonthlyBadgeXp).
// Earned months render as a glowing colored badge; not-yet-earned
// months render locked/greyscale — the current month additionally
// shows live progress toward the threshold.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/gamification_models.dart';
import '../../services/gamification_service.dart';
import 'reward_widgets.dart';

class MonthlyBadgesScreen extends StatefulWidget {
  const MonthlyBadgesScreen({super.key});

  @override
  State<MonthlyBadgesScreen> createState() => _MonthlyBadgesScreenState();
}

class _MonthlyBadgesScreenState extends State<MonthlyBadgesScreen> {
  late int _year;

  static const List<Color> _palette = [
    GKColors.teal,
    GKColors.amber,
    GKColors.purple,
    GKColors.coral,
    Color(0xFF4FD1C5),
    Color(0xFFF2A65A),
  ];

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
  }

  Color _colorForMonth(int monthIndex) => _palette[monthIndex % _palette.length];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      backgroundColor: GKColors.navyDeep,
      appBar: AppBar(
        backgroundColor: GKColors.navy,
        elevation: 0,
        title: const Text('Monthly Badges',
            style: TextStyle(color: GKColors.textPrimary, fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: GKColors.textPrimary),
        actions: [
          IconButton(
            tooltip: 'Previous year',
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => setState(() => _year -= 1),
          ),
          IconButton(
            tooltip: 'Next year',
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: _year >= now.year ? null : () => setState(() => _year += 1),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<List<MonthlyBadge>>(
        stream: GamificationService.watchMonthlyBadges(year: _year),
        builder: (context, snap) {
          final badges = snap.data ??
              List.generate(12, (i) => MonthlyBadge.empty('$_year-${(i + 1).toString().padLeft(2, '0')}'));
          final earnedCount = badges.where((b) => b.earned).length;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeScaleIn(
                      child: GlassCard(
                        gradientColors: [GKColors.teal.withOpacity(0.22), GKColors.surface],
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: GKColors.xpGradient),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.workspace_premium_rounded,
                                  color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$_year Badges',
                                    style: const TextStyle(
                                        color: GKColors.textPrimary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800)),
                                Text('$earnedCount / 12 earned  ·  reach ${MonthlyBadge.xpThreshold} XP in a month to unlock it',
                                    style: const TextStyle(color: GKColors.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cols = gkGridColumns(constraints.maxWidth);
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: 12,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.82,
                          ),
                          itemBuilder: (context, i) {
                            final badge = badges[i];
                            final isCurrentMonth = _year == now.year && badge.monthNumber == now.month;
                            final isFuture = _year > now.year ||
                                (_year == now.year && badge.monthNumber > now.month);
                            return FadeScaleIn(
                              delayMs: 50 * i,
                              child: _MonthBadgeTile(
                                badge: badge,
                                color: _colorForMonth(i),
                                isCurrentMonth: isCurrentMonth,
                                isFuture: isFuture,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MonthBadgeTile extends StatefulWidget {
  final MonthlyBadge badge;
  final Color color;
  final bool isCurrentMonth;
  final bool isFuture;

  const _MonthBadgeTile({
    required this.badge,
    required this.color,
    required this.isCurrentMonth,
    required this.isFuture,
  });

  @override
  State<_MonthBadgeTile> createState() => _MonthBadgeTileState();
}

class _MonthBadgeTileState extends State<_MonthBadgeTile> with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  String _monthName(int monthNumber) =>
      DateFormat('MMMM').format(DateTime(2000, monthNumber, 1));

  @override
  Widget build(BuildContext context) {
    final badge = widget.badge;
    final earned = badge.earned;
    final color = earned ? widget.color : GKColors.locked;

    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glow = earned ? (0.22 + 0.22 * _glowController.value) : 0.0;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: earned
                ? [BoxShadow(color: color.withOpacity(glow), blurRadius: 22, spreadRadius: 1)]
                : [],
          ),
          child: child,
        );
      },
      child: Opacity(
        opacity: earned ? 1.0 : (widget.isFuture ? 0.35 : 0.55),
        child: GlassCard(
          gradientColors: earned
              ? [color.withOpacity(0.25), GKColors.surface]
              : [GKColors.surface, GKColors.surface],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: earned ? LinearGradient(colors: [color, color.withOpacity(0.6)]) : null,
                  color: earned ? null : GKColors.locked.withOpacity(0.25),
                  border: Border.all(
                      color: earned ? color : GKColors.locked.withOpacity(0.5), width: 2),
                ),
                child: Icon(
                  earned ? Icons.emoji_events_rounded : Icons.lock_rounded,
                  color: earned ? Colors.white : GKColors.textSecondary,
                  size: 26,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _monthName(badge.monthNumber),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: earned ? GKColors.textPrimary : GKColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              if (earned)
                Text('${badge.xp} XP',
                    style: const TextStyle(color: GKColors.amber, fontSize: 11, fontWeight: FontWeight.w700))
              else if (widget.isCurrentMonth)
                Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 56,
                        height: 5,
                        child: XPProgressBar(progress: badge.progress, height: 5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${badge.xp}/${MonthlyBadge.xpThreshold} XP',
                        style: const TextStyle(color: GKColors.textSecondary, fontSize: 10)),
                  ],
                )
              else
                Text(widget.isFuture ? 'Not started' : '${badge.xp}/${MonthlyBadge.xpThreshold} XP',
                    style: const TextStyle(color: GKColors.textSecondary, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}