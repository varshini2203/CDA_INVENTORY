// lib/screens/gamification/reward_widgets.dart
//
// Shared, reusable UI pieces for the gamification module. Design
// tokens match the rest of CDA Inventory (see inventory_dashboard.dart
// / dashboard_screen.dart): dark navy background, teal/amber/purple
// accents, rounded cards, soft shadows.

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/gamification_models.dart';

// ── Design tokens ────────────────────────────────────────────────
class GKColors {
  static const Color navy = Color(0xFF0A1628);
  static const Color navyDeep = Color(0xFF050A14);
  static const Color surface = Color(0xFF101E36);
  static const Color surfaceHigh = Color(0xFF16274A);
  static const Color teal = Color(0xFF00D4AA);
  static const Color coral = Color(0xFFFF6B6B);
  static const Color amber = Color(0xFFFFB800);
  static const Color green = Color(0xFF00B894);
  static const Color purple = Color(0xFF6C63FF);
  static const Color textPrimary = Color(0xFFF3F6FB);
  static const Color textSecondary = Color(0xFF93A4C3);
  static const Color locked = Color(0xFF4B5A75);

  static const List<Color> xpGradient = [Color(0xFF1E5FC8), Color(0xFF00D4AA)];
  static const List<Color> streakGradient = [Color(0xFFFF6B6B), Color(0xFFFFB800)];
  static const List<Color> purpleGradient = [Color(0xFF6C63FF), Color(0xFF1E5FC8)];
}

IconData iconForKey(String key) {
  switch (key) {
    case 'seedling':
      return Icons.eco_rounded;
    case 'inventory':
      return Icons.inventory_2_rounded;
    case 'flight':
      return Icons.flight_takeoff_rounded;
    case 'target':
      return Icons.track_changes_rounded;
    case 'flame':
      return Icons.local_fire_department_rounded;
    case 'shield':
      return Icons.shield_rounded;
    case 'crown':
      return Icons.emoji_events_rounded;
    case 'add_box':
      return Icons.add_box_rounded;
    case 'receipt':
      return Icons.receipt_long_rounded;
    case 'check_circle':
      return Icons.check_circle_rounded;
    case 'task':
      return Icons.task_alt_rounded;
    case 'star':
    default:
      return Icons.star_rounded;
  }
}

Color tierColor(int tier) {
  switch (tier) {
    case 1:
      return const Color(0xFFCD7F32); // bronze
    case 2:
      return const Color(0xFFC0C0C0); // silver
    case 3:
      return GKColors.amber; // gold
    case 4:
      return GKColors.purple; // legendary
    default:
      return GKColors.teal;
  }
}

// ── Glass-morphism card wrapper ─────────────────────────────────
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final List<Color>? gradientColors;
  final double borderRadius;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.gradientColors,
    this.borderRadius = 20,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: gradientColors != null
                ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors!,
            )
                : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                GKColors.surfaceHigh.withOpacity(0.9),
                GKColors.surface.withOpacity(0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(borderRadius),
      child: card,
    );
  }
}

// ── Fade + scale entrance animation wrapper ──────────────────────
class FadeScaleIn extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const FadeScaleIn({super.key, required this.child, this.delayMs = 0});

  @override
  State<FadeScaleIn> createState() => _FadeScaleInState();
}

class _FadeScaleInState extends State<FadeScaleIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.92, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fade.value,
          child: Transform.scale(scale: _scale.value, child: child),
        );
      },
      child: widget.child,
    );
  }
}

// ── Animated XP progress bar ─────────────────────────────────────
class XPProgressBar extends StatelessWidget {
  final double progress; // 0..1
  final double height;
  final List<Color>? colors;

  const XPProgressBar({super.key, required this.progress, this.height = 14, this.colors});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: Colors.white.withOpacity(0.08),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return Container(
                      width: constraints.maxWidth * value,
                      height: height,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(height),
                        gradient: LinearGradient(colors: colors ?? GKColors.xpGradient),
                        boxShadow: [
                          BoxShadow(
                            color: (colors ?? GKColors.xpGradient).last.withOpacity(0.55),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── XP CARD ────────────────────────────────────────────────────
class XPCard extends StatelessWidget {
  final int level;
  final int totalXP;
  final double progress;
  final int xpToNext;

  const XPCard({
    super.key,
    required this.level,
    required this.totalXP,
    required this.progress,
    required this.xpToNext,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      gradientColors: [GKColors.surfaceHigh, GKColors.navy],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: GKColors.xpGradient),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: GKColors.teal.withOpacity(0.4), blurRadius: 12)],
                ),
                child: const Icon(Icons.star_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Text('Level $level',
                  style: const TextStyle(
                      color: GKColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('$totalXP XP',
                  style: const TextStyle(
                      color: GKColors.teal, fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          XPProgressBar(progress: progress),
          const SizedBox(height: 8),
          Text(
            xpToNext > 0 ? '$xpToNext XP to Level ${level + 1}' : 'Max level reached',
            style: const TextStyle(color: GKColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── STREAK CARD ────────────────────────────────────────────────
class StreakCard extends StatelessWidget {
  final int currentStreak;
  final int longestStreak;

  const StreakCard({super.key, required this.currentStreak, required this.longestStreak});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      gradientColors: [GKColors.coral.withOpacity(0.18), GKColors.surface],
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: GKColors.streakGradient),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: GKColors.coral.withOpacity(0.4), blurRadius: 12)],
            ),
            child: const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Current Streak',
                    style: TextStyle(color: GKColors.textSecondary, fontSize: 12)),
                Text('$currentStreak Days',
                    style: const TextStyle(
                        color: GKColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Container(width: 1, height: 34, color: Colors.white.withOpacity(0.1)),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Longest', style: TextStyle(color: GKColors.textSecondary, fontSize: 12)),
              Text('$longestStreak Days',
                  style: const TextStyle(
                      color: GKColors.amber, fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Small stat tile used on the dashboard grid / profile summary ─
class StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(value,
              style: const TextStyle(
                  color: GKColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: GKColors.textSecondary, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ── Mission tile (checkbox-style row with progress) ──────────────
class MissionTile extends StatelessWidget {
  final Mission mission;

  const MissionTile({super.key, required this.mission});

  @override
  Widget build(BuildContext context) {
    final done = mission.isCompleted;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      gradientColors: done
          ? [GKColors.green.withOpacity(0.22), GKColors.surface]
          : null,
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? GKColors.green : Colors.transparent,
              border: Border.all(color: done ? GKColors.green : GKColors.textSecondary, width: 2),
            ),
            child: done ? const Icon(Icons.check_rounded, size: 18, color: Colors.white) : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mission.title,
                  style: TextStyle(
                    color: done ? GKColors.textPrimary : GKColors.textPrimary.withOpacity(0.9),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: GKColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 6,
                    child: XPProgressBar(
                      progress: mission.progress,
                      height: 6,
                      colors: done ? [GKColors.green, GKColors.teal] : GKColors.xpGradient,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text('${mission.currentCount}/${mission.targetCount}',
                    style: const TextStyle(color: GKColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: GKColors.amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('+${mission.xpReward} XP',
                style: const TextStyle(
                    color: GKColors.amber, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Achievement badge card (glow when unlocked, greyed when locked) ─
class AchievementBadge extends StatefulWidget {
  final AchievementDef def;
  final bool unlocked;

  const AchievementBadge({super.key, required this.def, required this.unlocked});

  @override
  State<AchievementBadge> createState() => _AchievementBadgeState();
}

class _AchievementBadgeState extends State<AchievementBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.unlocked ? tierColor(widget.def.tier) : GKColors.locked;

    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glow = widget.unlocked ? (0.25 + 0.25 * _glowController.value) : 0.0;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: widget.unlocked
                ? [BoxShadow(color: color.withOpacity(glow), blurRadius: 22, spreadRadius: 1)]
                : [],
          ),
          child: child,
        );
      },
      child: Opacity(
        opacity: widget.unlocked ? 1.0 : 0.55,
        child: GlassCard(
          gradientColors: widget.unlocked
              ? [color.withOpacity(0.25), GKColors.surface]
              : [GKColors.surface, GKColors.surface],
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: widget.unlocked
                      ? LinearGradient(colors: [color, color.withOpacity(0.6)])
                      : null,
                  color: widget.unlocked ? null : GKColors.locked.withOpacity(0.25),
                  border: Border.all(
                      color: widget.unlocked ? color : GKColors.locked.withOpacity(0.5), width: 2),
                ),
                child: Icon(
                  widget.unlocked ? iconForKey(widget.def.iconKey) : Icons.lock_rounded,
                  color: widget.unlocked ? Colors.white : GKColors.textSecondary,
                  size: 26,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.def.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.unlocked ? GKColors.textPrimary : GKColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.def.description,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: GKColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Recent activity reward tile ───────────────────────────────────
class RewardActivityTile extends StatelessWidget {
  final RewardLogEntry entry;
  const RewardActivityTile({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: GKColors.teal.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(iconForKey(entry.iconKey), color: GKColors.teal, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title,
                    style: const TextStyle(
                        color: GKColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                if (entry.description.isNotEmpty)
                  Text(entry.description,
                      style: const TextStyle(color: GKColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Text('+${entry.xp} XP',
              style: const TextStyle(
                  color: GKColors.amber, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── Section header used across gamification screens ──────────────
class GKSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const GKSectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                  color: GKColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ── Responsive grid helper ────────────────────────────────────────
int gkGridColumns(double width) {
  if (width >= 1100) return 4;
  if (width >= 800) return 3;
  if (width >= 560) return 2;
  return 2;
}
