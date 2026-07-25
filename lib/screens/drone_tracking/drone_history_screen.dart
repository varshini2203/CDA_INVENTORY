// lib/screens/drone/drone_history_screen.dart
// Firestore version — theme matched to Invoice pages.

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../models/drone.dart';
import '../../services/drone_service.dart';

class DroneHistoryScreen extends StatefulWidget {
  final DroneService service;
  final Drone drone;
  const DroneHistoryScreen(
      {super.key, required this.service, required this.drone});

  @override
  State<DroneHistoryScreen> createState() => _DroneHistoryScreenState();
}

class _DroneHistoryScreenState extends State<DroneHistoryScreen>
    with SingleTickerProviderStateMixin {
  List<DroneHistory> _history = [];
  bool _loading = true;
  String? _error;
  late AnimationController _droneAnim;

  // ── Design tokens (matches Invoice pages) ──────────────────────────────────
  static const Color kNavy = Color(0xFF0A1628);
  static const Color kNavyLight = Color(0xFF162944);
  static const Color kTeal = Color(0xFF00D4AA);
  static const Color kCoral = Color(0xFFFF6B6B);
  static const Color kAmber = Color(0xFFFFB800);
  static const Color kSurface = Color(0xFFF0F4F8);
  static const Color kPurple = Color(0xFF6C63FF);

  @override
  void initState() {
    super.initState();
    _droneAnim = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))
      ..repeat();
    _loadHistory();
  }

  @override
  void dispose() {
    _droneAnim.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result =
    await widget.service.getHistory(widget.drone.id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.success) {
        _history = result.data!;
      } else {
        _error = result.error;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          _buildBody(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 150,
      pinned: true,
      backgroundColor: kNavy,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: _loadHistory,
          tooltip: 'Refresh',
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [kNavy, kNavyLight],
                ),
              ),
              child: CustomPaint(painter: _SubtleGridPainter()),
            ),
            // Animated trail dots
            AnimatedBuilder(
              animation: _droneAnim,
              builder: (_, __) => Stack(
                children: List.generate(5, (i) {
                  final t = (_droneAnim.value + i * 0.18) % 1.0;
                  final x =
                      0.55 + math.sin(t * 2 * math.pi + i) * 0.25;
                  final y = 0.5 +
                      math.cos(
                          t * 2 * math.pi * 0.5 + i * 0.8) *
                          0.35;
                  return Positioned(
                    right: MediaQuery.of(context).size.width * (1 - x),
                    top: 150 * y,
                    child: Opacity(
                      opacity: (1 - i * 0.18) * 0.2,
                      child: Container(
                        width: (5 - i * 0.8).clamp(1.5, 5.0),
                        height: (5 - i * 0.8).clamp(1.5, 5.0),
                        decoration: const BoxDecoration(
                          color: kPurple,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            AnimatedBuilder(
              animation: _droneAnim,
              builder: (_, __) {
                final t = _droneAnim.value;
                final x =
                    0.55 + math.sin(t * 2 * math.pi) * 0.25;
                final y =
                    0.5 + math.cos(t * 2 * math.pi * 0.5) * 0.35;
                return Positioned(
                  right:
                  MediaQuery.of(context).size.width * (1 - x),
                  top: 150 * y,
                  child: Opacity(
                    opacity: 0.3,
                    child: Transform.rotate(
                      angle: t * 2 * math.pi * 0.3,
                      child: const Icon(Icons.flight_rounded,
                          color: kPurple, size: 22),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              left: 20,
              bottom: 16,
              right: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: kPurple.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                              color: kPurple.withOpacity(0.35)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history,
                                color: kPurple, size: 12),
                            SizedBox(width: 5),
                            Text('FLIGHT LOG',
                                style: TextStyle(
                                    color: kPurple,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(widget.drone.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          color: Colors.white.withOpacity(0.5), size: 12),
                      const SizedBox(width: 4),
                      Text(widget.drone.model,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PulsingHistoryIcon(anim: _droneAnim),
              const SizedBox(height: 18),
              const Text('Loading flight log…',
                  style: TextStyle(
                      color: kPurple,
                      fontSize: 14,
                      letterSpacing: 0.5)),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: kCoral.withOpacity(0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: kCoral.withOpacity(0.25)),
                  ),
                  child: const Icon(Icons.error_outline,
                      color: kCoral, size: 40),
                ),
                const SizedBox(height: 18),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 14)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _loadHistory,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_history.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.grey.shade200, width: 2),
                ),
                child: Icon(Icons.history_toggle_off,
                    size: 52, color: Colors.grey.shade300),
              ),
              const SizedBox(height: 22),
              const Text('No flights recorded',
                  style: TextStyle(
                      color: kNavy,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'History will appear once ${widget.drone.name} is deployed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey.shade500, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (_, i) {
            if (i == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryBar(),
                  const SizedBox(height: 20),
                  _HistoryItem(
                      entry: _history[i],
                      isLast: i == _history.length - 1),
                ],
              );
            }
            return _HistoryItem(
                entry: _history[i],
                isLast: i == _history.length - 1);
          },
          childCount: _history.length,
        ),
      ),
    );
  }

  Widget _buildSummaryBar() {
    final inCount =
        _history.where((h) => h.status == 'IN').length;
    final outCount =
        _history.where((h) => h.status == 'OUT').length;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          _SummaryItem(
              label: 'Total events',
              value: '${_history.length}',
              color: kNavy),
          _buildDivider(),
          _SummaryItem(
              label: 'Landings',
              value: '$inCount',
              color: kTeal),
          _buildDivider(),
          _SummaryItem(
              label: 'Deployments',
              value: '$outCount',
              color: kAmber),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
        width: 1,
        height: 32,
        color: Colors.grey.shade200,
        margin: const EdgeInsets.symmetric(horizontal: 16));
  }
}

class _SummaryItem extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SummaryItem(
      {required this.label,
        required this.value,
        required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  color: Colors.grey.shade500, fontSize: 11),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final DroneHistory entry;
  final bool isLast;
  const _HistoryItem({required this.entry, required this.isLast});

  static const Color kTeal = Color(0xFF00D4AA);
  static const Color kAmber = Color(0xFFFFB800);
  static const Color kPurple = Color(0xFF6C63FF);

  @override
  Widget build(BuildContext context) {
    final isIn = entry.status == 'IN';
    final color = isIn ? kTeal : kAmber;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: color.withOpacity(0.4), width: 1.5),
                  ),
                  child: Icon(
                      isIn
                          ? Icons.flight_land
                          : Icons.flight_takeoff,
                      color: color,
                      size: 17),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: Colors.grey.shade200,
                      margin:
                      const EdgeInsets.symmetric(vertical: 5),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        color.withOpacity(0.8),
                        color.withOpacity(0.15)
                      ]),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(14)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius:
                                BorderRadius.circular(7),
                                border: Border.all(
                                    color:
                                    color.withOpacity(0.4)),
                              ),
                              child: Text(entry.status,
                                  style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                      letterSpacing: 1)),
                            ),
                            const Spacer(),
                            Row(children: [
                              Icon(Icons.access_time,
                                  color: Colors.grey.shade400,
                                  size: 12),
                              const SizedBox(width: 5),
                              Text(entry.time,
                                  style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 12)),
                            ]),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: kPurple.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                                Icons.person_outline,
                                color: kPurple,
                                size: 15),
                          ),
                          const SizedBox(width: 9),
                          Text(
                            entry.pilot.isEmpty
                                ? 'Used by: Unknown'
                                : 'Used by: ${entry.pilot}',
                            style: const TextStyle(
                                color: Color(0xFF0A1628),
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                          ),
                        ]),
                        if (entry.purpose != null &&
                            entry.purpose!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(children: [
                            Icon(Icons.flag_outlined,
                                color: Colors.grey.shade400, size: 13),
                            const SizedBox(width: 7),
                            Text('Purpose: ${entry.purpose}',
                                style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ]),
                        ],
                        if (entry.notes != null &&
                            entry.notes!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F4F8),
                              borderRadius:
                              BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.notes,
                                    color: Colors.grey.shade400,
                                    size: 13),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(entry.notes!,
                                      style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
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

class _PulsingHistoryIcon extends StatelessWidget {
  final AnimationController anim;
  const _PulsingHistoryIcon({required this.anim});

  static const Color kPurple = Color(0xFF6C63FF);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final pulse =
            (math.sin(anim.value * 2 * math.pi) + 1) / 2;
        return Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: kPurple.withOpacity(0.2 + pulse * 0.3),
                width: 1.5),
            color: kPurple.withOpacity(0.05 + pulse * 0.05),
          ),
          child: Icon(Icons.history,
              color: kPurple.withOpacity(0.7 + pulse * 0.3),
              size: 34),
        );
      },
    );
  }
}

class _SubtleGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 0.5;
    const spacing = 24.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}