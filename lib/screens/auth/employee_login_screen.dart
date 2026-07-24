import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cda_inventory/services/auth_service.dart';
import 'package:cda_inventory/services/access_control_service.dart';
import 'package:cda_inventory/models/app_access_models.dart';
import 'package:cda_inventory/core/access/access_scope.dart';
import 'package:cda_inventory/screens/dashboard/dashboard_screen.dart';
import 'package:cda_inventory/screens/auth/waiting_approval_screen.dart';
import 'register_screen.dart';

class EmployeeLoginScreen extends StatefulWidget {
  const EmployeeLoginScreen({super.key});

  @override
  State<EmployeeLoginScreen> createState() => _EmployeeLoginScreenState();
}

class _EmployeeLoginScreenState extends State<EmployeeLoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey      = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading     = false;
  bool _obscure       = true;

  late AnimationController _animController;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  // ── CDA Brand Colors ─────────────────────────────────────────
  static const kNavy  = Color(0xFF1A2A5E);
  static const kBlue  = Color(0xFF2A4DB5);
  static const kWhite = Colors.white;
  static const kBg    = Color(0xFF0A1128);
  static const kAccent = Color(0xFF7FA8FF);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final result = await AuthService.loginWithRole(
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
      requiredRole: 'employee',
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      final user = FirebaseAuth.instance.currentUser;
      AppUserAccess? access;
      try {
        if (user != null) {
          // loginWithRole() above already read users/{uid} once — reuse
          // that result here instead of onUserLoggedIn() reading it again.
          access = await AccessControlService.onUserLoggedIn(
            uid: user.uid,
            name: user.displayName ?? _emailCtrl.text.trim(),
            email: user.email ?? _emailCtrl.text.trim(),
            role: 'employee',
            existingData: result['docData'] as Map<String, dynamic>?,
            existingDataFound: result['docExists'] as bool?,
          );
        }
      } on AccountRemovedException {
        await AuthService.logout();
        if (!mounted) return;
        _showSnack('Your account has been removed by the admin. Contact them for access.');
        return;
      }

      if (!mounted) return;

      if (access != null && access.canView) {
        context.read<CurrentAccess>().listenTo(user!.uid);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(settings: const RouteSettings(name: 'Dashboard'),
            builder: (_) => const DashboardScreen(userRole: 'employee'),
          ),
        );
      } else {
        // Admin has been notified; hold here until they grant access.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(settings: const RouteSettings(name: 'Waiting Approval'), builder: (_) => const WaitingApprovalScreen()),
        );
      }
    } else {
      _showSnack(result['message'] ?? 'Login failed');
    }
  }

  void _forgotPassword() {
    final emailCtrl = TextEditingController(text: _emailCtrl.text);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_reset_rounded, color: kBlue),
            SizedBox(width: 8),
            Text('Reset Password', style: TextStyle(fontSize: 17, color: kNavy)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your email and we\'ll send a reset link.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email_rounded, size: 20),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final res =
              await AuthService.forgotPassword(email: emailCtrl.text);
              if (!mounted) return;
              _showSnack(res['message'], isError: res['success'] != true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kNavy,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child:
            const Text('Send Link', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: isError ? Colors.redAccent : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

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
            child: Column(
              children: [
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111D3A),
                            borderRadius: BorderRadius.circular(12),
                            border:
                            Border.all(color: kBlue.withOpacity(0.3)),
                          ),
                          child: const Icon(Icons.arrow_back_ios_rounded,
                              color: kWhite, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: kBlue.withOpacity(0.14),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: kBlue.withOpacity(0.4)),
                                  ),
                                  child: const Icon(
                                    Icons.badge_rounded,
                                    color: kAccent,
                                    size: 40,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                const Text(
                                  'Employee Login',
                                  style: TextStyle(
                                    color: kWhite,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Chennai Drone Academy · Inventory Management',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF111D3A),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                        color: kBlue.withOpacity(0.2)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      _buildField(
                                        controller: _emailCtrl,
                                        label: 'Email',
                                        icon: Icons.email_rounded,
                                        keyboardType:
                                        TextInputType.emailAddress,
                                        validator: (v) {
                                          if (v == null ||
                                              v.trim().isEmpty) {
                                            return 'Enter your email';
                                          }
                                          if (!v.contains('@')) {
                                            return 'Enter a valid email';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      _buildField(
                                        controller: _passwordCtrl,
                                        label: 'Password',
                                        icon: Icons.lock_rounded,
                                        obscureText: _obscure,
                                        suffix: IconButton(
                                          icon: Icon(
                                            _obscure
                                                ? Icons
                                                .visibility_off_rounded
                                                : Icons.visibility_rounded,
                                            color: Colors.white38,
                                            size: 20,
                                          ),
                                          onPressed: () => setState(
                                                  () => _obscure = !_obscure),
                                        ),
                                        validator: (v) =>
                                        (v == null || v.length < 6)
                                            ? 'Min 6 characters'
                                            : null,
                                      ),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: _forgotPassword,
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.only(
                                                top: 8),
                                            minimumSize: Size.zero,
                                            tapTargetSize:
                                            MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          child: const Text(
                                            'Forgot Password?',
                                            style: TextStyle(
                                              color: kAccent,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 52,
                                        child: ElevatedButton(
                                          onPressed:
                                          _isLoading ? null : _login,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: kBlue,
                                            foregroundColor: kWhite,
                                            disabledBackgroundColor:
                                            kBlue.withOpacity(0.4),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                              BorderRadius.circular(14),
                                            ),
                                            elevation: 0,
                                          ),
                                          child: _isLoading
                                              ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child:
                                            CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          )
                                              : const Row(
                                            mainAxisAlignment:
                                            MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.login_rounded,
                                                  size: 20),
                                              SizedBox(width: 8),
                                              Text(
                                                'Sign In',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight:
                                                  FontWeight.bold,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF111D3A),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: kBlue.withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Don't have an account?  ",
                                        style: TextStyle(
                                          color:
                                          Colors.white.withOpacity(0.5),
                                          fontSize: 13,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(settings: const RouteSettings(name: 'Register'),
                                              builder: (_) =>
                                              const RegisterScreen(
                                                  initialRole:
                                                  'employee')),
                                        ),
                                        child: const Text(
                                          'Create Account',
                                          style: TextStyle(
                                            color: kAccent,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
        TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      validator: validator,
    );
  }
}