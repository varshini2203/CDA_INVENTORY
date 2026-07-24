// lib/screens/admin/employee_activity_screen.dart
//
// "View Activity" for a single employee — opened from a button on their
// card in Manage Employees. Shows, for that one person only:
//   - every screen/page they visited
//   - every add/edit/delete action they took, with what changed
// newest first, clearly labelled, so the admin doesn't have to hunt for
// them inside the all-users Live Activity Feed.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_access_models.dart';
import '../../services/activity_log_service.dart';

class EmployeeActivityScreen extends StatelessWidget {
  final AppUserAccess user;
  const EmployeeActivityScreen({super.key, required this.user});

  static const _bg = Color(0xFF050A14);
  static const _card = Color(0xFF0A1428);
  static const _border = Color(0xFF1A2E50);
  static const _blue = Color(0xFF1E5FC8);

  static const _green = Color(0xFF2ECC71); // added
  static const _amber = Color(0xFFF5A623); // edited
  static const _red = Color(0xFFE74C3C); // deleted
  static const _purple = Color(0xFF9B59B6); // page visit

  static final _dateFmt = DateFormat('d MMM yyyy, h:mm a');

  String _timeAgo(DateTime? dt) {
    if (dt == null) return 'just now';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  bool _isPageVisit(ActivityLogModel log) => log.kind == 'screen_visit';

  IconData _iconFor(ActivityLogModel log) {
    if (_isPageVisit(log)) return Icons.visibility_outlined;
    switch (log.action) {
      case 'added':
        return Icons.add_circle_outline_rounded;
      case 'edited':
        return Icons.edit_outlined;
      case 'deleted':
        return Icons.delete_outline_rounded;
      default:
        return Icons.bolt_rounded;
    }
  }

  Color _colorFor(ActivityLogModel log) {
    if (_isPageVisit(log)) return _purple;
    switch (log.action) {
      case 'added':
        return _green;
      case 'edited':
        return _amber;
      case 'deleted':
        return _red;
      default:
        return Colors.amber;
    }
  }

  /// What kind of row this is, shown as a clear label ("Page visited" /
  /// "Action") so the admin never has to guess from the sentence alone.
  String _kindLabel(ActivityLogModel log) {
    if (_isPageVisit(log)) return 'Page visited';
    switch (log.action) {
      case 'added':
        return 'Added';
      case 'edited':
        return 'Edited';
      case 'deleted':
        return 'Deleted';
      default:
        return 'Action';
    }
  }

  /// The specific page name for a screen-visit row, or the module/item
  /// for an action row — this is the piece the admin actually wants at a
  /// glance: WHERE, in the app, did this happen.
  String _whereText(ActivityLogModel log) {
    if (_isPageVisit(log)) return log.label;
    if (log.itemName != null && log.module != null) {
      return '${log.itemName} · ${log.module}';
    }
    return log.module ?? log.itemName ?? log.label;
  }

  String _formatValue(dynamic v) {
    if (v == null || v == '') return '—';
    if (v is double) {
      return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
    }
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = user.name.isNotEmpty ? user.name : user.email;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        // Made transparent — the employee's avatar/name/email now live in
        // the hero banner below instead of the AppBar title, matching the
        // Pending Requests / Manage Employees screens.
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // ── Hero banner — same drone/sunset artwork as the other admin
          // screens, with this employee's avatar/name/email overlaid
          // instead of a generic title, so it's immediately clear whose
          // activity trail this is. ────────────────────────────────────
          Container(
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
                    alignment: const Alignment(0, -0.6),
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.20),
                          Colors.black.withOpacity(0.60),
                          Colors.black.withOpacity(0.85),
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
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: _blue.withOpacity(0.3),
                        child: Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(displayName,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(user.email,
                                style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildStatusHeader(),
          const Divider(height: 1, color: _border),
          Expanded(
            child: StreamBuilder<List<ActivityLogModel>>(
              stream: ActivityLogService.streamForUser(user.uid),
              builder: (context, snapshot) {
                if (!snapshot.hasData && !snapshot.hasError) {
                  return const Center(child: CircularProgressIndicator(color: _blue));
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_off_rounded, size: 40, color: Colors.white.withOpacity(0.3)),
                          const SizedBox(height: 12),
                          Text(
                            'Could not load activity.\n${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white.withOpacity(0.5)),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final logs = snapshot.data!;
                if (logs.isEmpty) {
                  return Center(
                    child: Text('No activity from $displayName yet',
                        style: TextStyle(color: Colors.white.withOpacity(0.4))),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: logs.length,
                  itemBuilder: (context, i) => _buildLogCard(logs[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: _card,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: user.isOnline ? _green : Colors.white24,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            user.isOnline ? 'Online now' : 'Offline',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 14),
          Icon(Icons.login_rounded, size: 14, color: Colors.white.withOpacity(0.4)),
          const SizedBox(width: 4),
          Text(
            user.lastLogin != null
                ? 'Last login ${_dateFmt.format(user.lastLogin!)}'
                : 'No login recorded yet',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(ActivityLogModel log) {
    final color = _colorFor(log);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_iconFor(log), size: 14, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Clear "kind" label first (Page visited / Added / Edited / Deleted)
                      Row(
                        children: [
                          _pill(_kindLabel(log), color.withOpacity(0.18), color),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _whereText(log),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        log.timestamp != null ? _dateFmt.format(log.timestamp!) : '—',
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Text(
                  _timeAgo(log.timestamp),
                  style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10),
                ),
              ],
            ),
            if (log.hasChanges) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: log.changes!.entries.map((e) {
                    final v = e.value as Map<String, dynamic>;
                    final oldV = _formatValue(v['old']);
                    final newV = _formatValue(v['new']);

                    List<InlineSpan> valueSpans;
                    if (log.action == 'deleted') {
                      valueSpans = [
                        TextSpan(
                          text: oldV,
                          style: const TextStyle(
                              color: Colors.redAccent, decoration: TextDecoration.lineThrough),
                        ),
                      ];
                    } else if (log.action == 'added') {
                      valueSpans = [
                        TextSpan(
                          text: newV,
                          style: const TextStyle(color: _green, fontWeight: FontWeight.w600),
                        ),
                      ];
                    } else {
                      valueSpans = [
                        TextSpan(
                          text: oldV,
                          style: TextStyle(
                              color: Colors.redAccent.withOpacity(0.85),
                              decoration: TextDecoration.lineThrough),
                        ),
                        const TextSpan(text: '  →  ', style: TextStyle(color: Colors.white38)),
                        TextSpan(
                          text: newV,
                          style: const TextStyle(color: _green, fontWeight: FontWeight.w600),
                        ),
                      ];
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 12),
                          children: [
                            TextSpan(
                              text: '${e.key}: ',
                              style: const TextStyle(
                                  color: Colors.white70, fontWeight: FontWeight.w600),
                            ),
                            ...valueSpans,
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}