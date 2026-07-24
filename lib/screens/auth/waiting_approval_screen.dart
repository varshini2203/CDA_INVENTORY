// lib/screens/auth/waiting_approval_screen.dart
//
// Shown right after an employee logs in if the admin hasn't granted
// access yet. Listens to their own users/{uid} doc in real time, so the
// moment the admin approves (Viewer or Editor) this screen automatically
// moves them into the dashboard — no need to log in again.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/access/access_scope.dart';
import '../../models/app_access_models.dart';
import '../../services/auth_service.dart';

class WaitingApprovalScreen extends StatefulWidget {
  const WaitingApprovalScreen({super.key});

  @override
  State<WaitingApprovalScreen> createState() => _WaitingApprovalScreenState();
}

class _WaitingApprovalScreenState extends State<WaitingApprovalScreen>
    with TickerProviderStateMixin {
  // ── Palette — dark drone-HUD theme ─────────────────────────────────
  static const _bgFallback = Color(0xFF040B1A);
  static const _cyan = Color(0xFF35D6FF);
  static const _cyanDim = Color(0xFF6FA8C9);
  static const _panelFill = Color(0xCC061226);
  static const _panelBorder = Color(0x5535D6FF);
  static const _amber = Color(0xFFFFB020);
  static const _red = Color(0xFFFF5470);
  static const _white70 = Color(0xB3FFFFFF);

  // Grabbed ONCE in initState instead of inside build(). This screen used
  // to call FirebaseFirestore.instance.collection('users').doc(uid)
  // .snapshots() directly inside build() — that creates a brand-new Stream
  // object (and therefore a brand-new Firestore listener) on EVERY rebuild
  // of this widget, not just when the user's doc actually changes. Any
  // rebuild trigger (Provider notification, hot reload, parent state
  // change) reopened another live subscription to the same document,
  // silently multiplying reads for as long as an employee sat on this
  // "waiting for approval" screen. Caching the stream once fixes that.
  String? _uid;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _docStream;

  // Decorative animations only — none of these affect the real-time
  // approval logic below.
  late final AnimationController _pulseController; // hourglass badge pulse
  late final AnimationController _scanController; // HUD ring rotation

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    if (_uid != null) {
      _docStream =
          FirebaseFirestore.instance.collection('users').doc(_uid).snapshots();
    }
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    if (uid == null || _docStream == null) {
      return const Scaffold(
        backgroundColor: _bgFallback,
        body: Center(
          child: Text('Not logged in', style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _bgFallback,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background artwork — full-bleed, always covers the
          // screen ──────────────────────────────────────────────────
          //
          // waiting.png is a tall portrait piece. We previously switched
          // between BoxFit.cover (phones) and BoxFit.contain (wide
          // desktop/tablet-landscape windows) based on aspect ratio. The
          // `contain` branch was the bug: on any wide window it shrank
          // the image to fit the width and centered it, leaving visible
          // letterboxed dead space (the plain _bgFallback color showing
          // through) above and below the artwork instead of a full-bleed
          // background.
          //
          // Always using `cover` fills the screen edge-to-edge at any
          // aspect ratio. On wide windows this crops the top/bottom of
          // the image instead of the sides, so we anchor to topCenter to
          // keep the drone + logo artwork (which live in the upper part
          // of the image) in frame.
          Image.asset(
            'assets/images/waiting.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (context, error, stack) => const DecoratedBox(
              decoration: BoxDecoration(color: _bgFallback),
            ),
          ),
          // Readability scrim — darker toward the bottom where the
          // status cards sit, lighter up top so the drone stays visible.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66040B1A),
                  Color(0x33040B1A),
                  Color(0xE6040B1A),
                  Color(0xFA040B1A),
                ],
                stops: [0.0, 0.32, 0.62, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _docStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: _cyan),
                  );
                }

                // The admin removed this employee entirely while they
                // were waiting — sign them straight back out with a
                // clear reason instead of leaving them stuck on a
                // spinner forever.
                if (!snapshot.data!.exists) {
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    await AuthService.logout();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Your account has been removed by the admin. Contact them for access.')),
                    );
                    Navigator.pushNamedAndRemoveUntil(
                        context, '/login', (route) => false);
                  });
                  return const Center(
                    child: CircularProgressIndicator(color: _cyan),
                  );
                }

                final access = AppUserAccess.fromDoc(snapshot.data!);

                // The moment access is approved, hand off to the
                // dashboard.
                if (access.canView) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!context.mounted) return;
                    context.read<CurrentAccess>().listenTo(uid);
                    Navigator.pushReplacementNamed(context, '/dashboard',
                        arguments: access.role);
                  });
                }

                final denied = access.accessStatus == AccessStatus.rejected;
                final statusColor = denied ? _red : _amber;

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _Header(cyan: _cyan),
                        SizedBox(height: size.height * 0.28),

                        // ── HUD badge over the artwork ───────────────
                        _HudBadge(
                          pulse: _pulseController,
                          scan: _scanController,
                          denied: denied,
                          accent: statusColor,
                        ),
                        const SizedBox(height: 22),

                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: denied ? 'ACCESS ' : 'WAITING FOR ',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              TextSpan(
                                text: denied ? 'REJECTED' : 'APPROVAL',
                                style: TextStyle(
                                  color: denied ? _red : _cyan,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          denied
                              ? 'Your access request has been rejected. Please contact the administrator for help.'
                              : 'Your access request has been submitted successfully. '
                              'Please wait while the admin reviews your request.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _white70,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 22),

                        // ── Status / Requested On panel ──────────────
                        _HudPanel(
                          border: _panelBorder,
                          fill: _panelFill,
                          child: Row(
                            children: [
                              Expanded(
                                child: _HudStat(
                                  icon: Icons.access_time_rounded,
                                  iconColor: _cyan,
                                  label: 'STATUS',
                                  value: denied
                                      ? 'REJECTED'
                                      : 'PENDING APPROVAL',
                                  valueColor: statusColor,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: _panelBorder,
                              ),
                              Expanded(
                                child: _HudStat(
                                  icon: Icons.event_rounded,
                                  iconColor: _cyan,
                                  label: 'REQUESTED ON',
                                  value: _formatRequestedOn(access.createdAt),
                                  valueColor: Colors.white,
                                  alignEnd: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // ── What happens next panel ──────────────────
                        _HudPanel(
                          border: _panelBorder,
                          fill: _panelFill,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _cyan.withOpacity(0.12),
                                  border: Border.all(
                                      color: _cyan.withOpacity(0.5)),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  denied
                                      ? Icons.support_agent_rounded
                                      : Icons.notifications_active_rounded,
                                  color: _cyan,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'WHAT HAPPENS NEXT?',
                                      style: TextStyle(
                                        color: _cyan,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      denied
                                          ? 'Reach out to your admin if you believe this was a mistake — they can re-approve your access at any time.'
                                          : 'You\'ll be let in automatically as soon as the admin approves your request — no need to log in again.',
                                      style: const TextStyle(
                                        color: _white70,
                                        fontSize: 12.5,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),

                        SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await AuthService.logout();
                              if (!context.mounted) return;
                              Navigator.pushNamedAndRemoveUntil(
                                  context, '/login', (route) => false);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                  color: _cyan.withOpacity(0.45), width: 1.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.logout_rounded, size: 18),
                            label: const Text(
                              'Log out',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // ── Contact admin footer ─────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.headset_mic_rounded,
                                size: 16, color: _cyanDim),
                            const SizedBox(width: 6),
                            const Text(
                              'Need help? ',
                              style: TextStyle(color: _cyanDim, fontSize: 13),
                            ),
                            GestureDetector(
                              onTap: () => _showContactAdminSheet(context),
                              child: const Text(
                                'Contact Admin',
                                style: TextStyle(
                                  color: _cyan,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _formatRequestedOn(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat("d MMM yyyy • h:mm a").format(dt);
  }

  void _showContactAdminSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF07162E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: _panelBorder),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CONTACT ADMIN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Reach out if your request is taking longer than expected.',
                  style: TextStyle(color: _white70, fontSize: 12.5),
                ),
                const SizedBox(height: 18),
                const _ContactRow(
                  icon: Icons.email_rounded,
                  label: 'info@chennaidroneacademy.com',
                ),
                const SizedBox(height: 12),
                const _ContactRow(
                  icon: Icons.language_rounded,
                  label: 'www.chennaidroneacademy.com',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Header — CDA mark + wordmark + thin ornament line, over the artwork
// ═══════════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final Color cyan;
  const _Header({required this.cyan});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 32,
              width: 32,
              errorBuilder: (context, error, stack) => Icon(
                Icons.flight_takeoff_rounded,
                size: 28,
                color: cyan,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'CHENNAI DRONE ACADEMY',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'INVENTORY MANAGEMENT',
          style: TextStyle(
            color: cyan,
            fontSize: 10,
            letterSpacing: 2.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 60,
          height: 1.4,
          color: cyan.withOpacity(0.5),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  HUD badge — glowing ring + pulsing hourglass, sits over the artwork
//  where it meets the panels below (mirrors the mockup's center icon).
// ═══════════════════════════════════════════════════════════════════════
class _HudBadge extends StatelessWidget {
  final Animation<double> pulse;
  final Animation<double> scan;
  final bool denied;
  final Color accent;

  const _HudBadge({
    required this.pulse,
    required this.scan,
    required this.denied,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([pulse, scan]),
        builder: (context, _) {
          final ringScale = 1.0 + (pulse.value * 0.10);
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer rotating dashed ring
              Transform.rotate(
                angle: scan.value * 2 * 3.14159,
                child: CustomPaint(
                  size: const Size(96, 96),
                  painter: _DashedRingPainter(color: accent.withOpacity(0.5)),
                ),
              ),
              // Glow
              Transform.scale(
                scale: ringScale,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF07162E),
                    border: Border.all(color: accent, width: 1.6),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(0.55),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    denied ? Icons.block_rounded : Icons.hourglass_top_rounded,
                    color: accent,
                    size: 28,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  final Color color;
  const _DashedRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = Offset(radius, radius);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    const dashCount = 24;
    const gapFraction = 0.55; // fraction of each segment left empty
    for (int i = 0; i < dashCount; i++) {
      final startAngle = (i / dashCount) * 2 * 3.14159;
      final sweep = (2 * 3.14159 / dashCount) * (1 - gapFraction);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 1),
        startAngle,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter old) => old.color != color;
}

// ═══════════════════════════════════════════════════════════════════════
//  Glass HUD panel shell shared by the status + info cards
// ═══════════════════════════════════════════════════════════════════════
class _HudPanel extends StatelessWidget {
  final Widget child;
  final Color border;
  final Color fill;

  const _HudPanel({required this.child, required this.border, required this.fill});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 1.2),
      ),
      child: child,
    );
  }
}

class _HudStat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color valueColor;
  final bool alignEnd;

  const _HudStat({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final crossAlign =
    alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    final textCol = Column(
      crossAxisAlignment: crossAlign,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8FA9C9),
            fontSize: 10.5,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            color: valueColor,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );

    if (alignEnd) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(child: textCol),
          const SizedBox(width: 8),
          Icon(icon, color: iconColor, size: 16),
        ],
      );
    }

    return Row(
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 8),
        Expanded(child: textCol),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ContactRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF35D6FF).withOpacity(0.12),
            border: Border.all(color: const Color(0xFF35D6FF).withOpacity(0.4)),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: const Color(0xFF35D6FF)),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}