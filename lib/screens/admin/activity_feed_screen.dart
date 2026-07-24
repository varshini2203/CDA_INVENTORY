// lib/screens/admin/activity_feed_screen.dart
//
// "Whatever happens in the app should be visible to the admin" — this is
// that screen. Live feed of every screen visit and every logged action
// (added / edited / deleted) across all users, showing WHO did it, WHICH
// module, WHAT item, WHEN, and exactly WHAT CHANGED.
//
// Filterable by user, by module, and by time range (Today / This Week /
// This Month / All time), sortable newest-first or oldest-first, grouped
// under date headers, and pageable via "Load more" so long history is
// paged rather than ever hidden.
//
// Nothing here is ever deleted automatically — there is no auto-expiry,
// no background pruning, nothing. The ONLY way an entry disappears is an
// admin explicitly tapping the trash icon on a single entry, or the bulk
// "delete what's shown" action in the app bar, and both require a typed
// confirmation before anything is removed. (See notes at the bottom of
// this file about the two real bugs that were actually causing entries
// to look wrong/duplicated — this screen itself was never deleting
// anything on its own.)
//
// UI PASS: same light theme as the Search Products screen (off-white
// page, white cards, dark navy app bar), reworked for clearer visual
// hierarchy — a stats strip, circular action-colored icon badges, pill
// tags, a cleaner diff box for edits, and a sticky filter panel.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_access_models.dart';
import '../../services/access_control_service.dart';
import '../../services/activity_log_service.dart';

enum _TimeRange { all, today, week, month }

enum _SortOrder { newest, oldest }

// NEW: drives the four clickable summary cards (Total / Added / Edited /
// Deleted). Kept as its own enum (rather than reusing `action` strings)
// so `total` has an explicit "no filter" meaning distinct from null.
enum ActivityTypeFilter { total, added, edited, deleted }

class ActivityFeedScreen extends StatefulWidget {
  const ActivityFeedScreen({super.key});

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen> {
  // ── Palette — matches the Manage Employees screen. ───────────────────────
  static const _bg = Color(0xFF050A14);
  static const _card = Color(0xFF0A1428);
  static const _chipFill = Color(0xFF101B33);
  static const _chipSelected = Color(0xFF1E5FC8);
  static const _border = Color(0xFF1A2E50);
  static const _blue = Color(0xFF1E5FC8);
  static const _textPrimary = Colors.white;
  static const _textSecondary = Color(0xFFB8C2D9);
  static const _textFaint = Color(0xFF6B7A99);

  static const _green = Color(0xFF2ECC71); // added
  static const _amber = Color(0xFFF5A623); // edited
  static const _red = Color(0xFFE74C3C); // deleted
  static const _grey = Color(0xFF6B7A99); // screen visit / other

  // The complete, real set of modules that log activity anywhere in this
  // app (matches the `module:` string passed to ActivityLogService.logAdd/
  // logEdit/logDelete in every *_service.dart file). Shown as filter chips
  // up front, merged with anything already seen in the feed — so an admin
  // can filter by, say, "Purchase Orders" even on day one, before any
  // purchase order has been touched yet.
  static const _kAllModules = [
    'Bills',
    'Branch Inventory',
    'Consumables',
    'Drones',
    'Employees',
    'Fixed Assets',
    'Invoices',
    'Payments Out',
    'Purchase Orders',
    'Purchase Returns',
    'Purchases',
    'Stock',
  ];

  String? _filterUid; // null = everyone
  String? _filterModule; // null = all modules
  _TimeRange _range = _TimeRange.all;
  _SortOrder _sort = _SortOrder.newest;

  // NEW: which summary card is currently selected. Defaults to `total`,
  // i.e. no action filter applied — matches the previous (pre-change)
  // behavior of the screen.
  ActivityTypeFilter _actionFilter = ActivityTypeFilter.total;

  // Nothing is ever truncated permanently — this is just how many recent
  // docs the current Firestore listener has pulled. "Load more" bumps it
  // and re-subscribes with a bigger window; every entry is still sitting
  // in Firestore the whole time regardless of this number.
  static const int _pageStep = 300;
  int _visibleLimit = _pageStep;

  bool _bulkDeleting = false;
  final Set<String> _rowsBeingDeleted = {};

  final _dateFmt = DateFormat('d MMM yyyy, h:mm a');
  final _dayHeaderFmt = DateFormat('EEEE, d MMM yyyy');

  String _timeAgo(DateTime? dt) {
    if (dt == null) return 'just now';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ── Time-range filtering ───────────────────────────────────────────────

  DateTime? _rangeStart() {
    final now = DateTime.now();
    switch (_range) {
      case _TimeRange.all:
        return null;
      case _TimeRange.today:
        return DateTime(now.year, now.month, now.day);
      case _TimeRange.week:
        final startOfToday = DateTime(now.year, now.month, now.day);
        // Monday as the first day of the week.
        return startOfToday.subtract(Duration(days: now.weekday - 1));
      case _TimeRange.month:
        return DateTime(now.year, now.month, 1);
    }
  }

  String _dayHeaderFor(DateTime dt) {
    final now = DateTime.now();
    final d = DateTime(dt.year, dt.month, dt.day);
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (d == today) return 'Today';
    if (d == yesterday) return 'Yesterday';
    return _dayHeaderFmt.format(dt);
  }

  // ── Presentation helpers ──────────────────────────────────────────────

  IconData _iconFor(ActivityLogModel log) {
    switch (log.action) {
      case 'added':
        return Icons.add_rounded;
      case 'edited':
        return Icons.edit_outlined;
      case 'deleted':
        return Icons.delete_outline_rounded;
      default:
        return log.kind == 'screen_visit'
            ? Icons.visibility_outlined
            : Icons.bolt_rounded;
    }
  }

  Color _colorFor(ActivityLogModel log) {
    switch (log.action) {
      case 'added':
        return _green;
      case 'edited':
        return _amber;
      case 'deleted':
        return _red;
      default:
        return log.kind == 'screen_visit' ? _grey : Colors.amber;
    }
  }

  /// The main, human-readable line: "Sudharshan added DJI Mavic 3 in Drones"
  String _sentenceFor(ActivityLogModel log) {
    if (log.action != null && log.itemName != null) {
      final verb = switch (log.action) {
        'added' => 'added',
        'edited' => 'edited',
        'deleted' => 'deleted',
        _ => log.action!,
      };
      final where = log.module != null ? ' in ${log.module}' : '';
      return '${log.userName} $verb ${log.itemName}$where';
    }
    if (log.kind == 'screen_visit') {
      return '${log.userName} viewed ${log.label}';
    }
    // Legacy / generic logAction rows: label is already human-readable,
    // e.g. "[Employee Access] Approved editor access".
    return '${log.userName} — ${log.label}';
  }

  String _formatValue(dynamic v) {
    if (v == null || v == '') return '—';
    if (v is double) {
      return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
    }
    return v.toString();
  }

  // ── Delete actions ─────────────────────────────────────────────────────

  Future<void> _confirmDeleteOne(ActivityLogModel log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _border),
        ),
        title: const Text('Delete this entry?',
            style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          _sentenceFor(log),
          style: const TextStyle(color: _textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _rowsBeingDeleted.add(log.id));
    try {
      await ActivityLogService.deleteLog(log.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _rowsBeingDeleted.remove(log.id));
    }
  }

  Future<void> _confirmBulkDelete(List<ActivityLogModel> visibleLogs) async {
    if (visibleLogs.isEmpty || _bulkDeleting) return;
    final count = visibleLogs.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _border),
        ),
        title: const Text('Delete these entries?',
            style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'This deletes all $count activit${count == 1 ? 'y' : 'ies'} currently '
              'shown (matching your user / module / time filters). This cannot be undone.',
          style: const TextStyle(color: _textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete $count'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _bulkDeleting = true);
    try {
      await ActivityLogService.deleteLogs(visibleLogs.map((l) => l.id).toList());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted $count entries')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bulk delete failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _bulkDeleting = false);
    }
  }

  // ── Hero banner ──────────────────────────────────────────────────────
  // Same drone/sunset artwork (pending.png) used on the Manage Employees
  // screen, with the page title + subtitle overlaid, and the sort toggle
  // pinned as a small pill in the top-right corner of the banner.
  //
  // Pulled out into its own method (rather than inline in build()) so it
  // can be dropped into a CustomScrollView as a SliverToBoxAdapter and
  // scroll away with everything else — see the "why this screen wasn't
  // scrolling" note at the bottom of this file.
  Widget _buildHeroBanner() {
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
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
                    ),
                    const Text(
                      'Live Activity Feed',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  'Every screen visit and change, across every user',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          // Sort toggle — small pill pinned to the top-right corner
          // of the banner instead of a plain AppBar action, so the
          // transparent AppBar above stays uncluttered (just the
          // back arrow), same treatment as the "sync legacy users"
          // button on the Manage Employees screen.
          Positioned(
            top: 12,
            right: 12,
            child: Material(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => setState(() {
                  _sort = _sort == _SortOrder.newest ? _SortOrder.oldest : _SortOrder.newest;
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _sort == _SortOrder.newest
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        size: 15,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _sort == _SortOrder.newest ? 'Newest' : 'Oldest',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Top filter bars (user + time range) ────────────────────────────────
  // Also pulled out so it can sit in a SliverToBoxAdapter alongside the
  // hero banner.
  Widget _buildTopFilterBars() {
    return Container(
      color: _card,
      child: Column(
        children: [
          _buildUserFilterBar(),
          _buildRangeFilterBar(),
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
        // Manage Employees screen's treatment.
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // A single CustomScrollView for the ENTIRE page (hero banner, both
      // filter bars, the module chips, the stats strip, the toolbar, and
      // the log list) — everything scrolls together as one unit, exactly
      // like the dashboard screen. Previously the hero banner + user/range
      // filter bars lived directly in a fixed Column with only the log
      // list wrapped in its own scrollable ListView; that meant the top
      // section never moved and the list itself only scrolled once its
      // content overflowed the *remaining* space beneath the fixed header,
      // which felt like "the page isn't scrolling" when the header alone
      // was taller than the screen. See the note at the bottom of this
      // file for the full explanation.
      body: StreamBuilder<List<ActivityLogModel>>(
        // A single listener for everyone's recent activity. The user,
        // module, and time-range filters are all applied client-side
        // below — this avoids a second Firestore listener (and the
        // composite index a where()+orderBy() on a different field
        // would need).
        stream: ActivityLogService.streamRecent(limit: _visibleLimit),
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeroBanner()),
                SliverToBoxAdapter(child: _buildTopFilterBars()),
                const SliverToBoxAdapter(child: Divider(height: 1, color: _border)),
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
                SliverToBoxAdapter(child: _buildHeroBanner()),
                SliverToBoxAdapter(child: _buildTopFilterBars()),
                const SliverToBoxAdapter(child: Divider(height: 1, color: _border)),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 40, color: _textFaint),
                        const SizedBox(height: 12),
                        Text(
                          'Could not load the activity feed.\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: _textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          final allLogs = snapshot.data!;

          // Every known module, plus anything seen in the logs that
          // isn't in the master list yet (e.g. a newly-wired module) —
          // so filter chips are available from day one, not only once
          // that module has an actual entry.
          final modules = <String>{
            ..._kAllModules,
            for (final l in allLogs)
              if (l.module != null && l.module!.isNotEmpty) l.module!,
          }.toList()
            ..sort();

          var logs = _filterUid == null
              ? allLogs
              : allLogs.where((l) => l.userId == _filterUid).toList();
          logs = _filterModule == null
              ? logs
              : logs.where((l) => l.module == _filterModule).toList();

          final rangeStart = _rangeStart();
          if (rangeStart != null) {
            logs = logs
                .where((l) => l.timestamp != null && !l.timestamp!.isBefore(rangeStart))
                .toList();
          }

          // NEW: `logs` at this point already reflects the user,
          // module, and time filters — but NOT the action/type filter
          // yet. Snapshot it here so the stats-strip counts (below)
          // always show "how many would match if you picked this
          // card", regardless of which card is currently selected.
          final logsBeforeActionFilter = logs;

          // Quick counts for the stats strip — added/edited/deleted
          // within the currently-filtered set (user/module/time),
          // independent of which summary card is selected.
          final addedCount = logsBeforeActionFilter.where((l) => l.action == 'added').length;
          final editedCount = logsBeforeActionFilter.where((l) => l.action == 'edited').length;
          final deletedCount = logsBeforeActionFilter.where((l) => l.action == 'deleted').length;

          // NEW: apply the selected summary-card filter (Total / Added
          // / Edited / Deleted) on top of the existing user/module/
          // time filters. `total` means "no additional filter".
          switch (_actionFilter) {
            case ActivityTypeFilter.total:
              break; // no-op, keep everything
            case ActivityTypeFilter.added:
              logs = logsBeforeActionFilter.where((l) => l.action == 'added').toList();
              break;
            case ActivityTypeFilter.edited:
              logs = logsBeforeActionFilter.where((l) => l.action == 'edited').toList();
              break;
            case ActivityTypeFilter.deleted:
              logs = logsBeforeActionFilter.where((l) => l.action == 'deleted').toList();
              break;
          }

          // allLogs already comes newest-first from Firestore.
          if (_sort == _SortOrder.oldest) {
            logs = logs.reversed.toList();
          }

          final hasMoreToLoad = allLogs.length >= _visibleLimit;
          final filtersActive = _filterUid != null ||
              _filterModule != null ||
              _range != _TimeRange.all ||
              _actionFilter != ActivityTypeFilter.total;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeroBanner()),
              SliverToBoxAdapter(child: _buildTopFilterBars()),
              const SliverToBoxAdapter(child: Divider(height: 1, color: _border)),
              SliverToBoxAdapter(
                child: Container(color: _card, child: _buildModuleFilterBar(modules)),
              ),
              const SliverToBoxAdapter(child: Divider(height: 1, color: _border)),
              SliverToBoxAdapter(
                child: _buildStatsStrip(
                  // NEW: total now comes from logsBeforeActionFilter
                  // (not the action-filtered `logs`), so the "Total"
                  // card always shows the true total for the current
                  // user/module/time filters, even while another card
                  // (e.g. Edited) is selected and `logs` is narrowed.
                  total: logsBeforeActionFilter.length,
                  added: addedCount,
                  edited: editedCount,
                  deleted: deletedCount,
                ),
              ),
              SliverToBoxAdapter(child: _buildToolbar(logs)),
              if (logs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_outlined,
                              size: 42, color: _textFaint.withOpacity(0.6)),
                          const SizedBox(height: 10),
                          Text(
                            filtersActive
                                ? 'No activity matches these filters'
                                : 'No activity yet',
                            style: const TextStyle(color: _textFaint),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, i) => _buildItem(logs, i, hasMoreToLoad),
                      childCount: _itemCount(logs, hasMoreToLoad),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // Builds a flat list mixing date headers, log cards, and a trailing
  // "Load more" row, without pre-materializing a parallel widget list
  // (keeps ListView.builder lazy/cheap even with hundreds of rows).
  int _itemCount(List<ActivityLogModel> logs, bool hasMoreToLoad) {
    var headers = 0;
    String? lastKey;
    for (final l in logs) {
      final key = l.timestamp != null
          ? '${l.timestamp!.year}-${l.timestamp!.month}-${l.timestamp!.day}'
          : 'unknown';
      if (key != lastKey) {
        headers++;
        lastKey = key;
      }
    }
    return logs.length + headers + (hasMoreToLoad ? 1 : 0);
  }

  Widget _buildItem(List<ActivityLogModel> logs, int index, bool hasMoreToLoad) {
    // Walk through, inserting a header each time the day changes.
    var i = 0;
    String? lastKey;
    for (final l in logs) {
      final key = l.timestamp != null
          ? '${l.timestamp!.year}-${l.timestamp!.month}-${l.timestamp!.day}'
          : 'unknown';
      if (key != lastKey) {
        if (i == index) {
          return Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 8, left: 2),
            child: Row(
              children: [
                Text(
                  l.timestamp != null ? _dayHeaderFor(l.timestamp!) : 'Unknown date',
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Container(height: 1, color: _border)),
              ],
            ),
          );
        }
        i++;
        lastKey = key;
      }
      if (i == index) return _buildLogCard(l);
      i++;
    }
    // Trailing "Load more" row.
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: _blue,
            side: const BorderSide(color: _border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: () => setState(() => _visibleLimit += _pageStep),
          icon: const Icon(Icons.expand_more_rounded, size: 18),
          label: const Text('Load more', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  // ── Stats strip ─────────────────────────────────────────────────────────
  // NEW: each card now doubles as an action filter — Total / Added /
  // Edited / Deleted. Same visual layout/colors as before; the only
  // additions are tap handling (via _statChip) and a highlight on
  // whichever card is currently selected.
  Widget _buildStatsStrip({
    required int total,
    required int added,
    required int edited,
    required int deleted,
  }) {
    return Container(
      color: _card,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          _statChip(
            icon: Icons.list_alt_rounded,
            label: '$total total',
            fg: _textSecondary,
            bg: _chipFill,
            filter: ActivityTypeFilter.total,
          ),
          const SizedBox(width: 8),
          _statChip(
            icon: Icons.add_rounded,
            label: '$added added',
            fg: _green,
            bg: _green.withOpacity(0.1),
            filter: ActivityTypeFilter.added,
          ),
          const SizedBox(width: 8),
          _statChip(
            icon: Icons.edit_outlined,
            label: '$edited edited',
            fg: _amber,
            bg: _amber.withOpacity(0.12),
            filter: ActivityTypeFilter.edited,
          ),
          const SizedBox(width: 8),
          _statChip(
            icon: Icons.delete_outline_rounded,
            label: '$deleted deleted',
            fg: _red,
            bg: _red.withOpacity(0.1),
            filter: ActivityTypeFilter.deleted,
          ),
        ],
      ),
    );
  }

  // NEW: `filter` identifies which ActivityTypeFilter this card represents.
  // Tapping it sets `_actionFilter` via setState (instant UI update, no
  // reload — the StreamBuilder above keeps its existing subscription and
  // simply re-filters the same snapshot). The selected card gets a solid
  // colored background, a matching border, and a small elevation/shadow so
  // the active filter is unambiguous at a glance; unselected cards keep the
  // original soft-tint look.
  Widget _statChip({
    required IconData icon,
    required String label,
    required Color fg,
    required Color bg,
    required ActivityTypeFilter filter,
  }) {
    final selected = _actionFilter == filter;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _actionFilter = filter),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected ? fg.withOpacity(0.18) : bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected ? fg : Colors.transparent, width: 1.4),
              boxShadow: selected
                  ? [
                BoxShadow(
                  color: fg.withOpacity(0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
                  : null,
            ),
            child: Column(
              children: [
                Icon(icon, size: 15, color: fg),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(List<ActivityLogModel> visibleLogs) {
    final disabled = _bulkDeleting || visibleLogs.isEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '${visibleLogs.length} ${visibleLogs.length == 1 ? 'entry' : 'entries'} shown',
            style: const TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Material(
            color: disabled ? _chipFill : _red.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: disabled ? null : () => _confirmBulkDelete(visibleLogs),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: disabled ? _border : _red.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_bulkDeleting)
                      const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _red),
                      )
                    else
                      Icon(Icons.delete_sweep_outlined,
                          size: 15, color: disabled ? _textFaint : _red),
                    const SizedBox(width: 6),
                    Text(
                      _bulkDeleting ? 'Deleting…' : 'Delete shown',
                      style: TextStyle(
                        color: disabled ? _textFaint : _red,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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

  Widget _buildLogCard(ActivityLogModel log) {
    final color = _colorFor(log);
    final deleting = _rowsBeingDeleted.contains(log.id);
    return Opacity(
      opacity: deleting ? 0.4 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Circular action-colored icon badge — replaces the old
                  // bare icon so each row's action type reads at a glance
                  // even before reading any text.
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                    child: Icon(_iconFor(log), size: 17, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _sentenceFor(log),
                          style: const TextStyle(
                              color: _textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.3),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _pill(log.userRole, _chipFill, _textSecondary),
                            if (log.module != null) _pill(log.module!, _blue.withOpacity(0.1), _blue),
                            Text(
                              log.timestamp != null ? _dateFmt.format(log.timestamp!) : '—',
                              style: const TextStyle(color: _textFaint, fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _timeAgo(log.timestamp),
                        style: const TextStyle(color: _textFaint, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: deleting ? null : () => _confirmDeleteOne(log),
                            borderRadius: BorderRadius.circular(14),
                            child: Icon(Icons.delete_outline_rounded, size: 16, color: _textFaint),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (log.hasChanges) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _chipFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
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
                            style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w700),
                          ),
                        ];
                      } else {
                        valueSpans = [
                          TextSpan(
                            text: oldV,
                            style: const TextStyle(
                                color: Colors.redAccent, decoration: TextDecoration.lineThrough),
                          ),
                          const TextSpan(text: '   →   ', style: TextStyle(color: _textFaint)),
                          TextSpan(
                            text: newV,
                            style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w700),
                          ),
                        ];
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 12),
                            children: [
                              TextSpan(
                                text: '${e.key}:  ',
                                style: const TextStyle(color: _textSecondary, fontWeight: FontWeight.w600),
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
      ),
    );
  }

  Widget _pill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  // One consistent row shape for every filter bar: a small muted leading
  // icon (so the three rows read as "who / when / where" at a glance
  // instead of three visually-unrelated strips), then a horizontally
  // scrolling row of chips, all sharing the same height and padding.
  Widget _filterRow({required IconData icon, required List<Widget> chips}) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(icon, size: 15, color: _textFaint),
          const SizedBox(width: 8),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: chips,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserFilterBar() {
    return StreamBuilder<List<AppUserAccess>>(
      stream: AccessControlService.streamAllEmployees(),
      builder: (context, snapshot) {
        final users = snapshot.data ?? [];
        return _filterRow(
          icon: Icons.person_outline_rounded,
          chips: [
            _chip('Everyone', null, _filterUid, (v) => setState(() => _filterUid = v as String?)),
            ...users.map((u) => _chip(
                u.name.isNotEmpty ? u.name : u.email,
                u.uid,
                _filterUid,
                    (v) => setState(() => _filterUid = v as String?))),
          ],
        );
      },
    );
  }

  Widget _buildModuleFilterBar(List<String> modules) {
    return _filterRow(
      icon: Icons.folder_open_rounded,
      chips: [
        _chip('All modules', null, _filterModule, (v) => setState(() => _filterModule = v as String?)),
        ...modules.map((m) => _chip(m, m, _filterModule, (v) => setState(() => _filterModule = v as String?))),
      ],
    );
  }

  Widget _buildRangeFilterBar() {
    return _filterRow(
      icon: Icons.schedule_rounded,
      chips: [
        _chip('All time', _TimeRange.all, _range, (v) => setState(() => _range = v as _TimeRange)),
        _chip('Today', _TimeRange.today, _range, (v) => setState(() => _range = v as _TimeRange)),
        _chip('This week', _TimeRange.week, _range, (v) => setState(() => _range = v as _TimeRange)),
        _chip('This month', _TimeRange.month, _range, (v) => setState(() => _range = v as _TimeRange)),
      ],
    );
  }

  /// One shared chip style for every filter row — same fill, border,
  /// radius, and padding whether it's a user, a module, or a time range,
  /// so all three rows look like one coherent filter panel rather than
  /// three separately-styled controls. Selected chips go solid black (as
  /// on the Search Products screen's "All" chip) rather than blue, so
  /// selection reads the same way across both screens.
  Widget _chip(String label, Object? value, Object? current, ValueChanged<Object?> onSelect) {
    final selected = current == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      child: ChoiceChip(
        label: Text(label),
        labelStyle: TextStyle(
          color: selected ? Colors.white : _textSecondary,
          fontSize: 12.5,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
        selected: selected,
        onSelected: (_) => onSelect(value),
        selectedColor: _chipSelected,
        backgroundColor: _chipFill,
        showCheckmark: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: selected ? _chipSelected : _border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// WHY "Unnamed screen" / duplicate entries were showing up — and the fix
// ─────────────────────────────────────────────────────────────────────────
// This screen was only ever rendering whatever ActivityLogService streamed
// to it — it wasn't the source of either problem you saw. The real causes,
// fixed alongside this file:
//
// 1. "Unnamed screen" — AccessRouteObserver labels a page visit using
//    `route.settings.name`, falling back to the literal string
//    'Unnamed screen' whenever a screen is pushed via
//    `Navigator.push(MaterialPageRoute(builder: ...))` with no `settings:`.
//    Nine call sites across the app were missing that name:
//      - lib/screens/inventory/inventory_dashboard.dart
//          4x → EditProductScreen, 1x → AddProductScreen
//      - lib/screens/consumables/consumable_list_screen.dart
//          3x → EditConsumableScreen, 1x → AddConsumableScreen
//    Each now has `settings: const RouteSettings(name: '...')` added, so
//    the feed shows "Edit Product", "Add Product", "Edit Consumable", and
//    "Add Consumable" instead of "Unnamed screen". (Every other push in
//    the app already had a name — confirmed by scanning every
//    MaterialPageRoute(...) call in lib/.)
//
// 2. Rapid duplicate entries for the same screen — `AccessRouteObserver()`
//    was being constructed *inline* inside
//    `MaterialApp(navigatorObservers: [AccessRouteObserver()])`, which
//    lives inside a `Consumer<ThemeProvider>` builder in main.dart. Every
//    time that Consumer rebuilt (e.g. a theme change), a brand-new
//    observer instance replaced the old one — silently wiping its
//    `_lastLabel` / `_lastLoggedAt` throttle memory and letting the same
//    screen log again immediately. Fixed by hoisting a single
//    `static final AccessRouteObserver` instance in
//    `ChennaiDroneInventoryApp` and passing that same instance every
//    build, so the 60-second duplicate-visit throttle actually holds for
//    the lifetime of the app.
//
// Everything else was already correct and needed no change:
//   - CRUD add/edit/delete logging is already wired into every
//     *_service.dart file (Bills, Branch Inventory, Consumables, Drones,
//     Fixed Assets, Invoices, Payments Out, Purchase Orders, Purchase
//     Returns, Purchases, Stock) via ActivityLogService.logAdd/logEdit/
//     logDelete, so those actions already show up here with full before/
//     after detail.
//   - Nothing auto-expires or auto-prunes `activity_logs` — the only
//     deletions are `ActivityLogService.deleteLog`/`deleteLogs`, and both
//     are only ever called from this screen's own confirm-then-delete
//     dialogs above.