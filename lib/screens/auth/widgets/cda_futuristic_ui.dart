// lib/screens/auth/widgets/cda_futuristic_ui.dart
//
// Shared futuristic / glassmorphism building blocks used by the CDA
// auth screens (Login & Register): a cinematic sunset-sky + drone
// background, a frosted-glass card, a glowing neon button and a
// small telemetry ("READY TO FLY") HUD widget.
//
// Everything here is pure Flutter (gradients, CustomPainter, blur) —
// no network images required — so it works completely offline.

import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

// ── CDA Futuristic palette ─────────────────────────────────────────
class CdaColors {
  CdaColors._();
  static const darkNavy = Color(0xFF071827);
  static const deepSpace = Color(0xFF040D16);
  static const electricBlue = Color(0xFF00AEEF);
  static const cyanGlow = Color(0xFF4DE8FF);
  static const sunsetOrange = Color(0xFFFF8A4C);
  static const sunsetPink = Color(0xFFFF5F7E);
  static const glassFill = Color(0x1AFFFFFF); // white @ 10%
  static const glassBorder = Color(0x4D00AEEF); // electricBlue @ 30%
}

// ═════════════════════════════════════════════════════════════════
// BACKGROUND — real CDA cinematic photo (assets/images/cda_background.png)
// with a readability scrim + a light HUD-particle shimmer on top.
// ═════════════════════════════════════════════════════════════════
class FuturisticDroneBackground extends StatefulWidget {
  final Widget child;
  const FuturisticDroneBackground({super.key, required this.child});

  @override
  State<FuturisticDroneBackground> createState() =>
      _FuturisticDroneBackgroundState();
}

class _FuturisticDroneBackgroundState extends State<FuturisticDroneBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // cda_background.png is a landscape photo (1536×1024, ratio 1.5).
        // `cover` looks right on essentially every phone/tablet ratio —
        // it only crops the sides, never the subject. The one case where
        // `cover` would look wrong is a screen *narrower* than the photo
        // itself (very unusual — e.g. a squeezed multi-window/split-screen
        // pane), so we fall back to `contain` there instead of over-cropping.
        final aspect = constraints.maxWidth / constraints.maxHeight;
        final fit = aspect < 0.4 ? BoxFit.contain : BoxFit.cover;
        return Stack(
          fit: StackFit.expand,
          children: [
            // ── The real CDA background photo ─────────────────────
            Image.asset(
              'assets/images/cda_background.png',
              fit: fit,
              errorBuilder: (context, error, stack) => const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      CdaColors.deepSpace,
                      Color(0xFF0B2338),
                      CdaColors.darkNavy,
                    ],
                  ),
                ),
              ),
            ),
            // ── Dark scrim so foreground text/cards stay readable ──
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x99020608),
                    Color(0x33020608),
                    Color(0x99020608),
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
            // ── Subtle animated HUD particle shimmer on top of photo ──
            AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) => CustomPaint(
                painter: _ParticlePainter(_ctrl.value),
                child: const SizedBox.expand(),
              ),
            ),
            widget.child,
          ],
        );
      },
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double t;
  _ParticlePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(42);
    for (int i = 0; i < 34; i++) {
      final dx = rnd.nextDouble() * size.width;
      final baseDy = rnd.nextDouble() * size.height;
      final dy = (baseDy - (t * 60)) % size.height;
      final twinkle = (sin((t * 2 * pi) + i) + 1) / 2;
      final r = 0.6 + rnd.nextDouble() * 1.6;
      canvas.drawCircle(
        Offset(dx, dy),
        r,
        Paint()
          ..color = CdaColors.cyanGlow.withOpacity(0.15 + twinkle * 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}

// ═════════════════════════════════════════════════════════════════
// GLASS CARD — frosted glassmorphism container, 25px radius.
// Auto-constrained to a compact, centered width so it never
// stretches edge-to-edge on wide/desktop/web screens.
// ═════════════════════════════════════════════════════════════════
class CdaGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double maxWidth;
  const CdaGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.maxWidth = 420,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    CdaColors.electricBlue.withOpacity(0.28),
                    const Color(0xFF071A33).withOpacity(0.88),
                    const Color(0xFF04101F).withOpacity(0.94),
                  ],
                ),
                border: Border.all(
                  color: CdaColors.cyanGlow.withOpacity(0.55),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: CdaColors.electricBlue.withOpacity(0.35),
                    blurRadius: 40,
                    spreadRadius: 1,
                    offset: const Offset(0, 14),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 26,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// NEON BUTTON — glowing electric-blue call-to-action button
// ═════════════════════════════════════════════════════════════════
class CdaNeonButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback? onPressed;

  const CdaNeonButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [CdaColors.electricBlue, Color(0xFF0080C4)],
          ),
          boxShadow: [
            BoxShadow(
              color: CdaColors.electricBlue.withOpacity(0.55),
              blurRadius: 20,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: Center(
              child: loading
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// BRAND HEADER — logo chip + wordmark + LEARN | INNOVATE | FLY motto
// ═════════════════════════════════════════════════════════════════
class CdaBrandHeader extends StatelessWidget {
  final double logoSize;
  const CdaBrandHeader({super.key, this.logoSize = 74});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: CdaColors.electricBlue.withOpacity(0.45),
                blurRadius: 22,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              'assets/images/logo.png',
              height: logoSize,
              width: logoSize,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.flight_takeoff_rounded,
                color: CdaColors.electricBlue,
                size: logoSize * 0.6,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'CHENNAI ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              TextSpan(
                text: 'DRONE',
                style: TextStyle(
                  color: CdaColors.electricBlue,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        const Text(
          'ACADEMY',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 8),
        _MottoRow(),
      ],
    );
  }
}

class _MottoRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: CdaColors.cyanGlow,
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 2,
    );
    Widget dot() => Container(
      width: 3,
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: CdaColors.electricBlue,
        shape: BoxShape.circle,
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('LEARN', style: style),
        dot(),
        const Text('INNOVATE', style: style),
        dot(),
        const Text('FLY', style: style),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// TELEMETRY HUD — small "READY TO FLY" widget for footer decoration
// ═════════════════════════════════════════════════════════════════
class CdaTelemetryStrip extends StatelessWidget {
  const CdaTelemetryStrip({super.key});

  @override
  Widget build(BuildContext context) {
    Widget stat(String label, String value) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 9,
                  letterSpacing: 0.6)),
          Text(value,
              style: const TextStyle(
                  color: CdaColors.cyanGlow,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withOpacity(0.05),
            border: Border.all(color: CdaColors.glassBorder, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.radar_rounded,
                  color: CdaColors.electricBlue, size: 22),
              const SizedBox(width: 10),
              stat('ALT', '120m'),
              const SizedBox(width: 14),
              stat('SPD', '45km/h'),
              const SizedBox(width: 14),
              stat('BAT', '92%'),
              const SizedBox(width: 14),
              stat('GPS', 'LOCK'),
            ],
          ),
        ),
      ),
    );
  }
}