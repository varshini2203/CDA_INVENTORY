// lib/screens/admin/admin_hero_banner.dart
//
// Shared hero banner for the admin screens (Pending Requests, Manage
// Employees, Live Activity Feed, Employee Activity). One place to control
// the artwork position, so the drone stays visible on every screen.

import 'package:flutter/material.dart';

class AdminHeroBanner extends StatelessWidget {
  /// Title / subtitle (or avatar + name) pinned to the bottom-left.
  final Widget bottomLeft;

  /// Optional small action pinned to the top-right (sort pill, sync button).
  final Widget? topRight;

  final double height;

  const AdminHeroBanner({
    super.key,
    required this.bottomLeft,
    this.topRight,
    this.height = 220,
  });

  /// Which part of pending.png is shown inside the short, wide banner.
  ///   x: -1 = left edge, 1 = right edge (only matters on narrow screens)
  ///   y: -1 = top of the photo, 0 = middle, 1 = bottom.
  /// The real drone sits just above the middle of the photo, on the right,
  /// so we centre the crop on it. If the drone is still cut off:
  ///   - cut at the top    -> make y bigger  (e.g. -0.28)
  ///   - cut at the bottom -> make y smaller (e.g. -0.45)
  static const Alignment imageAlignment = Alignment(0.7, -0.35);

  static const _navy = Color(0xFF071630);
  static const _blue = Color(0xFF1E5FC8);
  static const _border = Color(0xFFD5DFEE);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 4),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        // Fallback shown while the photo loads / if it is missing.
        gradient: const LinearGradient(
          colors: [Color(0xFF2F6FDB), Color(0xFF0D3A80)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _blue.withOpacity(0.14),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/pending.png',
              fit: BoxFit.cover,
              alignment: imageAlignment,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          // Left-side scrim only: keeps the white title readable while the
          // right side (where the drone is) stays bright and clear.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _navy.withOpacity(0.62),
                    _navy.withOpacity(0.22),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.40, 0.65],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
          // Very light fade at the bottom-left only, so the drone on the
          // bottom-right is never darkened.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, _navy.withOpacity(0.28)],
                  stops: const [0.60, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(left: 16, right: 16, bottom: 14, child: bottomLeft),
          if (topRight != null) Positioned(top: 12, right: 12, child: topRight!),
        ],
      ),
    );
  }
}