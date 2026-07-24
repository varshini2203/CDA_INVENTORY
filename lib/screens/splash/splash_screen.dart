import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'package:cda_inventory/services/auth_service.dart';
import 'package:cda_inventory/services/access_control_service.dart';
import 'package:cda_inventory/core/access/access_scope.dart';

/// ═══════════════════════════════════════════════════════════════════════
///  SPLASH SCREEN
///  Background: assets/images/splash.png (full artwork — drone, skyline,
///  CDA logo, wordmark & feature icons already baked into the image).
///
///  Added on top of the artwork:
///    • Ken-Burns slow zoom + fade-in entrance for the artwork
///    • Twinkling star / particle overlay drifting over the sky
///    • Soft vignette + bottom scrim so the loading UI stays readable
///    • Small radar-style scanner loading indicator, sized and positioned
///      to sit in the clear strip below the artwork's feature-icon row
///      rather than overlapping it.
/// ═══════════════════════════════════════════════════════════════════════
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Artwork entrance (fade + Ken-Burns zoom)
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _zoomAnimation;

  // Twinkling particle field over the sky
  late AnimationController _starsController;
  late final List<_Star> _stars;

  // Radar sweep rotation
  late AnimationController _sweepController;

  // Radar expanding "ping" rings
  late AnimationController _pingController;

  // Overall load progress (drives status label + % readout)
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();

    // Artwork fade + slow zoom (Ken-Burns effect)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..forward();
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeIn),
      ),
    );
    _zoomAnimation = Tween<double>(begin: 1.06, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );

    // Star field
    _starsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _stars = List.generate(36, (i) => _Star.random(math.Random(i * 97)));

    // Radar sweep — one full rotation every 2.2s
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    // Expanding ping ring every 1.6s
    _pingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    // Progress readout over ~2.8s, then holds at 100%
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _progressController.forward();
    });

    _checkLogin();
  }

  Future<void> _checkLogin() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      // Single users/{uid} read shared by role detection AND onUserLoggedIn()
      // below (previously getRole() read the doc, then onUserLoggedIn() read
      // the exact same doc again a moment later).
      final roleInfo = await AuthService.getCurrentUserRoleAndProfile();
      final role = roleInfo['role'] as String;
      final access = await AccessControlService.onUserLoggedIn(
        uid: user.uid,
        name: user.displayName?.isNotEmpty == true ? user.displayName! : (user.email ?? ''),
        email: user.email ?? '',
        role: role,
        existingData: roleInfo['docData'] as Map<String, dynamic>?,
        existingDataFound: roleInfo['docExists'] as bool?,
      );

      if (!mounted) return;
      context.read<CurrentAccess>().listenTo(user.uid);

      if (access.isAdmin || access.canView) {
        Navigator.pushReplacementNamed(context, '/dashboard', arguments: role);
      } else {
        Navigator.pushReplacementNamed(context, '/waiting-approval');
      }
    } on AccountRemovedException {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } catch (_) {
      // Any unexpected error resolving access — safest fallback is to
      // send them back through login rather than silently into the app.
      await AuthService.logout();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _starsController.dispose();
    _sweepController.dispose();
    _pingController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0D47A1),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Splash artwork — Ken-Burns zoom + fade-in ──────────────
          AnimatedBuilder(
            animation: _entranceController,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: _zoomAnimation.value,
                  child: child,
                ),
              );
            },
            child: Image.asset(
              'assets/images/splash.png',
              // splash.png is a tall portrait image (~0.47 width/height —
              // very close to a real phone screen's own ratio). On phone-
              // shaped screens we fill edge-to-edge with `cover` since the
              // crop is negligible there. Only on much wider windows
              // (desktop browser, tablet landscape) do we switch to
              // `contain`, where `cover` would otherwise chop off the top
              // and bottom of the artwork.
              fit: (size.width / size.height) < 0.85
                  ? BoxFit.cover
                  : BoxFit.contain,
              alignment: Alignment.center,
              width: size.width,
              height: size.height,
              errorBuilder: (context, error, stackTrace) {
                // Fallback so the app never crashes if the asset is missing
                return Container(
                  color: const Color(0xFF0D47A1),
                  alignment: Alignment.center,
                  child: const Icon(Icons.flight_takeoff,
                      size: 90, color: Colors.white70),
                );
              },
            ),
          ),

          // ── 2. Twinkling star / particle field over the sky ───────────
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _starsController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _StarFieldPainter(
                    stars: _stars,
                    time: _starsController.value,
                  ),
                );
              },
            ),
          ),

          // ── 3. Bottom scrim — kept thin so it only shades the very
          // bottom strip (behind the loading indicator) instead of
          // washing out the artwork's own feature-icon row above it. ────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: size.height * 0.09,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF061024).withOpacity(0.0),
                      const Color(0xFF061024).withOpacity(0.75),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── 4. Radar-scanner loading indicator — small footprint,
          // pinned to the clear strip at the very bottom edge so it never
          // overlaps the artwork's baked-in feature-icon row above it. ──
          Positioned(
            left: 0,
            right: 0,
            bottom: size.height * 0.018,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: Listenable.merge(
                        [_sweepController, _pingController, _progressController]),
                    builder: (context, _) {
                      return SizedBox(
                        width: 30,
                        height: 30,
                        child: CustomPaint(
                          painter: _RadarPainter(
                            sweepAngle: _sweepController.value * 2 * math.pi,
                            pingProgress: _pingController.value,
                            lockedOn: _progressAnimation.value >= 1.0,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  AnimatedBuilder(
                    animation: _progressController,
                    builder: (context, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _statusLabel(_progressAnimation.value),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 9.5,
                              letterSpacing: 1.3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${(_progressAnimation.value * 100).toInt()}%',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 9,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(double progress) {
    if (progress < 0.25) return 'INITIALISING SYSTEMS';
    if (progress < 0.55) return 'SCANNING AIRSPACE';
    if (progress < 0.85) return 'PRE-FLIGHT READY';
    return 'CLEARED FOR TAKEOFF';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  RADAR PAINTER
//  A circular scanner: grid rings, rotating sweep beam, expanding ping
//  ring, and a locked-on blip once loading completes.
// ═══════════════════════════════════════════════════════════════════════════
class _RadarPainter extends CustomPainter {
  final double sweepAngle;   // 0 → 2π, current rotation of the sweep beam
  final double pingProgress; // 0 → 1, expanding ring cycle
  final bool lockedOn;

  const _RadarPainter({
    required this.sweepAngle,
    required this.pingProgress,
    required this.lockedOn,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    // ── Scope background ───────────────────────────────────────────────
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFF0E2138), const Color(0xFF060E1C)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // ── Grid rings ──────────────────────────────────────────────────────
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF00E676).withOpacity(0.16);
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, radius * i / 3, gridPaint);
    }

    // ── Crosshair ───────────────────────────────────────────────────────
    canvas.drawLine(center - Offset(radius, 0), center + Offset(radius, 0), gridPaint);
    canvas.drawLine(center - Offset(0, radius), center + Offset(0, radius), gridPaint);

    // ── Rotating sweep beam ─────────────────────────────────────────────
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));
    canvas.translate(center.dx, center.dy);
    canvas.rotate(sweepAngle);
    final sweepRect = Rect.fromCircle(center: Offset.zero, radius: radius);
    canvas.drawArc(
      sweepRect,
      0,
      math.pi / 2.4,
      true,
      Paint()
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: math.pi / 2.4,
          colors: [
            const Color(0xFF00E676).withOpacity(0.55),
            const Color(0xFF00E676).withOpacity(0.0),
          ],
        ).createShader(sweepRect),
    );
    canvas.restore();

    // ── Expanding ping ring ─────────────────────────────────────────────
    final pingRadius = radius * pingProgress;
    canvas.drawCircle(
      center,
      pingRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF00E676).withOpacity((1 - pingProgress) * 0.8),
    );

    // ── Outer bezel ─────────────────────────────────────────────────────
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withOpacity(0.18),
    );

    // ── Centre blip (drone) — pulses green once "locked on" ────────────
    final blipColor = lockedOn
        ? const Color(0xFF00E676)
        : Color.lerp(const Color(0xFFFFB300), const Color(0xFF00E676),
        (math.sin(sweepAngle) + 1) / 2)!;
    canvas.drawCircle(center, 4, Paint()..color = blipColor);
    canvas.drawCircle(
      center,
      8,
      Paint()
        ..color = blipColor.withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      old.sweepAngle != sweepAngle ||
          old.pingProgress != pingProgress ||
          old.lockedOn != lockedOn;
}

// ═══════════════════════════════════════════════════════════════════════════
//  STAR FIELD PAINTER — subtle twinkling particles drifting over the sky
// ═══════════════════════════════════════════════════════════════════════════
class _Star {
  final double x;      // 0..1 relative position
  final double y;       // 0..1 relative position (kept in upper 60% of screen)
  final double size;
  final double phase;   // twinkle phase offset
  final double speed;   // twinkle speed multiplier

  _Star(this.x, this.y, this.size, this.phase, this.speed);

  factory _Star.random(math.Random r) {
    return _Star(
      r.nextDouble(),
      r.nextDouble() * 0.6,
      0.8 + r.nextDouble() * 1.6,
      r.nextDouble() * 2 * math.pi,
      0.6 + r.nextDouble() * 0.8,
    );
  }
}

class _StarFieldPainter extends CustomPainter {
  final List<_Star> stars;
  final double time; // 0..1 looping

  _StarFieldPainter({required this.stars, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final t = time * 2 * math.pi;
    for (final star in stars) {
      final twinkle = (math.sin(t * star.speed + star.phase) + 1) / 2;
      final opacity = 0.15 + twinkle * 0.55;
      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.size,
        Paint()..color = Colors.white.withOpacity(opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter old) => old.time != time;
}