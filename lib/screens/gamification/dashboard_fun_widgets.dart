// lib/screens/gamification/dashboard_fun_widgets.dart
//
// Purely decorative, animated "fun theme" pieces used ONLY by the
// Staff Rewards dashboard (gamification_dashboard.dart).
//
// IMPORTANT: nothing here touches reward_widgets.dart's GlassCard,
// FadeScaleIn, MissionTile, RewardActivityTile, or GKSectionHeader —
// those are shared with the Achievements / Missions / Leaderboard /
// Monthly Badges screens and must keep their current look everywhere
// else. Everything in this file is new and additive.

import 'dart:math';
import 'package:flutter/material.dart';

// ── Floating party emoji drifting up the background ──────────────
// A lightweight, purely decorative layer of emoji slowly floating
// upward and looping, like a subtle party atmosphere behind the real
// content. Wrapped in IgnorePointer so it never intercepts taps or
// scroll gestures.
class ConfettiDrift extends StatefulWidget {
  const ConfettiDrift({super.key});

  @override
  State<ConfettiDrift> createState() => _ConfettiDriftState();
}

class _ConfettiDriftState extends State<ConfettiDrift>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  static const _emojis = ['🎉', '⭐', '✨', '🔥', '🚀', '🏆', '💫', '🎯'];
  final List<_ConfettiSpec> _specs = List.generate(12, (i) {
    final rnd = Random(i * 97 + 13);
    return _ConfettiSpec(
      left: rnd.nextDouble(),
      size: 14 + rnd.nextDouble() * 14,
      phase: rnd.nextDouble(),
      speed: 0.6 + rnd.nextDouble() * 0.7,
      swayAmount: 10 + rnd.nextDouble() * 18,
      emoji: _emojis[i % _emojis.length],
    );
  });

  @override
  void initState() {
    super.initState();
    _controller =
    AnimationController(vsync: this, duration: const Duration(seconds: 20))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: _specs
                      .map((s) => s.build(_controller.value, constraints))
                      .toList(),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ConfettiSpec {
  final double left; // 0..1 fraction of width
  final double size;
  final double phase; // 0..1 start offset so pieces don't sync up
  final double speed; // loops per full controller cycle
  final double swayAmount;
  final String emoji;

  _ConfettiSpec({
    required this.left,
    required this.size,
    required this.phase,
    required this.speed,
    required this.swayAmount,
    required this.emoji,
  });

  Widget build(double t, BoxConstraints constraints) {
    final loopT = ((t * speed) + phase) % 1.0;
    // Drift from just below the bottom edge to just above the top edge.
    final y = constraints.maxHeight * (1 - loopT) - 20;
    final sway = sin(loopT * 2 * pi * 2) * swayAmount;
    final x = constraints.maxWidth * left + sway;
    // Fade in near the bottom, fade out near the top.
    final opacity = (sin(loopT * pi)).clamp(0.0, 1.0) * 0.35;

    return Positioned(
      left: x.clamp(0.0, constraints.maxWidth - size),
      top: y,
      child: Opacity(
        opacity: opacity,
        child: Text(emoji, style: TextStyle(fontSize: size)),
      ),
    );
  }
}

// ── Gentle continuous wiggle (rotation) wrapper ───────────────────
// Wrap any icon/emoji in this to make it feel alive — e.g. a flame
// that flickers or a trophy that jiggles.
class WiggleIcon extends StatefulWidget {
  final Widget child;
  final double angle; // max rotation, radians
  final Duration period;

  const WiggleIcon({
    super.key,
    required this.child,
    this.angle = 0.12,
    this.period = const Duration(milliseconds: 1400),
  });

  @override
  State<WiggleIcon> createState() => _WiggleIconState();
}

class _WiggleIconState extends State<WiggleIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period)
      ..repeat(reverse: true);
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
        final t = Curves.easeInOut.transform(_controller.value);
        final angle = (t - 0.5) * 2 * widget.angle;
        return Transform.rotate(angle: angle, child: child);
      },
      child: widget.child,
    );
  }
}

// ── Slow "breathing" scale pulse ──────────────────────────────────
// Wrap a card/icon in this for a subtle alive/glowing feel without
// changing its layout footprint.
class PulseScale extends StatefulWidget {
  final Widget child;
  final double minScale;
  final double maxScale;
  final Duration period;

  const PulseScale({
    super.key,
    required this.child,
    this.minScale = 0.95,
    this.maxScale = 1.05,
    this.period = const Duration(milliseconds: 1200),
  });

  @override
  State<PulseScale> createState() => _PulseScaleState();
}

class _PulseScaleState extends State<PulseScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period)
      ..repeat(reverse: true);
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
        final t = Curves.easeInOut.transform(_controller.value);
        final scale = widget.minScale + (widget.maxScale - widget.minScale) * t;
        return Transform.scale(scale: scale, child: child);
      },
      child: widget.child,
    );
  }
}

// ── Gentle up/down float, for a bobbing mascot emoji ──────────────
class FloatBob extends StatefulWidget {
  final Widget child;
  final double distance;
  final Duration period;

  const FloatBob({
    super.key,
    required this.child,
    this.distance = 6,
    this.period = const Duration(milliseconds: 1600),
  });

  @override
  State<FloatBob> createState() => _FloatBobState();
}

class _FloatBobState extends State<FloatBob> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period)
      ..repeat(reverse: true);
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
        final dy = -widget.distance * Curves.easeInOut.transform(_controller.value);
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: widget.child,
    );
  }
}

// ── Bouncy scale-down-on-tap wrapper ──────────────────────────────
// Gives any tappable card a playful little "squish" instead of a
// plain InkWell ripple.
class BounceTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const BounceTap({super.key, required this.child, this.onTap});

  @override
  State<BounceTap> createState() => _BounceTapState();
}

class _BounceTapState extends State<BounceTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      lowerBound: 0.0,
      upperBound: 0.08,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) =>
            Transform.scale(scale: 1 - _controller.value, child: child),
        child: widget.child,
      ),
    );
  }
}

// ── Funny, rotating "welcome back" one-liners ─────────────────────
// Picked deterministically from the day of the month, so it stays
// stable for the whole day instead of changing on every rebuild.
const List<String> funnyGreetings = [
  "Look who's back to hoard some XP 👀",
  "Ready to out-hustle a spreadsheet? 📊",
  "Inventory doesn't stack itself, champ 💪",
  "Another day, another chance to flex that streak 🔥",
  "Let's turn boxes into bragging rights 📦✨",
  "Warning: excessive XP gains ahead 🚀",
  "Your drones called — they miss you 🛸",
  "Plot twist: you're the main character today 🎬",
  "Time to make the leaderboard nervous 😎",
  "Sneaking in some XP before anyone notices? 🤫",
];

String pickFunnyGreeting() {
  final idx = DateTime.now().day % funnyGreetings.length;
  return funnyGreetings[idx];
}