// lib/screens/gamification/premium_dashboard_widgets.dart
//
// Premium "enterprise gamification dashboard" presentation layer for
// the Staff Rewards screen. Everything in this file is PURELY VISUAL —
// every widget here only renders data that is handed to it as plain
// constructor parameters. Nothing in this file imports or calls
// Firestore, a provider, or any service, and nothing here changes any
// existing model, route, or business logic.
//
// It deliberately reuses the shared design tokens and animated
// primitives already defined for the gamification module
// (GKColors / GlassCard / FadeScaleIn / XPProgressBar / WiggleIcon /
// PulseScale / FloatBob / BounceTap / AchievementBadge / iconForKey)
// from reward_widgets.dart and dashboard_fun_widgets.dart, so the
// Achievements / Missions / Leaderboard / Monthly Badges screens that
// also depend on those files are completely unaffected.

import 'dart:math';
import 'package:flutter/material.dart';

import '../../models/gamification_models.dart';
import 'reward_widgets.dart';
import 'dashboard_fun_widgets.dart';

// ── Small shared helpers ──────────────────────────────────────────

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts[0].substring(0, min(2, parts[0].length)).toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

/// Lightweight "x time ago" formatter with no extra package dependency
/// (kept deliberately simple/lightweight per the perf requirement).
String timeAgoLabel(DateTime? dt) {
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.isNegative || diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
  return '${(diff.inDays / 365).floor()}y ago';
}

/// Rank of [uid] within an already-sorted (descending XP) leaderboard,
/// or null if not found / not signed in. Purely a presentation-layer
/// lookup — does not touch Firestore itself (the list is supplied by
/// the existing GamificationService.watchLeaderboard stream).
int? rankOf(List<LeaderboardEntry> entries, String uid) {
  if (uid.isEmpty) return null;
  final idx = entries.indexWhere((e) => e.uid == uid);
  return idx == -1 ? null : idx + 1;
}

enum MissionDifficulty { easy, medium, hard }

/// Cosmetic-only difficulty classification derived from a mission's
/// existing xpReward — no new fields, no change to Mission itself.
MissionDifficulty missionDifficultyOf(Mission m) {
  if (m.xpReward <= 30) return MissionDifficulty.easy;
  if (m.xpReward <= 45) return MissionDifficulty.medium;
  return MissionDifficulty.hard;
}

Color missionDifficultyColor(MissionDifficulty d) {
  switch (d) {
    case MissionDifficulty.easy:
      return GKColors.green;
    case MissionDifficulty.medium:
      return GKColors.amber;
    case MissionDifficulty.hard:
      return GKColors.coral;
  }
}

String missionDifficultyLabel(MissionDifficulty d) {
  switch (d) {
    case MissionDifficulty.easy:
      return 'Easy';
    case MissionDifficulty.medium:
      return 'Medium';
    case MissionDifficulty.hard:
      return 'Hard';
  }
}

// ── Generic empty-state hint (public twin of the dashboard's private
//    _EmptyHint, reusable from this file's sections too) ────────────
class GKEmptyHint extends StatelessWidget {
  final String text;
  const GKEmptyHint({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(text, style: const TextStyle(color: GKColors.textSecondary, fontSize: 13)),
    );
  }
}

// ── Count-up number animation ─────────────────────────────────────
class CountUpText extends StatelessWidget {
  final int value;
  final String suffix;
  final String prefix;
  final TextStyle style;
  const CountUpText({
    super.key,
    required this.value,
    this.suffix = '',
    this.prefix = '',
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('$prefix$v$suffix', style: style),
    );
  }
}

// ── Ambient floating decorative shapes (stars / trophy outlines /
//    sparkles / medal outlines) kept under 10% opacity, non-interactive.
class AmbientDecor extends StatelessWidget {
  const AmbientDecor({super.key});

  static const List<_DecorSpec> _specs = [
    _DecorSpec(left: 0.06, top: 0.03, icon: Icons.star_outline_rounded, size: 26),
    _DecorSpec(left: 0.86, top: 0.08, icon: Icons.emoji_events_outlined, size: 48),
    _DecorSpec(left: 0.16, top: 0.24, icon: Icons.auto_awesome_outlined, size: 20),
    _DecorSpec(left: 0.76, top: 0.34, icon: Icons.military_tech_outlined, size: 34),
    _DecorSpec(left: 0.32, top: 0.52, icon: Icons.star_outline_rounded, size: 18),
    _DecorSpec(left: 0.92, top: 0.60, icon: Icons.auto_awesome_outlined, size: 24),
    _DecorSpec(left: 0.04, top: 0.72, icon: Icons.emoji_events_outlined, size: 30),
    _DecorSpec(left: 0.58, top: 0.86, icon: Icons.military_tech_outlined, size: 22),
    _DecorSpec(left: 0.40, top: 0.14, icon: Icons.auto_awesome_outlined, size: 16),
    _DecorSpec(left: 0.68, top: 0.94, icon: Icons.star_outline_rounded, size: 20),
  ];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: _specs.map((s) {
              return Positioned(
                left: constraints.maxWidth * s.left,
                top: constraints.maxHeight * s.top,
                child: FloatBob(
                  distance: 5,
                  period: Duration(milliseconds: 2200 + (s.size * 25).round()),
                  child: Opacity(
                    opacity: 0.07,
                    child: Icon(s.icon, size: s.size, color: GKColors.textSecondary),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _DecorSpec {
  final double left;
  final double top;
  final IconData icon;
  final double size;
  const _DecorSpec({required this.left, required this.top, required this.icon, required this.size});
}

// ── Circular animated XP ring (wraps an avatar/level chip) ────────
class XPRing extends StatelessWidget {
  final double progress;
  final double size;
  final double strokeWidth;
  final Widget child;

  const XPRing({
    super.key,
    required this.progress,
    required this.child,
    this.size = 92,
    this.strokeWidth = 7,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: strokeWidth,
              valueColor: AlwaysStoppedAnimation(Colors.white.withOpacity(0.08)),
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return SizedBox(
                width: size,
                height: size,
                child: ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    colors: GKColors.xpGradient,
                  ).createShader(rect),
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: strokeWidth,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Colors.transparent,
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              );
            },
          ),
          child,
        ],
      ),
    );
  }
}

// ── Avatar with a soft glow, initials-based (no new avatar storage
//    needed — nothing here reads or writes a photo URL / Firestore) ─
class AvatarGlow extends StatelessWidget {
  final String name;
  final double size;

  const AvatarGlow({super.key, required this.name, this.size = 60});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: GKColors.purpleGradient,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.28), width: 2),
        boxShadow: [
          BoxShadow(color: GKColors.purple.withOpacity(0.55), blurRadius: 18, spreadRadius: 1),
        ],
      ),
      child: Text(
        initialsOf(name),
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.32),
      ),
    );
  }
}

// ── Small pill chip (rank / member since / branch, etc.) ──────────
class GKChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const GKChip({super.key, required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── Premium hero backdrop (gradient + drifting glow particles +
//    faint trophy illustration) wrapping the profile card ─────────
class PremiumHeroBackdrop extends StatefulWidget {
  final Widget child;
  const PremiumHeroBackdrop({super.key, required this.child});

  @override
  State<PremiumHeroBackdrop> createState() => _PremiumHeroBackdropState();
}

class _PremiumHeroBackdropState extends State<PremiumHeroBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_GlowParticle> _particles = List.generate(10, (i) {
    final rnd = Random(i * 31 + 7);
    return _GlowParticle(
      left: rnd.nextDouble(),
      top: rnd.nextDouble(),
      size: 3 + rnd.nextDouble() * 4,
      phase: rnd.nextDouble(),
    );
  });

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [GKColors.navy, GKColors.surfaceHigh, GKColors.purple.withOpacity(0.35)],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 12)),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children:
                          _particles.map((p) => p.build(_controller.value, constraints)).toList(),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
          Positioned(
            right: -20,
            top: -20,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.09,
                child: Icon(Icons.emoji_events_rounded, size: 150, color: GKColors.amber),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _GlowParticle {
  final double left;
  final double top;
  final double size;
  final double phase;
  _GlowParticle({required this.left, required this.top, required this.size, required this.phase});

  Widget build(double t, BoxConstraints c) {
    final loop = (t + phase) % 1.0;
    final opacity = sin(loop * pi).clamp(0.0, 1.0) * 0.5;
    return Positioned(
      left: c.maxWidth * left,
      top: c.maxHeight * top,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: GKColors.teal,
            boxShadow: [BoxShadow(color: GKColors.teal.withOpacity(0.8), blurRadius: 6)],
          ),
        ),
      ),
    );
  }
}

// ── Profile hero card: avatar + XP ring, level badge, XP, rank,
//    member-since — sits inside PremiumHeroBackdrop ─────────────────
class ProfileHeroCard extends StatelessWidget {
  final GamificationProfile profile;
  final int? rank;
  final String memberSinceLabel;

  const ProfileHeroCard({
    super.key,
    required this.profile,
    required this.rank,
    required this.memberSinceLabel,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 380;

        final avatarRing = Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            XPRing(
              progress: profile.levelProgress,
              size: 88,
              child: AvatarGlow(name: profile.name, size: 62),
            ),
            Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: GKColors.xpGradient),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: GKColors.navy, width: 2),
                ),
                child: Text(
                  'Lv ${profile.level}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        );

        final stats = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CountUpText(
                  value: profile.totalXP,
                  suffix: ' XP',
                  style: const TextStyle(
                      color: GKColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 8),
                if (rank != null) GKChip(icon: Icons.leaderboard_rounded, label: '#$rank', color: GKColors.amber),
              ],
            ),
            const SizedBox(height: 8),
            XPProgressBar(progress: profile.levelProgress),
            const SizedBox(height: 6),
            Text(
              profile.xpRemainingToNextLevel > 0
                  ? '${profile.xpRemainingToNextLevel} XP to Level ${profile.level + 1}'
                  : 'Max level reached',
              style: const TextStyle(color: GKColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                GKChip(icon: Icons.calendar_month_rounded, label: memberSinceLabel, color: GKColors.teal),
                GKChip(
                  icon: Icons.place_rounded,
                  label: profile.branch.isEmpty ? 'HQ' : profile.branch,
                  color: GKColors.purple,
                ),
              ],
            ),
          ],
        );

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [avatarRing, const SizedBox(height: 16), stats],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [avatarRing, const SizedBox(width: 18), Expanded(child: stats)],
        );
      },
    );
  }
}

// ── Premium streak card: animated flame, gradient, glow, daily
//    login status ────────────────────────────────────────────────
class StreakCardPremium extends StatelessWidget {
  final int currentStreak;
  final int longestStreak;
  final bool loggedInToday;

  const StreakCardPremium({
    super.key,
    required this.currentStreak,
    required this.longestStreak,
    required this.loggedInToday,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      gradientColors: [
        GKColors.coral.withOpacity(0.26),
        GKColors.amber.withOpacity(0.12),
        GKColors.surface,
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PulseScale(
                minScale: 0.94,
                maxScale: 1.08,
                period: const Duration(milliseconds: 1100),
                child: WiggleIcon(
                  angle: 0.18,
                  period: const Duration(milliseconds: 700),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: GKColors.streakGradient),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: GKColors.coral.withOpacity(0.55), blurRadius: 16, spreadRadius: 1),
                      ],
                    ),
                    child: const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 26),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current Streak', style: TextStyle(color: GKColors.textSecondary, fontSize: 12)),
                    CountUpText(
                      value: currentStreak,
                      suffix: ' Days',
                      style: const TextStyle(
                          color: GKColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 38, color: Colors.white.withOpacity(0.1)),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Longest', style: TextStyle(color: GKColors.textSecondary, fontSize: 12)),
                  Text('$longestStreak Days',
                      style: const TextStyle(color: GKColors.amber, fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (loggedInToday ? GKColors.green : GKColors.textSecondary).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  loggedInToday ? Icons.check_circle_rounded : Icons.access_time_rounded,
                  size: 16,
                  color: loggedInToday ? GKColors.green : GKColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loggedInToday
                        ? "Today's streak is secured"
                        : 'Log some activity today to extend your streak',
                    style: TextStyle(
                      color: loggedInToday ? GKColors.green : GKColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Premium overview stat card: bigger icon, gradient accent,
//    hover elevation, count-up animation ─────────────────────────
class OverviewStatCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final int value;
  final int? outOf;
  final Color color;

  const OverviewStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.outOf,
    required this.color,
  });

  @override
  State<OverviewStatCard> createState() => _OverviewStatCardState();
}

class _OverviewStatCardState extends State<OverviewStatCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0),
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          gradientColors: [widget.color.withOpacity(_hover ? 0.30 : 0.18), GKColors.surface],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _hover
                      ? [BoxShadow(color: widget.color.withOpacity(0.4), blurRadius: 14)]
                      : const [],
                ),
                child: Icon(widget.icon, color: widget.color, size: 26),
              ),
              const SizedBox(height: 12),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: widget.value),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) {
                  final text = widget.outOf != null ? '$v/${widget.outOf}' : '$v';
                  return Text(
                    text,
                    style: const TextStyle(color: GKColors.textPrimary, fontSize: 19, fontWeight: FontWeight.w800),
                  );
                },
              ),
              const SizedBox(height: 2),
              Text(
                widget.label,
                style: const TextStyle(color: GKColors.textSecondary, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Premium mission card: progress bar + %, XP badge, difficulty
//    badge ──────────────────────────────────────────────────────
class MissionCardPremium extends StatelessWidget {
  final Mission mission;
  const MissionCardPremium({super.key, required this.mission});

  @override
  Widget build(BuildContext context) {
    final done = mission.isCompleted;
    final diff = missionDifficultyOf(mission);
    final diffColor = missionDifficultyColor(diff);
    final diffLabel = missionDifficultyLabel(diff);
    final pct = (mission.progress * 100).round();

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      gradientColors: done ? [GKColors.green.withOpacity(0.22), GKColors.surface] : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? GKColors.green : Colors.transparent,
                  border: Border.all(color: done ? GKColors.green : GKColors.textSecondary, width: 2),
                  boxShadow: done
                      ? [BoxShadow(color: GKColors.green.withOpacity(0.5), blurRadius: 10)]
                      : const [],
                ),
                child: done ? const Icon(Icons.check_rounded, size: 18, color: Colors.white) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  mission.title,
                  style: TextStyle(
                    color: GKColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: GKColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: diffColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(diffLabel, style: TextStyle(color: diffColor, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 7,
                    child: XPProgressBar(
                      progress: mission.progress,
                      height: 7,
                      colors: done ? [GKColors.green, GKColors.teal] : GKColors.xpGradient,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('$pct%', style: const TextStyle(color: GKColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('${mission.currentCount}/${mission.targetCount}',
                  style: const TextStyle(color: GKColors.textSecondary, fontSize: 11)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: GKColors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('+${mission.xpReward} XP',
                    style: const TextStyle(color: GKColors.amber, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Top Performers (Gold / Silver / Bronze podium cards) ─────────
class TopPerformersSection extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  const TopPerformersSection({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final top = entries.take(3).toList();
    if (top.isEmpty) {
      return const GKEmptyHint(text: 'No performers yet — be the first to top the board 🏆');
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 520;
        final cards = List.generate(top.length, (i) => _PerformerCard(rank: i + 1, entry: top[i]));
        if (narrow) {
          return Column(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                cards[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: cards[i]),
            ],
          ],
        );
      },
    );
  }
}

class _PerformerCard extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;
  const _PerformerCard({required this.rank, required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = rank == 1
        ? GKColors.amber
        : (rank == 2 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32));
    final medal = rank == 1 ? '🥇' : (rank == 2 ? '🥈' : '🥉');

    return GlassCard(
      gradientColors: [color.withOpacity(0.28), GKColors.surface],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(medal, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 8),
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [color, color.withOpacity(0.6)]),
              boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 14)],
            ),
            child: Text(
              initialsOf(entry.name),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            entry.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: GKColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text('Lvl ${entry.level}', style: const TextStyle(color: GKColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 4),
          Text('${entry.totalXP} XP', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// ── Recent rewards timeline tile ──────────────────────────────────
class RewardTimelineTile extends StatelessWidget {
  final RewardLogEntry entry;
  final bool isLast;
  const RewardTimelineTile({super.key, required this.entry, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: GKColors.teal.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: GKColors.teal.withOpacity(0.4)),
                ),
                child: Icon(iconForKey(entry.iconKey), color: GKColors.teal, size: 16),
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: Colors.white.withOpacity(0.08))),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.title,
                            style: const TextStyle(color: GKColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                        if (entry.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(entry.description,
                                style: const TextStyle(color: GKColors.textSecondary, fontSize: 11)),
                          ),
                        const SizedBox(height: 4),
                        Text(timeAgoLabel(entry.createdAt),
                            style: const TextStyle(color: GKColors.textSecondary, fontSize: 10)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: GKColors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text('+${entry.xp} XP',
                        style: const TextStyle(color: GKColors.amber, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Large premium navigation card (Leaderboard / Achievements /
//    Monthly Badges) with hover elevation + animated icon ─────────
class NavCardLarge extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const NavCardLarge({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  State<NavCardLarge> createState() => _NavCardLargeState();
}

class _NavCardLargeState extends State<NavCardLarge> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: BounceTap(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hover ? -5 : 0, 0),
          child: GlassCard(
            padding: const EdgeInsets.all(18),
            gradientColors: [
              widget.gradientColors.first.withOpacity(_hover ? 0.42 : 0.28),
              widget.gradientColors.last.withOpacity(0.14),
            ],
            child: Row(
              children: [
                FloatBob(
                  distance: 4,
                  period: const Duration(milliseconds: 1800),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: widget.gradientColors),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: widget.gradientColors.first.withOpacity(0.5), blurRadius: 16),
                      ],
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 26),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.label,
                          style: const TextStyle(
                              color: GKColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(widget.subtitle, style: const TextStyle(color: GKColors.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: GKColors.textSecondary.withOpacity(0.6), size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Badge showcase strip: reuses AchievementBadge (unchanged) for
//    earned + locked badges, with a progress bar for locked ones
//    where progress can be derived from data already on the profile.
class BadgeShowcase extends StatelessWidget {
  final GamificationProfile profile;
  final List<AchievementDef> catalog;

  const BadgeShowcase({super.key, required this.profile, required this.catalog});

  double? _progressFor(AchievementDef def) {
    switch (def.id) {
      case 'consistency_king':
        return (profile.currentStreak / 7).clamp(0.0, 1.0);
      case 'cda_legend':
        return (profile.currentStreak / 30).clamp(0.0, 1.0);
      case 'inventory_hero':
        return (profile.level / 10).clamp(0.0, 1.0);
      case 'stock_master':
        return (profile.stockUpdates / 50).clamp(0.0, 1.0);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlockedCount = profile.achievementIds.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$unlockedCount/${catalog.length} unlocked',
            style: const TextStyle(color: GKColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        SizedBox(
          // Tall enough for AchievementBadge's own content (icon +
          // up-to-2-line title + up-to-2-line description + its
          // internal padding) plus the progress-bar row below it —
          // sized generously so long titles like "Consistency King"
          // never get clipped.
          height: 232,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: catalog.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final def = catalog[i];
              final unlocked = profile.achievementIds.contains(def.id);
              final progress = unlocked ? null : _progressFor(def);
              return SizedBox(
                width: 150,
                child: Column(
                  children: [
                    Expanded(child: AchievementBadge(def: def, unlocked: unlocked)),
                    const SizedBox(height: 6),
                    // Reserve the same vertical space whether or not a
                    // badge has a computable progress bar, so every
                    // card in the row lines up at the same height.
                    SizedBox(
                      height: 5,
                      child: progress != null
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: XPProgressBar(progress: progress, height: 5),
                      )
                          : null,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}