// lib/widgets/ai_assistant/floating_chat_button.dart
//
// Wrap around MaterialApp's `builder`, same pattern as
// InAppNotificationBanner — stacks a floating action button over every
// screen without touching the routes table. Tapping opens AiChatScreen
// via a plain MaterialPageRoute (no named route added, per the "don't
// modify routes" requirement) with a RouteSettings name so the existing
// AccessRouteObserver / Activity Feed still logs the visit like every
// other screen in the app.

import 'package:flutter/material.dart';

import '../../screens/ai_assistant/ai_chat_screen.dart';

class FloatingChatButton extends StatelessWidget {
  final Widget child;
  const FloatingChatButton({super.key, required this.child});

  static const _primary = Color(0xFF1E5FC8);
  static const _accent = Color(0xFF00D68F);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          right: 20,
          bottom: 24,
          child: _PulsingFab(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'AI Assistant'),
                  builder: (_) => const AiChatScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PulsingFab extends StatefulWidget {
  final VoidCallback onTap;
  const _PulsingFab({required this.onTap});

  @override
  State<_PulsingFab> createState() => _PulsingFabState();
}

class _PulsingFabState extends State<_PulsingFab> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final glow = 0.25 + (_controller.value * 0.25);
        return Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.onTap,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [FloatingChatButton._primary, FloatingChatButton._accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: FloatingChatButton._accent.withOpacity(glow),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 26),
            ),
          ),
        );
      },
    );
  }
}