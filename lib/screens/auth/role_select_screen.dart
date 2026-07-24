import 'package:flutter/material.dart';
import 'admin_login_screen.dart';
import 'employee_login_screen.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  // ── CDA Brand Colors ─────────────────────────────────────────
  static const kNavy  = Color(0xFF1A2A5E);
  static const kBlue  = Color(0xFF2A4DB5);
  static const kWhite = Colors.white;
  static const kBg    = Color(0xFF0A1128);
  static const kCard  = Color(0xFF111D3A);
  static const kAccent = Color(0xFF7FA8FF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kBlue.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kNavy.withOpacity(0.25),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: kBlue.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/images/logo.png',
                          height: 90,
                          width: 90,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.flight_takeoff_rounded,
                              color: kBlue, size: 48),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Chennai Drone Academy',
                      style: TextStyle(
                        color: kWhite,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: kBlue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kBlue.withOpacity(0.4)),
                      ),
                      child: const Text(
                        'Inventory Management',
                        style: TextStyle(
                          color: kAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    Text(
                      'Continue as',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _RoleCard(
                      title: 'Admin',
                      subtitle: 'Full access & management',
                      icon: Icons.admin_panel_settings_rounded,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(settings: const RouteSettings(name: 'Admin Login'),
                            builder: (_) => const AdminLoginScreen()),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _RoleCard(
                      title: 'Employee',
                      subtitle: 'Branch & inventory operations',
                      icon: Icons.badge_rounded,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(settings: const RouteSettings(name: 'Employee Login'),
                            builder: (_) => const EmployeeLoginScreen()),
                      ),
                    ),

                    const SizedBox(height: 32),
                    Text(
                      '© 2025 Chennai Drone Academy',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.2),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: RoleSelectScreen.kCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: RoleSelectScreen.kBlue.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: RoleSelectScreen.kBlue.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: RoleSelectScreen.kBlue.withOpacity(0.4)),
                ),
                child: Icon(icon, color: RoleSelectScreen.kAccent, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: RoleSelectScreen.kWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.3), size: 16),
            ],
          ),
        ),
      ),
    );
  }
}