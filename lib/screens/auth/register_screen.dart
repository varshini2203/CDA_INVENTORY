import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cda_inventory/services/auth_service.dart';
import 'package:cda_inventory/screens/auth/widgets/cda_futuristic_ui.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// 🎨 DESIGN TOKENS — CDA Futuristic (electric blue / dark navy)
// ═══════════════════════════════════════════════════════════════════════════════
const _bg          = Color(0xFF071827);
const _bgDeep      = Color(0xFF040D16);
const _surface     = Color(0x0DFFFFFF); // glass fill
const _surfaceHigh = Color(0xFF0D2A3D);
const _border      = Color(0x4D00AEEF); // electric blue @ 30%

const _blue        = Color(0xFF00AEEF);
const _blueLight   = Color(0xFF4DE8FF);
const _blueDark    = Color(0xFF0080C4);

const _white       = Color(0xFFF0F6FF);
const _green       = Color(0xFF00D68F);
const _red         = Color(0xFFE8374A);

const _textPrimary = Color(0xFFF0F6FF);
const _textSub     = Color(0xFFA0B8D0);
const _textMuted   = Color(0xFF7FA8C0);

// ── Branch options for the dropdown ──────────────────────────────────────
const List<String> kBranchOptions = ['CDA Admin', 'CDA Ops'];

class RegisterScreen extends StatefulWidget {
  final String initialRole;

  const RegisterScreen({super.key, this.initialRole = 'employee'});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController     = TextEditingController();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();

  // Branch is now a dropdown selection instead of free text.
  String? _selectedBranch;

  bool _obscurePassword = true;
  bool _obscureConfirm  = true;
  bool _isLoading = false;
  bool _agreedToTerms = false;
  late String _selectedRole = widget.initialRole;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _red.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Text('Please agree to the Terms & Conditions to continue.',
              style: TextStyle(color: Colors.white)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authService = AuthService();

    final result = await authService.register(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text.trim(),
      _selectedBranch ?? '',
      _selectedRole,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _green.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(result['message'] ?? 'Account created successfully!',
              style: const TextStyle(color: Colors.white)),
        ),
      );
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _red.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(result['message'] ?? 'Registration failed. Please try again.',
              style: const TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      // See the matching comment in login_screen.dart — this keeps the
      // background photo at full screen height even while the keyboard
      // is open, instead of it being squeezed/re-cropped every time a
      // field is focused. The form scrolls up via the bottom padding
      // below to stay clear of the keyboard instead.
      resizeToAvoidBottomInset: false,
      body: FuturisticDroneBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                24,
                20,
                24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Form(
                key: _formKey,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Top spacing (brand header is baked into
                        // the background photo already) ────────────
                        const SizedBox(height: 150),
                        const Text(
                          'Join CDA!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Create your account and be a part of the future of drones',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _textMuted, fontSize: 12.5),
                        ),
                        const SizedBox(height: 24),

                        // ── Glass card wrapping the whole form ─────
                        CdaGlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ── Name Field ──────────────────────────────
                              _buildLabel('Full Name'),
                              _buildTextField(
                                controller: _nameController,
                                hint: 'Enter your full name',
                                icon: Icons.person_outline_rounded,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Please enter your name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // ── Email Field ─────────────────────────────
                              _buildLabel('Email'),
                              _buildTextField(
                                controller: _emailController,
                                hint: 'Enter your email',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!RegExp(r'^[\w.\-]+@[\w\-]+\.[a-zA-Z]{2,}$').hasMatch(v.trim())) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Registration is EMPLOYEE-ONLY. There is exactly one
                              // admin account for this app and it is not created
                              // through this screen — see kAdminEmail in
                              // lib/core/constants/app_admin.dart. Every account
                              // created here starts with zero access until the
                              // admin approves it (see AccessControlService).

                              // ── Branch Field (dropdown: CDA Admin / CDA Ops) ──
                              _buildLabel('Branch'),
                              _buildBranchDropdown(),
                              const SizedBox(height: 16),

                              // ── Password Field ──────────────────────────
                              _buildLabel('Password'),
                              _buildTextField(
                                controller: _passwordController,
                                hint: 'Create a password',
                                icon: Icons.lock_outline_rounded,
                                obscureText: _obscurePassword,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                    color: _textMuted,
                                    size: 19,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Please enter a password';
                                  }
                                  if (v.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // ── Confirm Password Field ──────────────────
                              _buildLabel('Confirm Password'),
                              _buildTextField(
                                controller: _confirmController,
                                hint: 'Re-enter your password',
                                icon: Icons.lock_outline_rounded,
                                obscureText: _obscureConfirm,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                    color: _textMuted,
                                    size: 19,
                                  ),
                                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Please confirm your password';
                                  }
                                  if (v != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              // ── Terms & Conditions checkbox ───────────────
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: Checkbox(
                                      value: _agreedToTerms,
                                      onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                                      activeColor: _blue,
                                      checkColor: Colors.white,
                                      side: BorderSide(color: _blue.withOpacity(0.6)),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(4)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                                      child: RichText(
                                        text: TextSpan(
                                          style: const TextStyle(color: _textMuted, fontSize: 12.5, height: 1.4),
                                          children: const [
                                            TextSpan(text: 'I agree to the '),
                                            TextSpan(
                                              text: 'Terms & Conditions',
                                              style: TextStyle(color: _blueLight, fontWeight: FontWeight.w700),
                                            ),
                                            TextSpan(text: ' and '),
                                            TextSpan(
                                              text: 'Privacy Policy',
                                              style: TextStyle(color: _blueLight, fontWeight: FontWeight.w700),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 22),

                              // ── Register Button ──────────────────────────
                              CdaNeonButton(
                                label: 'REGISTER',
                                icon: Icons.arrow_forward_rounded,
                                loading: _isLoading,
                                onPressed: _isLoading ? null : _handleRegister,
                              ),
                            ], // end inner form-fields column
                          ),
                        ), // end CdaGlassCard

                        const SizedBox(height: 22),

                        // ── Already have account ─────────────────────
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _blue.withOpacity(0.25)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Already have an account? ',
                                    style: TextStyle(color: _textMuted, fontSize: 13),
                                  ),
                                  GestureDetector(
                                    onTap: _isLoading
                                        ? null
                                        : () => Navigator.pushReplacementNamed(context, '/login'),
                                    child: const Text(
                                      'Login Now',
                                      style: TextStyle(
                                        color: _blueLight,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Text(
                          '© 2026 Chennai Drone Academy',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _textMuted.withOpacity(0.6), fontSize: 11),
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
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        text,
        style: const TextStyle(
          color: _textSub,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: _textPrimary, fontSize: 14),
      cursorColor: _blueLight,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textMuted, fontSize: 13.5),
        prefixIcon: Icon(icon, color: _textMuted, size: 19),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: _surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _blue.withOpacity(0.7), width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _red.withOpacity(0.7), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _red, width: 1.4),
        ),
        errorStyle: const TextStyle(color: _red, fontSize: 11.5),
      ),
    );
  }

  // ── Branch dropdown (CDA Admin / CDA Ops) ─────────────────────────────
  Widget _buildBranchDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedBranch,
      dropdownColor: _surfaceHigh,
      style: const TextStyle(color: _textPrimary, fontSize: 14),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _textMuted),
      decoration: InputDecoration(
        hintText: 'Select your branch',
        hintStyle: const TextStyle(color: _textMuted, fontSize: 13.5),
        prefixIcon: const Icon(Icons.business_rounded, color: _textMuted, size: 19),
        filled: true,
        fillColor: _surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _blue.withOpacity(0.7), width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _red.withOpacity(0.7), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _red, width: 1.4),
        ),
        errorStyle: const TextStyle(color: _red, fontSize: 11.5),
      ),
      items: kBranchOptions
          .map((branch) => DropdownMenuItem(value: branch, child: Text(branch)))
          .toList(),
      onChanged: (v) => setState(() => _selectedBranch = v),
      validator: (v) {
        if (v == null || v.isEmpty) {
          return 'Please select your branch';
        }
        return null;
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ROLE CHIP (kept for reference — no longer used since registration is
// employee-only now, but left here in case you want a role picker again
// for some other purpose. Safe to delete.)
// ═══════════════════════════════════════════════════════════════════════════════
class _RoleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _blue.withOpacity(0.18) : _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _blue.withOpacity(0.7) : _border,
            width: 1.2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? _blueLight : _textMuted,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}