// lib/screens/admin/employee_access_screen.dart
//
// Full employee roster for the admin, with live access-level control.
// Existing/legacy employees default to Viewer (via the one-tap "Sync
// legacy users" action); the admin manually promotes anyone who needs
// Editor access, or revokes access entirely.

import 'package:flutter/material.dart';

import '../../models/app_access_models.dart';
import '../../services/access_control_service.dart';
import 'employee_activity_screen.dart';

class EmployeeAccessScreen extends StatelessWidget {
  const EmployeeAccessScreen({super.key});

  static const _bg = Color(0xFF050A14);
  static const _card = Color(0xFF0A1428);
  static const _border = Color(0xFF1A2E50);
  static const _blue = Color(0xFF1E5FC8);

  Future<void> _syncLegacyUsers(BuildContext context) async {
    final count = await AccessControlService.migrateLegacyUsersToViewer();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$count existing employee(s) set to Viewer access')),
    );
  }

  // ── Hero banner ──────────────────────────────────────────────────────
  // Same drone/sunset artwork (pending.png) used on the Pending Requests
  // screen, with the page title + subtitle overlaid, and the "sync legacy
  // users" action pinned as a small circular button in the top-right
  // corner of the banner.
  //
  // Pulled into its own method (rather than inline in build()) so it can
  // sit in a SliverToBoxAdapter and scroll away with the rest of the page
  // — see the note at the bottom of this file for why that matters.
  Widget _buildHeroBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 220,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 4),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: _card,
        border: Border.all(color: _border),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/pending.png',
              fit: BoxFit.cover,
              // Bias toward the drone/skyline band of the tall
              // portrait photo — a short wide crop can't show the
              // whole image, so favor the recurring hero subject,
              // same as the other admin-screen banners.
              alignment: const Alignment(0, -0.6),
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          // Dark scrim, heaviest at the bottom where the title sits.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.15),
                    Colors.black.withOpacity(0.55),
                    Colors.black.withOpacity(0.80),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Manage Employees',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'View employees and control their access levels',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          // "Sync legacy users" — small circular button pinned to
          // the top-right corner of the banner instead of a plain
          // AppBar action, so the transparent AppBar above stays
          // uncluttered (just the back arrow).
          Positioned(
            top: 12,
            right: 12,
            child: Material(
              color: Colors.black.withOpacity(0.35),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _syncLegacyUsers(context),
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Tooltip(
                    message: 'Give every un-configured existing employee Viewer access',
                    child: Icon(Icons.sync_rounded,
                        color: Colors.white.withOpacity(0.9), size: 19),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        // Transparent — the page title/subtitle now live in the hero
        // banner below instead of a plain AppBar title, matching the
        // Pending Requests screen's treatment.
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // A single CustomScrollView for the ENTIRE page (hero banner + the
      // employee list) — everything scrolls together as one unit, same
      // as the dashboard screen. Previously the hero banner lived in a
      // fixed Column with only the employee list wrapped in its own
      // scrollable ListView beneath it; that meant the banner never
      // moved and the list only scrolled within the leftover space below
      // it, which read as "the page isn't scrolling" whenever the
      // banner + list together were taller than the screen.
      body: StreamBuilder<List<AppUserAccess>>(
        stream: AccessControlService.streamAllEmployees(),
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeroBanner(context)),
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator(color: _blue)),
                  ),
                ),
              ],
            );
          }
          if (snapshot.hasError) {
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeroBanner(context)),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off_rounded, size: 40, color: Colors.white.withOpacity(0.3)),
                        const SizedBox(height: 12),
                        Text(
                          'Could not load employees.\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withOpacity(0.5)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          final users = snapshot.data!;
          if (users.isEmpty) {
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeroBanner(context)),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text('No employees yet',
                        style: TextStyle(color: Colors.white.withOpacity(0.4))),
                  ),
                ),
              ],
            );
          }
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeroBanner(context)),
              SliverPadding(
                padding: const EdgeInsets.all(14),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, i) => Padding(
                      padding: EdgeInsets.only(bottom: i == users.length - 1 ? 0 : 10),
                      child: _EmployeeCard(user: users[i]),
                    ),
                    childCount: users.length,
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

class _EmployeeCard extends StatelessWidget {
  final AppUserAccess user;
  const _EmployeeCard({required this.user});

  Color get _dotColor {
    switch (user.accessLevel) {
      case AccessLevel.editor:
        return Colors.greenAccent;
      case AccessLevel.viewer:
        return Colors.amber;
      case AccessLevel.none:
        return Colors.white24;
    }
  }

  Future<void> _setLevel(BuildContext context, AccessLevel level) async {
    // NOTE: AccessControlService.setAccessLevel() already writes a proper
    // feed entry (module: 'Employees', with an access_level before/after
    // diff) for this exact change. There used to be a second logAction()
    // call here too, which meant every single Viewer/Editor click wrote
    // two rows to the Live Activity Feed for the same click — one under
    // "Employees" and a near-duplicate under "Access Control".
    await AccessControlService.setAccessLevel(userId: user.uid, level: level);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: EmployeeAccessScreen._card,
        title: const Text('Remove employee?', style: TextStyle(color: Colors.white)),
        content: Text(
          'This will permanently remove ${user.name.isNotEmpty ? user.name : user.email} '
              'and revoke all their access. This cannot be undone.',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      await AccessControlService.removeEmployee(user.uid);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.name.isNotEmpty ? user.name : user.email} removed')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove employee: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EmployeeAccessScreen._card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: EmployeeAccessScreen._border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: avatar, name/email/status, and the small "View"
          // (activity) button pinned to the top-right corner of the card.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: EmployeeAccessScreen._blue.withOpacity(0.2),
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (user.isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: EmployeeAccessScreen._card, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name.isNotEmpty ? user.name : user.email,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    Text(user.email,
                        style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(color: _dotColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${accessLevelToString(user.accessLevel)} · ${accessStatusToString(user.accessStatus)}',
                          style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // "View" — shows this employee's name together with every
              // page they visited and every action they took. Small and
              // pinned top-right, exactly where it's sketched.
              _ViewButton(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    settings: const RouteSettings(name: 'Employee Activity'),
                    builder: (_) => EmployeeActivityScreen(user: user),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // "Delete" — permanently removes the employee (with a
              // confirmation dialog first). Pinned top-right next to View.
              _DeleteButton(onTap: () => _confirmDelete(context)),
            ],
          ),
          const SizedBox(height: 12),
          // ── Bottom row: Viewer / Editor / Revoke as three always-visible
          // buttons instead of a hidden 3-dot menu. The one matching the
          // employee's current access level is filled/highlighted.
          Row(
            children: [
              Expanded(
                child: _AccessButton(
                  label: 'Viewer',
                  active: user.accessLevel == AccessLevel.viewer,
                  color: Colors.amber,
                  onTap: () => _setLevel(context, AccessLevel.viewer),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AccessButton(
                  label: 'Editor',
                  active: user.accessLevel == AccessLevel.editor,
                  color: Colors.greenAccent,
                  onTap: () => _setLevel(context, AccessLevel.editor),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AccessButton(
                  label: 'Revoke',
                  active: user.accessLevel == AccessLevel.none,
                  color: Colors.redAccent,
                  onTap: () => _setLevel(context, AccessLevel.none),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small pill button pinned top-right of the card — opens the
/// per-employee activity trail (pages visited + actions taken).
class _ViewButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ViewButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: EmployeeAccessScreen._blue.withOpacity(0.14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: EmployeeAccessScreen._blue.withOpacity(0.5)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_rounded, size: 13, color: EmployeeAccessScreen._blue),
              SizedBox(width: 4),
              Text('View', style: TextStyle(fontSize: 11, color: EmployeeAccessScreen._blue, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small pill button pinned top-right of the card, next to "View" —
/// permanently deletes the employee after a confirmation dialog.
class _DeleteButton extends StatelessWidget {
  final VoidCallback onTap;
  const _DeleteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline_rounded, size: 13, color: Colors.redAccent),
              SizedBox(width: 4),
              Text('Delete', style: TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the three inline access-level buttons (Viewer / Editor / Revoke).
/// Filled with [color] when it's the employee's current access level,
/// outlined otherwise — so the active state is obvious at a glance without
/// needing to open anything.
class _AccessButton extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _AccessButton({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? color.withOpacity(0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? color : Colors.white24),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: active ? color : Colors.white60,
              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}