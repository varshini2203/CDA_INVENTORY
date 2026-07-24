import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cda_inventory/screens/dashboard/dashboard_screen.dart';
import 'package:cda_inventory/providers/theme_provider.dart';
import 'package:cda_inventory/providers/language_provider.dart';
import 'package:cda_inventory/localization/app_strings.dart';
import 'package:cda_inventory/core/access/access_scope.dart';

class AppColors {
  final bool isDark;
  const AppColors(this.isDark);

  Color get bg          => isDark ? const Color(0xFF050A14) : const Color(0xFFF2F5FA);
  Color get bgDeep      => isDark ? const Color(0xFF030710) : const Color(0xFFE8EDF5);
  Color get surface     => isDark ? const Color(0xFF0A1428) : Colors.white;
  Color get surfaceHigh => isDark ? const Color(0xFF0F1C35) : const Color(0xFFF7F9FC);
  Color get border      => isDark ? const Color(0xFF1A2E50) : const Color(0xFFD8E0EC);

  Color get blue      => const Color(0xFF1E5FC8);
  Color get blueLight => const Color(0xFF3A7AE8);
  Color get blueDark  => const Color(0xFF0D3A80);

  Color get silver => isDark ? const Color(0xFFB8C8DC) : const Color(0xFF5A6B85);

  Color get green => const Color(0xFF00D68F);
  Color get red   => const Color(0xFFE8374A);
  Color get amber => const Color(0xFFF5A623);

  Color get textPrimary => isDark ? const Color(0xFFF0F6FF) : const Color(0xFF0A1428);
  Color get textSub     => isDark ? const Color(0xFFA0B8D0) : const Color(0xFF4A5A70);
  Color get textMuted   => isDark ? const Color(0xFF4A6080) : const Color(0xFF8A97A8);
}

// ⚠️ CONFIRM these match your real Firestore collection names in console
const _colUsers       = 'users';
const _colDrones      = 'drone_tracking';
const _colFixedAssets = 'fixed_products';
const _colConsumables = 'consumables';
const _colBranches    = 'branches';
const _colInvoices    = 'invoices';

const _kEmailNotif = 'profile_email_notif';
// Firestore field on users/{uid} that the weekly-report Cloud Function
// will read to decide who gets the email.
const _fieldWeeklyReport = 'weeklyReportEnabled';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  bool _uploadingPhoto = false;

  User? _authUser;
  String _name    = '';
  String _email   = '';
  String _phone   = '';
  String _role    = 'Team Member';
  String _branch  = 'Unassigned';
  String? _photoUrl;
  // Bytes of the just-picked image, shown immediately via Image.memory so
  // the avatar updates the instant the user picks a photo — instead of
  // waiting on Image.network(_photoUrl) to round-trip through Firebase
  // Storage, which can silently fail to render on Flutter Web when the
  // storage bucket's CORS config doesn't allow this origin (the classic
  // cause of "picked a photo but it never shows, just falls back to the
  // initials circle"). Cleared if the upload itself fails.
  Uint8List? _localPhotoBytes;

  bool _emailNotif = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    _authUser = user;

    // Local cache first (instant paint), Firestore is the source of truth
    // and overrides this below once it comes back.
    _emailNotif = prefs.getBool(_kEmailNotif) ?? true;

    if (user != null) {
      _name  = (user.displayName?.trim().isNotEmpty ?? false) ? user.displayName! : 'CDA User';
      _email = user.email ?? '';
      _photoUrl = user.photoURL;

      // The users/{uid} document is already kept live in CurrentAccess
      // (populated once right after login, shared across the whole app —
      // see core/access/access_scope.dart), so read the profile fields
      // from there instead of issuing a dedicated Firestore get() every
      // time this screen opens.
      final access = mounted ? context.read<CurrentAccess>().access : null;
      if (access != null) {
        _phone  = access.phone.isNotEmpty ? access.phone : _phone;
        _role   = access.role.isNotEmpty ? access.role : _role;
        _branch = access.branch.isNotEmpty ? access.branch : _branch;
        _name   = access.name.isNotEmpty ? access.name : _name;
      }

      // weeklyReportEnabled isn't part of CurrentAccess, so read it
      // directly — this is what the weekly-report Cloud Function checks
      // to decide who to email, so it has to live in Firestore, not just
      // on-device SharedPreferences.
      try {
        final doc = await FirebaseFirestore.instance.collection(_colUsers).doc(user.uid).get();
        final data = doc.data();
        if (data != null && data.containsKey(_fieldWeeklyReport)) {
          _emailNotif = data[_fieldWeeklyReport] as bool;
          await prefs.setBool(_kEmailNotif, _emailNotif); // keep local cache in sync
        }
      } catch (e) {
        debugPrint('Could not load $_fieldWeeklyReport: $e');
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  // Persists the Email Notifications toggle to Firestore so the weekly
  // scheduled Cloud Function can query "which users want the report".
  // Local SharedPreferences is kept too, purely as a fast on-device cache.
  Future<void> _saveEmailNotifPref(bool value) async {
    await _saveBool(_kEmailNotif, value);

    final user = _authUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection(_colUsers).doc(user.uid).set(
        {_fieldWeeklyReport: value},
        SetOptions(merge: true),
      );
    } catch (e) {
      if (mounted) {
        // Revert the UI if the write failed, so the switch doesn't lie
        // about what's actually saved server-side.
        setState(() => _emailNotif = !value);
        _showToast('Could not save preference: $e');
      }
    }
  }

  Future<void> _persistProfile({
    required String name,
    required String phone,
    required String role,
    required String branch,
  }) async {
    final user = _authUser;
    if (user == null) return;

    if (user.displayName != name) {
      await user.updateDisplayName(name);
    }

    await FirebaseFirestore.instance.collection(_colUsers).doc(user.uid).set({
      'name': name,
      'phone': phone,
      'role': role,
      'branch': branch,
      'email': user.email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await user.reload();
    _authUser = FirebaseAuth.instance.currentUser;
  }

  Future<void> _openEditSheet(AppColors c, String lang) async {
    final nameCtrl   = TextEditingController(text: _name);
    final phoneCtrl  = TextEditingController(text: _phone);
    final roleCtrl   = TextEditingController(text: _role);
    final branchCtrl = TextEditingController(text: _branch);
    String t(String k) => AppStrings.tr(lang, k);

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: c.bgDeep,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              border: Border(top: BorderSide(color: c.border, width: 1)),
            ),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(t('edit_profile'),
                    style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(_email.isEmpty ? t('no_email_on_file') : _email,
                    style: TextStyle(color: c.textMuted, fontSize: 11.5)),
                const SizedBox(height: 16),
                _EditField(c: c, label: t('full_name'), controller: nameCtrl, icon: Icons.person_rounded),
                const SizedBox(height: 12),
                _EditField(c: c, label: t('phone'), controller: phoneCtrl, icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _EditField(c: c, label: t('designation'), controller: roleCtrl, icon: Icons.badge_rounded),
                const SizedBox(height: 12),
                _EditField(c: c, label: t('branch'), controller: branchCtrl, icon: Icons.business_rounded),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: BorderSide(color: c.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(t('cancel'), style: TextStyle(color: c.textSub)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            await _persistProfile(
                              name: nameCtrl.text.trim().isEmpty ? _name : nameCtrl.text.trim(),
                              phone: phoneCtrl.text.trim(),
                              role: roleCtrl.text.trim().isEmpty ? _role : roleCtrl.text.trim(),
                              branch: branchCtrl.text.trim().isEmpty ? _branch : branchCtrl.text.trim(),
                            );
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('Could not save: $e')),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.blue,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(t('save_changes'),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == true && mounted) {
      await _load();
      _showToast('Profile updated successfully');
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final user = _authUser;
    if (user == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 800);
    if (picked == null) return;

    // Use bytes instead of dart:io File — works on both Web and mobile.
    final bytes = await picked.readAsBytes();

    // Show the picked photo right away, from the bytes already sitting in
    // memory — don't wait on the upload + Image.network round-trip.
    setState(() {
      _uploadingPhoto = true;
      _localPhotoBytes = bytes;
    });

    try {
      final ref = FirebaseStorage.instance.ref().child('profile_photos/${user.uid}.jpg');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));

      final url = await ref.getDownloadURL();

      await user.updatePhotoURL(url);
      await FirebaseFirestore.instance.collection(_colUsers).doc(user.uid).set(
        {'photoUrl': url}, SetOptions(merge: true),
      );
      await user.reload();

      if (mounted) {
        setState(() {
          _authUser = FirebaseAuth.instance.currentUser;
          _photoUrl = url;
        });
        _showToast('Profile photo updated');
      }
    } catch (e) {
      // Upload itself failed (network/permissions) — nothing saved, so
      // drop the local preview too rather than showing a photo that
      // isn't actually stored.
      if (mounted) {
        setState(() => _localPhotoBytes = null);
        _showToast('Upload failed: $e');
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _showToast(String msg) {
    final isDark = context.read<ThemeProvider>().isDark;
    final c = AppColors(isDark);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: c.surfaceHigh,
        content: Row(children: [
          Icon(Icons.check_circle_rounded, color: c.green, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: TextStyle(color: c.textPrimary))),
        ]),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _sendPasswordReset() async {
    final email = _authUser?.email;
    if (email == null || email.isEmpty) {
      _showToast('No email on file for this account');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showToast('Password reset link sent to $email');
    } on FirebaseAuthException catch (e) {
      _showToast(e.message ?? 'Could not send reset email');
    }
  }

  Future<void> _confirmLogout(AppColors c, String lang) async {
    String t(String k) => AppStrings.tr(lang, k);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surfaceHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.red.withOpacity(0.3)),
        ),
        title: Row(children: [
          Icon(Icons.logout_rounded, color: c.red, size: 20),
          const SizedBox(width: 8),
          Text(t('log_out_confirm_title'), style: TextStyle(color: c.textPrimary, fontSize: 16)),
        ]),
        content: Text(
          t('log_out_confirm_body'),
          style: TextStyle(color: c.textSub, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('cancel'), style: TextStyle(color: c.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: c.red, elevation: 0),
            child: Text(t('log_out'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  Future<void> _openLanguagePicker(AppColors c, String currentLang) async {
    String t(String k) => AppStrings.tr(currentLang, k);
    const options = [
      {'code': 'en', 'label': 'English'},
      {'code': 'ta', 'label': 'தமிழ் (Tamil)'},
      {'code': 'hi', 'label': 'हिन्दी (Hindi)'},
    ];

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: c.bgDeep,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            border: Border(top: BorderSide(color: c.border, width: 1)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 14),
              Text(t('select_language'), style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ...options.map((opt) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  opt['code'] == currentLang ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: opt['code'] == currentLang ? c.blueLight : c.textMuted,
                ),
                title: Text(opt['label']!, style: TextStyle(color: c.textPrimary, fontSize: 14)),
                onTap: () => Navigator.pop(ctx, opt['code']),
              )),
            ],
          ),
        );
      },
    );

    if (selected != null && selected != currentLang) {
      await context.read<LanguageProvider>().setLanguage(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final lang = context.watch<LanguageProvider>().code;
    final c = AppColors(isDark);
    String t(String k) => AppStrings.tr(lang, k);

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          _ProfileBackground(isDark: isDark),
          SafeArea(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: c.blueLight))
                : RefreshIndicator(
              color: c.blueLight,
              backgroundColor: c.surfaceHigh,
              onRefresh: _load,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(
                    child: _TopBar(c: c, title: t('my_profile'), onEdit: () => _openEditSheet(c, lang), userRole: _role),
                  ),
                  SliverToBoxAdapter(
                    child: _ProfileHeaderCard(
                      c: c,
                      name: _name,
                      email: _email,
                      role: _role,
                      branch: _branch,
                      verifiedLabel: t('verified'),
                      noEmailLabel: t('no_email'),
                      photoUrl: _photoUrl,
                      localPhotoBytes: _localPhotoBytes,
                      uploading: _uploadingPhoto,
                      onEdit: () => _openEditSheet(c, lang),
                      onChangePhoto: _pickAndUploadPhoto,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _SectionHeader(c: c, label: t('account'), icon: Icons.person_outline_rounded),
                  ),
                  SliverToBoxAdapter(
                    child: _SettingsGroup(c: c, children: [
                      _SettingsTile(
                        c: c,
                        icon: Icons.person_rounded,
                        title: t('personal_information'),
                        subtitle: _phone.isEmpty ? _email : '$_email  ·  $_phone',
                        onTap: () => _openEditSheet(c, lang),
                      ),
                      _SettingsTile(
                        c: c,
                        icon: Icons.lock_rounded,
                        title: t('change_password'),
                        subtitle: t('change_password_sub'),
                        onTap: _sendPasswordReset,
                      ),
                    ]),
                  ),
                  SliverToBoxAdapter(
                    child: _SectionHeader(c: c, label: t('notifications'), icon: Icons.notifications_none_rounded),
                  ),
                  SliverToBoxAdapter(
                    child: _SettingsGroup(c: c, children: [
                      _SettingsTile(
                        c: c,
                        icon: Icons.mark_email_unread_rounded,
                        title: t('email_notifications'),
                        subtitle: t('email_notifications_sub'),
                        trailing: _MiniSwitch(
                          c: c,
                          value: _emailNotif,
                          onChanged: (v) {
                            setState(() => _emailNotif = v);
                            _saveEmailNotifPref(v);
                          },
                        ),
                      ),
                    ]),
                  ),
                  SliverToBoxAdapter(
                    child: _SectionHeader(c: c, label: t('preferences'), icon: Icons.tune_rounded),
                  ),
                  SliverToBoxAdapter(
                    child: _SettingsGroup(c: c, children: [
                      _SettingsTile(
                        c: c,
                        icon: Icons.dark_mode_rounded,
                        title: t('dark_mode'),
                        subtitle: isDark ? t('dark_mode_on') : t('light_mode_on'),
                        trailing: _MiniSwitch(
                          c: c,
                          value: isDark,
                          onChanged: (v) => context.read<ThemeProvider>().toggle(v),
                        ),
                      ),
                      _SettingsTile(
                        c: c,
                        icon: Icons.language_rounded,
                        title: t('language'),
                        subtitle: context.watch<LanguageProvider>().displayName,
                        onTap: () => _openLanguagePicker(c, lang),
                      ),
                    ]),
                  ),
                  SliverToBoxAdapter(
                    child: _SectionHeader(c: c, label: t('support'), icon: Icons.help_outline_rounded),
                  ),
                  SliverToBoxAdapter(
                    child: _SettingsGroup(c: c, children: [
                      _SettingsTile(
                        c: c,
                        icon: Icons.info_rounded,
                        title: t('about_app'),
                        subtitle: t('about_app_sub'),
                        onTap: () => _showAboutSheet(context, c, lang),
                      ),
                    ]),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 18, 14, 8),
                      child: _LogoutButton(c: c, label: t('log_out'), onTap: () => _confirmLogout(c, lang)),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        children: [
                          Icon(Icons.flight_takeoff_rounded, color: c.textMuted, size: 14),
                          const SizedBox(height: 4),
                          Text('Chennai Drone Academy  ·  SkyLNK Unmanned Pvt. Ltd.',
                              style: TextStyle(color: c.textMuted, fontSize: 10)),
                          const SizedBox(height: 2),
                          Text('Version 2.0.0 (Build 240)',
                              style: TextStyle(color: c.textMuted, fontSize: 9)),
                        ],
                      ),
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

  void _showAboutSheet(BuildContext context, AppColors c, String lang) {
    String t(String k) => AppStrings.tr(lang, k);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surfaceHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.border),
        ),
        title: Text(t('about'), style: TextStyle(color: c.textPrimary)),
        content: Text(
          t('about_body'),
          style: TextStyle(color: c.textSub, fontSize: 12.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('close'), style: TextStyle(color: c.blueLight)),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final AppColors c;
  final String title;
  final VoidCallback onEdit;
  final String userRole;
  const _TopBar({required this.c, required this.title, required this.onEdit, required this.userRole});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: Row(
        children: [
          Builder(
            builder: (ctx) => _RoundIconButton(
              c: c,
              icon: Icons.arrow_back_rounded,
              onTap: () {
                if (Navigator.of(ctx).canPop()) {
                  Navigator.of(ctx).pop();
                } else {
                  Navigator.of(ctx).pushReplacement(
                    MaterialPageRoute(settings: const RouteSettings(name: 'Dashboard'), builder: (_) => DashboardScreen(userRole: userRole)),
                  );
                }
              },
            ),
          ),
          const Spacer(),
          Text(title,
              style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
          const Spacer(),
          Builder(
            builder: (ctx) => _RoundIconButton(
              c: c,
              icon: Icons.home_rounded,
              onTap: () => Navigator.of(ctx).pushAndRemoveUntil(
                MaterialPageRoute(settings: const RouteSettings(name: 'Dashboard'), builder: (_) => DashboardScreen(userRole: userRole)),
                    (route) => false,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _RoundIconButton(c: c, icon: Icons.edit_rounded, onTap: onEdit),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final AppColors c;
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.c, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: c.blue.withOpacity(0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.blue.withOpacity(0.4), width: 1),
        ),
        child: Icon(icon, color: c.blueLight, size: 17),
      ),
    );
  }
}

class _ProfileHeaderCard extends StatefulWidget {
  final AppColors c;
  final String name, email, role, branch, verifiedLabel, noEmailLabel;
  final String? photoUrl;
  final Uint8List? localPhotoBytes;
  final bool uploading;
  final VoidCallback onEdit;
  final VoidCallback onChangePhoto;
  const _ProfileHeaderCard({
    required this.c, required this.name, required this.email, required this.role,
    required this.branch, required this.verifiedLabel, required this.noEmailLabel,
    required this.photoUrl, required this.localPhotoBytes, required this.uploading,
    required this.onEdit, required this.onChangePhoto,
  });

  @override
  State<_ProfileHeaderCard> createState() => _ProfileHeaderCardState();
}

class _ProfileHeaderCardState extends State<_ProfileHeaderCard> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  String get _initials {
    final parts = widget.name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'A';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  Widget get _initialsFallback => Center(
    child: Text(_initials, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
  );

  /// Just-picked bytes win (instant, no network round-trip). Otherwise try
  /// the stored photoUrl over the network; if that request never lands —
  /// most commonly because the Firebase Storage bucket's CORS config
  /// doesn't allow this web origin, which silently breaks Image.network
  /// on Flutter Web — fall back to the initials instead of hanging.
  Widget _buildAvatarImage() {
    if (widget.localPhotoBytes != null) {
      return Image.memory(
        widget.localPhotoBytes!,
        fit: BoxFit.cover,
        width: 88, height: 88,
        errorBuilder: (_, __, ___) => _initialsFallback,
      );
    }
    if (widget.photoUrl != null && widget.photoUrl!.isNotEmpty) {
      return Image.network(
        widget.photoUrl!,
        fit: BoxFit.cover,
        width: 88, height: 88,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white70),
            ),
          );
        },
        errorBuilder: (_, error, ___) {
          // Surfaces the real cause (e.g. a CORS/XMLHttpRequest error on
          // web) in the debug console instead of failing silently, so
          // it's obvious this is a load failure and not "no photo set".
          debugPrint('Profile photo failed to load: $error');
          return _initialsFallback;
        },
      );
    }
    return _initialsFallback;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, child) => Container(
        margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [c.surface.withOpacity(0.97), c.bgDeep.withOpacity(0.95)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          border: Border.all(color: c.blue.withOpacity(0.28 * _glow.value), width: 1.2),
          boxShadow: [
            BoxShadow(color: c.blue.withOpacity(0.20 * _glow.value), blurRadius: 26, offset: const Offset(0, 8)),
          ],
        ),
        child: child,
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 104, height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [c.blue.withOpacity(0.28), c.blue.withOpacity(0.0)]),
                ),
              ),
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [c.blue, c.blueDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  border: Border.all(color: c.blueLight.withOpacity(0.6), width: 2),
                  boxShadow: [BoxShadow(color: c.blue.withOpacity(0.5), blurRadius: 20, spreadRadius: 2)],
                ),
                child: ClipOval(
                  child: _buildAvatarImage(),
                ),
              ),
              if (widget.uploading)
                Container(
                  width: 88, height: 88,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black45),
                  child: const Center(
                    child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)),
                  ),
                ),
              Positioned(
                right: 0, bottom: 2,
                child: GestureDetector(
                  onTap: widget.uploading ? null : widget.onChangePhoto,
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: c.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.bgDeep, width: 2.5),
                      boxShadow: [BoxShadow(color: c.green.withOpacity(0.5), blurRadius: 8)],
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 13),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(widget.name, style: TextStyle(color: c.textPrimary, fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
          const SizedBox(height: 4),
          Text(widget.email.isEmpty ? widget.noEmailLabel : widget.email, style: TextStyle(color: c.textMuted, fontSize: 12)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 6, alignment: WrapAlignment.center,
            children: [
              _Chip(icon: Icons.badge_rounded, label: widget.role, color: c.blueLight),
              _Chip(icon: Icons.business_rounded, label: widget.branch, color: c.silver),
              _Chip(icon: Icons.verified_rounded, label: widget.verifiedLabel, color: c.green),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 11),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final AppColors c;
  final String label;
  final IconData icon;
  const _SectionHeader({required this.c, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 8),
      child: Row(
        children: [
          Icon(icon, color: c.textMuted, size: 13),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: c.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2.0)),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: c.border, height: 1)),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final AppColors c;
  final List<Widget> children;
  const _SettingsGroup({required this.c, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: c.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Column(
        children: List.generate(children.length, (i) {
          return Column(children: [
            children[i],
            if (i != children.length - 1) Divider(color: c.border, height: 1, indent: 54),
          ]);
        }),
      ),
    );
  }
}

class _SettingsTile extends StatefulWidget {
  final AppColors c;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _SettingsTile({
    required this.c, required this.icon, required this.title, this.subtitle, this.trailing, this.onTap,
  });

  @override
  State<_SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<_SettingsTile> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: InkWell(
        onTap: widget.onTap,
        splashColor: c.blue.withOpacity(0.08),
        highlightColor: Colors.transparent,
        child: Container(
          color: _h ? c.blue.withOpacity(0.05) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: c.blue.withOpacity(0.12), borderRadius: BorderRadius.circular(9)),
                child: Icon(widget.icon, color: c.blueLight, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(widget.subtitle!, style: TextStyle(color: c.textMuted, fontSize: 10.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              widget.trailing ?? (widget.onTap != null ? Icon(Icons.chevron_right_rounded, color: c.textMuted, size: 18) : const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniSwitch extends StatelessWidget {
  final AppColors c;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _MiniSwitch({required this.c, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 42, height: 24,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: value ? c.blue : c.border, borderRadius: BorderRadius.circular(20)),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18, height: 18,
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 3)]),
          ),
        ),
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final AppColors c;
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType? keyboardType;
  const _EditField({required this.c, required this.label, required this.controller, required this.icon, this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: c.textPrimary, fontSize: 13.5),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: c.textMuted, fontSize: 12.5),
        prefixIcon: Icon(icon, color: c.blueLight, size: 17),
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.blue, width: 1.4)),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final AppColors c;
  final String label;
  final VoidCallback onTap;
  const _LogoutButton({required this.c, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: c.red.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.red.withOpacity(0.35), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: c.red, size: 17),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: c.red, fontSize: 14, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _ProfileBackground extends StatefulWidget {
  final bool isDark;
  const _ProfileBackground({required this.isDark});
  @override
  State<_ProfileBackground> createState() => _ProfileBackgroundState();
}

class _ProfileBackgroundState extends State<_ProfileBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat(reverse: true);
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => SizedBox.expand(child: CustomPaint(painter: _ProfileBgPainter(t: _c.value, isDark: widget.isDark))),
    );
  }
}

class _ProfileBgPainter extends CustomPainter {
  final double t;
  final bool isDark;
  _ProfileBgPainter({required this.t, required this.isDark});

  @override
  void paint(Canvas canvas, Size sz) {
    final bgColors = isDark
        ? [const Color(0xFF030710), const Color(0xFF050A14), const Color(0xFF040810)]
        : [const Color(0xFFF7F9FC), const Color(0xFFF2F5FA), const Color(0xFFEDF1F8)];

    canvas.drawRect(Rect.fromLTWH(0, 0, sz.width, sz.height),
        Paint()..shader = LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)
            .createShader(Rect.fromLTWH(0, 0, sz.width, sz.height)));

    final grid = Paint()..color = (isDark ? const Color(0xFF0D2040) : const Color(0xFFD8E0EC)).withOpacity(0.5)..strokeWidth = 0.5;
    for (double x = 0; x < sz.width; x += 32) canvas.drawLine(Offset(x, 0), Offset(x, sz.height), grid);
    for (double y = 0; y < sz.height; y += 32) canvas.drawLine(Offset(0, y), Offset(sz.width, y), grid);

    void glow(double x, double y, double r, Color color, double o) {
      canvas.drawCircle(Offset(x, y), r,
          Paint()..shader = RadialGradient(colors: [color.withOpacity(o), Colors.transparent]).createShader(Rect.fromCircle(center: Offset(x, y), radius: r)));
    }

    final f = isDark ? 1.0 : 0.5;
    glow(sz.width * (0.75 + t * 0.05), sz.height * 0.10, sz.width * 0.42, const Color(0xFF1E5FC8), 0.12 * f);
    glow(sz.width * (0.12 - t * 0.04), sz.height * 0.85, sz.width * 0.32, const Color(0xFF3A7AE8), 0.08 * f);
  }

  @override
  bool shouldRepaint(_ProfileBgPainter old) => old.t != t || old.isDark != isDark;
}