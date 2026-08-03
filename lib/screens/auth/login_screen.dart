// lib/screens/auth/login_screen.dart

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'package:cda_inventory/screens/auth/register_screen.dart';
import 'package:cda_inventory/services/auth_service.dart';
import 'package:cda_inventory/services/access_control_service.dart';
import 'package:cda_inventory/core/access/access_scope.dart';
import 'package:cda_inventory/screens/auth/widgets/cda_futuristic_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String _selectedRole = 'Employee';
  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ── CDA Futuristic Brand Colors ──────────────────────────────
  static const kNavy = Color(0xFF0D2A3D); // CDA navy blue
  static const kDarkNav = Color(0xFF071827); // darker navy
  static const kBlue = Color(0xFF00AEEF); // electric blue
  static const kWhite = Colors.white;
  static const kBg = Color(0xFF071827); // dark navy background
  static const kCard = Color(0xFF0D2A3D);
  static const kAccentText = Color(0xFF4DE8FF);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Login ────────────────────────────────────────────────────
  // Single source of truth for the whole "admin has full control" flow:
  //   1. AuthService.loginWithRole() signs in AND enforces that only the
  //      one reserved email (kAdminEmail) can ever come back as 'admin' —
  //      it signs the user back out and returns an error for anyone else
  //      who tries to log in as Admin, or whose real role doesn't match
  //      the tab they picked.
  //   2. AccessControlService.onUserLoggedIn() creates/refreshes this
  //      user's users/{uid} doc and — for every non-admin — fires an
  //      admin_notifications entry so the admin sees an access request.
  //   3. CurrentAccess.listenTo() starts the live accessLevel/accessStatus
  //      stream that EditGuard / ViewOnlyBanner / admin screens depend on.
  //   4. Routing: admins and already-approved employees go straight to
  //      the dashboard; everyone else goes to /waiting-approval, where
  //      they're auto-forwarded the instant the admin approves them.
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final requiredRole = _selectedRole == 'Admin' ? 'admin' : 'employee';

    try {
      final result = await AuthService.loginWithRole(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
        requiredRole: requiredRole,
      );

      if (result['success'] != true) {
        final msg = result['message'] as String? ?? 'Login failed. Please try again';
        setState(() => _error = msg);
        _showSnack(msg);
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _error = 'Something went wrong. Please try again.');
        return;
      }

      final role = result['role'] as String? ?? requiredRole;

      // loginWithRole() above already read users/{uid} once to resolve the
      // role — reuse that result here instead of onUserLoggedIn() reading
      // the same document again.
      final access = await AccessControlService.onUserLoggedIn(
        uid: user.uid,
        name: user.displayName?.isNotEmpty == true ? user.displayName! : _emailCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        role: role,
        existingData: result['docData'] as Map<String, dynamic>?,
        existingDataFound: result['docExists'] as bool?,
      );

      if (!mounted) return;
      context.read<CurrentAccess>().listenTo(user.uid, knownName: access.name, knownRole: access.role);

      if (access.isAdmin || access.canView) {
        Navigator.pushReplacementNamed(context, '/dashboard', arguments: role);
      } else {
        // Pending or rejected — waiting_approval_screen shows the right
        // state and auto-forwards to /dashboard the moment the admin
        // approves, no second login needed.
        Navigator.pushReplacementNamed(context, '/waiting-approval');
      }
    } on AccountRemovedException {
      await AuthService.logout();
      const msg = 'This account has been removed by the admin. Contact them for access.';
      setState(() => _error = msg);
      _showSnack(msg);
    } on FirebaseAuthException catch (e) {
      String friendlyMessage;
      switch (e.code) {
        case 'invalid-email':
          friendlyMessage = 'Please enter a valid email address';
          break;
        case 'user-not-found':
          friendlyMessage = 'No account found with this email';
          break;
        case 'wrong-password':
        case 'invalid-credential':
          friendlyMessage = 'Incorrect email or password';
          break;
        default:
          friendlyMessage = e.message ?? 'Login failed. Please try again';
      }
      setState(() => _error = friendlyMessage);
      _showSnack(friendlyMessage);
    } catch (e) {
      final msg = 'Something went wrong: $e';
      setState(() => _error = msg);
      _showSnack(msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  // ── Forgot Password flow ─────────────────────────────────────
  Future<void> _showForgotPasswordDialog() async {
    final resetEmailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    final resetFormKey = GlobalKey<FormState>();
    bool sending = false;
    String? dialogError;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: kCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: kBlue.withOpacity(0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Form(
                  key: resetFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.lock_reset_rounded,
                          color: kAccentText, size: 36),
                      const SizedBox(height: 10),
                      const Text('Reset Password',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: kWhite,
                              fontSize: 17,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(
                        'Enter your email and we\'ll send you a link to reset your password.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.45),
                            fontSize: 12.5),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: resetEmailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        cursorColor: kAccentText,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter your email';
                          }
                          if (!v.contains('@') || !v.contains('.')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: TextStyle(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 13),
                          prefixIcon:
                          const Icon(Icons.email_outlined, color: kAccentText, size: 20),
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
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      if (dialogError != null) ...[
                        const SizedBox(height: 10),
                        Text(dialogError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 12.5)),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: sending
                                  ? null
                                  : () => Navigator.pop(dialogContext),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white.withOpacity(0.5),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: sending
                                  ? null
                                  : () async {
                                if (!resetFormKey.currentState!.validate()) {
                                  return;
                                }
                                setDialogState(() {
                                  sending = true;
                                  dialogError = null;
                                });
                                try {
                                  await FirebaseAuth.instance
                                      .sendPasswordResetEmail(
                                    email: resetEmailCtrl.text.trim(),
                                  );
                                  if (!mounted) return;
                                  Navigator.pop(dialogContext);
                                  _showSnack(
                                    'Reset link sent to ${resetEmailCtrl.text.trim()}',
                                    isError: false,
                                  );
                                } on FirebaseAuthException catch (e) {
                                  String msg;
                                  switch (e.code) {
                                    case 'invalid-email':
                                      msg = 'Please enter a valid email address';
                                      break;
                                    case 'user-not-found':
                                      msg = 'No account found with this email';
                                      break;
                                    default:
                                      msg = e.message ?? 'Could not send reset email';
                                  }
                                  setDialogState(() {
                                    dialogError = msg;
                                    sending = false;
                                  });
                                } catch (e) {
                                  setDialogState(() {
                                    dialogError = 'Something went wrong: $e';
                                    sending = false;
                                  });
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kBlue,
                                foregroundColor: kWhite,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: sending
                                  ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                                  : const Text('Send Link',
                                  style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      // `false` keeps the Scaffold body — and therefore the background
      // photo inside FuturisticDroneBackground — at the full screen
      // height even while the keyboard is open. Without this, the photo
      // was being squeezed into a shorter box every time a field was
      // focused, which re-crops/zooms `BoxFit.cover` into an odd, mostly
      // solid-looking slice. The form itself still avoids the keyboard —
      // it gets pushed up via the bottom padding below instead.
      resizeToAvoidBottomInset: false,
      body: FuturisticDroneBackground(
        child: Stack(
          children: [
            // ── Main content ───────────────────────────────────
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    28,
                    16,
                    28,
                    16 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Form(
                        key: _formKey,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 140),

                                // ── Card ──────────────────────────
                                CdaGlassCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Welcome Back!',
                                        style: TextStyle(
                                          color: kWhite,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Login to continue your journey with Chennai Drone Academy',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.55),
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 24),

                                      // Email field
                                      _buildField(
                                        controller: _emailCtrl,
                                        label: 'Email',
                                        icon: Icons.email_rounded,
                                        keyboardType: TextInputType.emailAddress,
                                        validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Email required'
                                            : null,
                                      ),
                                      const SizedBox(height: 16),

                                      // Password field
                                      _buildField(
                                        controller: _passwordCtrl,
                                        label: 'Password',
                                        icon: Icons.lock_rounded,
                                        obscureText: _obscurePassword,
                                        suffix: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                            color: Colors.white38,
                                            size: 20,
                                          ),
                                          onPressed: () => setState(
                                                  () => _obscurePassword = !_obscurePassword),
                                        ),
                                        validator: (v) =>
                                        (v == null || v.isEmpty)
                                            ? 'Password required'
                                            : null,
                                      ),

                                      // Forgot password
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed:
                                          _loading ? null : _showForgotPasswordDialog,
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.only(top: 8),
                                            minimumSize: Size.zero,
                                            tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: const Text(
                                            'Forgot Password?',
                                            style: TextStyle(
                                              color: kAccentText,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 8),

                                      // Role dropdown
                                      _buildRoleDropdown(),

                                      if (_error != null) ...[
                                        const SizedBox(height: 12),
                                        Text(
                                          _error!,
                                          style: const TextStyle(
                                              color: Colors.redAccent, fontSize: 13),
                                        ),
                                      ],

                                      const SizedBox(height: 20),

                                      // Sign In Button
                                      CdaNeonButton(
                                        label: 'LOGIN',
                                        icon: Icons.arrow_forward_rounded,
                                        loading: _loading,
                                        onPressed: _loading ? null : _login,
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // ── Register link ─────────────────
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(16),
                                        border:
                                        Border.all(color: kBlue.withOpacity(0.25)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            "Don't have an account?  ",
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.5),
                                              fontSize: 13,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: _loading
                                                ? null
                                                : () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(settings: const RouteSettings(name: 'Register'),
                                                    builder: (_) => const RegisterScreen()),
                                              );
                                            },
                                            child: const Text(
                                              'Register Now',
                                              style: TextStyle(
                                                color: kAccentText,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 20),

                                // ── Footer ────────────────────────
                                Text(
                                  '© 2026 Chennai Drone Academy',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.25),
                                    fontSize: 11,
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Reusable dark-themed field ───────────────────────────────
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
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 14),
        prefixIcon: Icon(icon, color: kBlue.withOpacity(0.7), size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: kBlue.withOpacity(0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: kBlue.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      validator: validator,
    );
  }

  // ── Role dropdown, themed to match the card fields ───────────
  Widget _buildRoleDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBlue.withOpacity(0.15)),
        color: Colors.white.withOpacity(0.05),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedRole,
          isExpanded: true,
          dropdownColor: kCard,
          icon: const Icon(Icons.arrow_drop_down, color: kAccentText),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          items: const [
            DropdownMenuItem(value: 'Admin', child: Text('Admin')),
            DropdownMenuItem(value: 'Employee', child: Text('Employee')),
          ],
          onChanged: (value) {
            setState(() => _selectedRole = value ?? 'Employee');
          },
        ),
      ),
    );
  }
}