// lib/screens/admin/admin_notifications_screen.dart
//
// "Pending Requests" page for the admin — the single place to see every
// employee currently waiting for access and act on them.
//
// Data source: users/{uid} where role == 'employee' && accessStatus ==
// 'pending', streamed live via AccessControlService.streamPendingUsers().
// Reading straight from the user's own document (rather than the
// admin_notifications log) means this list can never drift out of sync
// with what the employee's Waiting-for-Approval screen is showing them.
//
// Security: this whole screen is only reachable by the admin — Firestore
// rules block a non-admin from reading these documents at all (isAdmin()
// in firestore.rules), and main.dart wraps the route in an AdminGuard as
// defense-in-depth on the client side too.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_access_models.dart';
import '../../services/access_control_service.dart';
import 'admin_hero_banner.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  static const _bg = Color(0xFFF2F5FA);
  static const _card = Colors.white;
  static const _border = Color(0xFFD5DFEE);
  static const _blue = Color(0xFF1E5FC8);

  final _searchCtrl = TextEditingController();
  String _query = '';

  // Which status tab is selected. 'pending' keeps the original behaviour;
  // 'approved'/'rejected'/'all' let the admin see requests that were
  // already acted on instead of them just disappearing forever.
  String _statusFilter = 'pending';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Case-insensitive filter across name + email. Empty query = show all.
  List<AppUserAccess> _filter(List<AppUserAccess> items) {
    var out = items;
    if (_statusFilter != 'all') {
      out = out.where((u) => accessStatusToString(u.accessStatus) == _statusFilter).toList();
    }
    if (_query.trim().isEmpty) return out;
    final q = _query.trim().toLowerCase();
    return out
        .where((u) => u.name.toLowerCase().contains(q) || u.email.toLowerCase().contains(q))
        .toList();
  }

  // ── Hero banner ──────────────────────────────────────────────────────
  // Drone/sunset artwork with the page title + subtitle overlaid, matching
  // the reference mockup. Pulled into its own method (rather than inline
  // in build()) so it can sit in a SliverToBoxAdapter and scroll away with
  // the rest of the page — see the note at the bottom of this file.
  Widget _buildHeroBanner() {
    return const AdminHeroBanner(
      bottomLeft: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Pending Requests',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 3),
          Text(
            'Review and manage access requests',
            style: TextStyle(color: Colors.white, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  // ── Status tabs ──────────────────────────────────────────────────────
  // Pending is the default view (unchanged behaviour), but
  // Approved/Rejected/All let the admin look back at requests that were
  // already acted on instead of them just disappearing the moment they're
  // approved or rejected.
  Widget _buildStatusTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Row(
        children: [
          _StatusTab(
            label: 'Pending',
            selected: _statusFilter == 'pending',
            color: Color(0xFFB7791F),
            onTap: () => setState(() => _statusFilter = 'pending'),
          ),
          const SizedBox(width: 8),
          _StatusTab(
            label: 'Approved',
            selected: _statusFilter == 'approved',
            color: Color(0xFF15803D),
            onTap: () => setState(() => _statusFilter = 'approved'),
          ),
          const SizedBox(width: 8),
          _StatusTab(
            label: 'Rejected',
            selected: _statusFilter == 'rejected',
            color: Color(0xFFDC2626),
            onTap: () => setState(() => _statusFilter = 'rejected'),
          ),
          const SizedBox(width: 8),
          _StatusTab(
            label: 'All',
            selected: _statusFilter == 'all',
            color: _blue,
            onTap: () => setState(() => _statusFilter = 'all'),
          ),
        ],
      ),
    );
  }

  // ── Search bar ────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v),
        style: const TextStyle(color: Color(0xFF111827), fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search by name or email',
          hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF9CA3AF), size: 20),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFF9CA3AF), size: 18),
            onPressed: () => setState(() {
              _searchCtrl.clear();
              _query = '';
            }),
          ),
          filled: true,
          fillColor: _card,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _blue.withOpacity(0.7)),
          ),
        ),
      ),
    );
  }

  // Slivers that are always present regardless of stream state — hero
  // banner, status tabs, search bar. Kept as one list so every branch
  // below (loading / error / empty / data) includes them and the whole
  // page always scrolls as a single CustomScrollView.
  List<Widget> _headerSlivers() {
    return [
      SliverToBoxAdapter(child: _buildHeroBanner()),
      SliverToBoxAdapter(child: _buildStatusTabs()),
      SliverToBoxAdapter(child: _buildSearchBar()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
      ),
      // A single CustomScrollView for the ENTIRE page (hero banner, status
      // tabs, search bar, and the requests list) — everything scrolls
      // together as one unit, same as the dashboard screen. Previously
      // the banner + tabs + search bar lived in a fixed Column with only
      // the requests list wrapped in its own scrollable ListView beneath
      // them; that meant the top section never moved and the list only
      // scrolled within the leftover space below it.
      body: StreamBuilder<List<AppUserAccess>>(
        stream: AccessControlService.streamAllEmployees(),
        builder: (context, snapshot) {
          // ── Loading state ──
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                ..._headerSlivers(),
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
          // ── Error state ──
          if (snapshot.hasError) {
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                ..._headerSlivers(),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load requests.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ),
                ),
              ],
            );
          }

          final items = _filter(snapshot.data ?? const []);

          // ── Empty state (label matches the selected tab) ──
          if (items.isEmpty) {
            final label = switch (_statusFilter) {
              'approved' => 'No approved requests.',
              'rejected' => 'No rejected requests.',
              'all' => 'No requests yet.',
              _ => 'No pending approval requests.',
            };
            return RefreshIndicator(
              color: _blue,
              onRefresh: () async {
                // StreamBuilder is already live; this just gives the
                // user a tactile "sync" gesture to pull.
                await Future.delayed(const Duration(milliseconds: 400));
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  ..._headerSlivers(),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_rounded, size: 48, color: Color(0xFF9CA3AF)),
                        const SizedBox(height: 12),
                        Text(
                          label,
                          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: _blue,
            onRefresh: () async {
              await Future.delayed(const Duration(milliseconds: 400));
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                ..._headerSlivers(),
                SliverPadding(
                  padding: const EdgeInsets.all(14),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, i) => Padding(
                        padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 10),
                        child: _PendingRequestCard(user: items[i]),
                      ),
                      childCount: items.length,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One selectable status tab (Pending / Approved / Rejected / All).
class _StatusTab extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _StatusTab({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? color : Color(0xFFD5DFEE)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: selected ? color : Color(0xFF6B7280),
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingRequestCard extends StatefulWidget {
  final AppUserAccess user;
  const _PendingRequestCard({required this.user});

  @override
  State<_PendingRequestCard> createState() => _PendingRequestCardState();
}

class _PendingRequestCardState extends State<_PendingRequestCard> {
  static const _card = Colors.white;
  static const _border = Color(0xFFD5DFEE);
  static const _blue = Color(0xFF1E5FC8);

  bool _busy = false;

  String get _registeredLabel {
    final d = widget.user.createdAt;
    if (d == null) return 'Unknown';
    return DateFormat('MMM d, yyyy • h:mm a').format(d);
  }

  // ── Approve as Viewer / Editor ──────────────────────────────────
  Future<void> _approve(AccessLevel level) async {
    setState(() => _busy = true);
    try {
      await AccessControlService.approveAccess(userId: widget.user.uid, level: level);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.user.name} approved as ${accessLevelToString(level)}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not approve: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Reject ───────────────────────────────────────────────────────
  Future<void> _reject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _card,
        title: const Text('Reject request?', style: TextStyle(color: Color(0xFF111827))),
        content: Text(
          '${widget.user.name} will not be able to access the app unless approved again later.',
          style: TextStyle(color: Color(0xFF374151)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reject', style: TextStyle(color: Color(0xFFDC2626))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await AccessControlService.rejectAccess(userId: widget.user.uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.user.name} rejected')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not reject: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final status = accessStatusToString(user.accessStatus); // 'pending' | 'approved' | 'rejected'
    final isPending = status == 'pending';
    final badgeColor = switch (status) {
      'approved' => Color(0xFF15803D),
      'rejected' => Color(0xFFDC2626),
      _ => Color(0xFFB7791F),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _blue.withOpacity(0.2),
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name.isNotEmpty ? user.name : 'Unnamed',
                        style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(user.email,
                        style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeColor.withOpacity(0.4)),
                ),
                child: Text(status.toUpperCase(),
                    style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.event_rounded, size: 13, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 5),
              Text('Registered: $_registeredLabel',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11.5)),
            ],
          ),
          const SizedBox(height: 14),
          if (_busy)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _blue),
                ),
              ),
            )
          else if (!isPending)
          // Already decided — show what was decided plus a way to
          // change their mind, instead of hiding this request entirely.
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _approve(AccessLevel.viewer),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Color(0xFFB7791F),
                      side: const BorderSide(color: Color(0xFFB7791F)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Re-approve Viewer', style: TextStyle(fontSize: 12.5)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _approve(AccessLevel.editor),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _blue,
                      side: BorderSide(color: _blue),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Re-approve Editor', style: TextStyle(fontSize: 12.5)),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Reject', style: TextStyle(fontSize: 12.5)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _approve(AccessLevel.viewer),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Color(0xFFB7791F),
                      side: const BorderSide(color: Color(0xFFB7791F)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Approve Viewer', style: TextStyle(fontSize: 12.5)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _approve(AccessLevel.editor),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Approve Editor', style: TextStyle(fontSize: 12.5)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}