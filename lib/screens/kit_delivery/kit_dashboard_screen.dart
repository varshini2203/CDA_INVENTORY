// lib/screens/kit_delivery/kit_dashboard_screen.dart
//
// "Kit Deliveries" home screen. Same look as the Drone Services page:
// tall navy header · 4 stat tiles · overdue banner · branch chips ·
// List / Calendar / History switch · search · status chips · sort chips ·
// cards · teal "New Kit" button.
//
//   List      every kit with its DELIVERED and PENDING products
//   Calendar  kits by promised date (pending) / delivery date (completed)
//   History   every hand-over event (what was given, when, by whom)
//
// The dashboard bell opens this screen with the "Due / Overdue" filter.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/drone_categories.dart';
import '../../core/access/access_scope.dart';
import '../../models/kit_delivery.dart';
import '../../services/kit_delivery_service.dart';
import '../drone_service/drone_service_dashboard_screen.dart'
    show ServiceMonthCalendar;
import 'add_edit_kit_screen.dart';
import 'kit_detail_screen.dart';

// Same palette as the Drone Services page. The kKit* names are kept because
// the other kit screens import them; kKitBlue is now the teal accent.
const Color kKitBg = Color(0xFFF0F4F8);
const Color kKitNavy = Color(0xFF0A1628);
const Color kKitBlue = Color(0xFF00D4AA); // teal accent
const Color kKitGreen = Color(0xFF00B894);
const Color kKitRed = Color(0xFFFF6B6B); // coral
const Color kKitAmber = Color(0xFFFFB800);
const Color kKitPurple = Color(0xFF6C63FF);
const Color kKitMuted = Color(0xFF8D99A8);
const Color kKitBorder = Color(0xFFE2E8F0);

enum KitFilter { due, pending, completed, all }

extension KitFilterLabel on KitFilter {
  String get label {
    switch (this) {
      case KitFilter.due:
        return 'Due / Overdue';
      case KitFilter.pending:
        return 'Pending';
      case KitFilter.completed:
        return 'Completed';
      case KitFilter.all:
        return 'All';
    }
  }
}

/// Human text for a kit's promised date: "Overdue 3d", "Due today",
/// "Due in 2d", "No date".
String kitDueText(KitDelivery k) {
  if (k.isComplete) return 'Completed';
  if (k.promisedDate == null) return 'No promised date';
  if (k.isOverdue) return 'Overdue ${k.daysOverdue}d';
  final p = k.promisedDate!;
  final now = DateTime.now();
  final days = DateTime(p.year, p.month, p.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;
  return days == 0 ? 'Due today' : 'Due in ${days}d';
}

Color kitDueColor(KitDelivery k) {
  if (k.isComplete) return kKitGreen;
  if (k.isOverdue) return kKitRed;
  if (k.isDueOrOverdue) return kKitAmber;
  return kKitPurple;
}

class _HandoverEntry {
  final KitDelivery kit;
  final KitHandover handover;
  const _HandoverEntry(this.kit, this.handover);
}

class KitDashboardScreen extends StatefulWidget {
  final KitFilter initialFilter;

  const KitDashboardScreen({
    super.key,
    this.initialFilter = KitFilter.pending,
  });

  @override
  State<KitDashboardScreen> createState() => _KitDashboardScreenState();
}

class _KitDashboardScreenState extends State<KitDashboardScreen> {
  final KitDeliveryService _service = KitDeliveryService();

  // Created once — creating it inside build() would re-open the Firestore
  // listener on every rebuild.
  late final Stream<List<KitDelivery>> _stream =
  _service.kitsStreamWithReminderSync();

  late KitFilter _filter = widget.initialFilter;
  String _branch = KitDeliveryService.branchAll;
  String _search = '';
  String _historySearch = '';
  String _viewMode = 'list'; // 'list' | 'calendar' | 'history'
  bool _sortAscending = true; // Oldest → Newest
  DateTime _focusedMonth =
  DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? _selectedDay;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Refresh "Overdue 3d" / "Due today" labels when midnight passes.
    _tick = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<KitDelivery> _branchOnly(List<KitDelivery> all) =>
      _branch == KitDeliveryService.branchAll
          ? all
          : all.where((k) => k.branch == _branch).toList();

  /// The day a kit sits on in the calendar / sort order.
  DateTime _keyDate(KitDelivery k) =>
      k.isPending ? (k.promisedDate ?? k.deliveredAt) : k.deliveredAt;

  List<KitDelivery> _filtered(List<KitDelivery> all) {
    Iterable<KitDelivery> list = _branchOnly(all);

    switch (_filter) {
      case KitFilter.due:
        list = list.where((k) => k.isDueOrOverdue);
        break;
      case KitFilter.pending:
        list = list.where((k) => k.isPending);
        break;
      case KitFilter.completed:
        list = list.where((k) => k.isComplete);
        break;
      case KitFilter.all:
        break;
    }

    final q = _search.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((k) =>
      k.customerName.toLowerCase().contains(q) ||
          k.customerPhone.contains(q) ||
          k.invoiceRef.toLowerCase().contains(q) ||
          k.items.any((i) => i.name.toLowerCase().contains(q)));
    }

    final out = list.toList();
    out.sort((a, b) => _sortAscending
        ? _keyDate(a).compareTo(_keyDate(b))
        : _keyDate(b).compareTo(_keyDate(a)));
    return out;
  }

  List<_HandoverEntry> _history(List<KitDelivery> all) {
    final q = _historySearch.trim().toLowerCase();
    final out = <_HandoverEntry>[];
    for (final k in _branchOnly(all)) {
      for (final h in k.handovers) {
        if (q.isNotEmpty) {
          final hit = k.customerName.toLowerCase().contains(q) ||
              k.customerPhone.contains(q) ||
              h.by.toLowerCase().contains(q) ||
              h.quantities.keys.any((n) => n.toLowerCase().contains(q));
          if (!hit) continue;
        }
        out.add(_HandoverEntry(k, h));
      }
    }
    out.sort((a, b) => b.handover.at.compareTo(a.handover.at));
    return out;
  }

  Future<void> _openAdd() async {
    if (!requireEditAccess(context)) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'Add Kit'),
        builder: (_) => const AddEditKitScreen(),
      ),
    );
  }

  Future<void> _openEdit(KitDelivery k) async {
    if (!requireEditAccess(context)) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'Edit Kit'),
        builder: (_) => AddEditKitScreen(kit: k),
      ),
    );
  }

  Future<void> _delete(KitDelivery k) async {
    if (!requireEditAccess(context)) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete this kit?',
            style: TextStyle(color: kKitNavy, fontWeight: FontWeight.w800)),
        content: Text(
          'This removes the record for ${k.customerName} and its reminder. '
              'This cannot be undone.',
          style: const TextStyle(color: kKitNavy),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: kKitRed))),
        ],
      ),
    );
    if (ok != true) return;
    final r = await _service.deleteKit(k);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(r.success
            ? 'Kit for ${k.customerName} deleted'
            : (r.error ?? 'Could not delete.')),
        backgroundColor: r.success ? kKitBlue : kKitRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openDetail(KitDelivery k) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'Kit Details'),
        builder: (_) => KitDetailScreen(kitId: k.id),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kKitBg,
      body: StreamBuilder<List<KitDelivery>>(
        stream: _stream,
        builder: (context, snap) {
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            slivers: [
              _buildAppBar(),
              if (snap.hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load kits.\n${snap.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: kKitRed),
                      ),
                    ),
                  ),
                )
              else if (!snap.hasData)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                      child: CircularProgressIndicator(color: kKitBlue)),
                )
              else
                ..._buildBody(snap.data!),
            ],
          );
        },
      ),
      floatingActionButton: MediaQuery.of(context).viewInsets.bottom > 0
          ? null
          : EditGuard(
        child: FloatingActionButton.extended(
          onPressed: _openAdd,
          backgroundColor: kKitBlue,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('New Kit',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  List<Widget> _buildBody(List<KitDelivery> all) {
    final scoped = _branchOnly(all);
    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: _viewMode == 'history'
            ? _buildHistoryStats(all)
            : _buildStatsRow(scoped),
      ),
      SliverToBoxAdapter(child: _buildOverdueBanner(scoped)),
      SliverToBoxAdapter(child: _buildBranchRow()),
      SliverToBoxAdapter(child: _buildViewToggle()),
    ];

    if (_viewMode == 'list') {
      final shown = _filtered(all);
      slivers.add(SliverToBoxAdapter(child: _buildSearchAndStatusRow(scoped)));
      slivers.add(
        shown.isEmpty
            ? SliverToBoxAdapter(child: _EmptyView(filter: _filter, onAdd: _openAdd))
            : SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _KitCard(
                  kit: shown[i],
                  onTap: () => _openDetail(shown[i]),
                  onEdit: () => _openEdit(shown[i]),
                  onDelete: () => _delete(shown[i]),
                ),
              ),
              childCount: shown.length,
            ),
          ),
        ),
      );
    } else if (_viewMode == 'calendar') {
      final agenda = _agenda(scoped);
      slivers.add(SliverToBoxAdapter(child: _buildCalendar(scoped)));
      slivers.add(SliverToBoxAdapter(child: _buildAgendaHeader()));
      slivers.add(
        agenda.isEmpty
            ? SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text('No kits on this day',
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 13)),
            ),
          ),
        )
            : SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _KitCard(
                  kit: agenda[i],
                  onTap: () => _openDetail(agenda[i]),
                  onEdit: () => _openEdit(agenda[i]),
                  onDelete: () => _delete(agenda[i]),
                ),
              ),
              childCount: agenda.length,
            ),
          ),
        ),
      );
    } else {
      final hist = _history(all);
      slivers.add(SliverToBoxAdapter(child: _buildHistorySearch()));
      slivers.add(
        hist.isEmpty
            ? SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: Column(children: [
                Icon(Icons.history_rounded,
                    size: 44, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('No hand-overs yet',
                    style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        )
            : SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _HandoverCard(
                  entry: hist[i],
                  onTap: () => _openDetail(hist[i].kit),
                ),
              ),
              childCount: hist.length,
            ),
          ),
        ),
      );
    }
    return slivers;
  }

  // ── App bar ───────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: kKitNavy,
      pinned: true,
      expandedHeight: 108,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 16),
        title: const Text('Kit Deliveries',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kKitNavy, Color(0xFF162944)],
            ),
          ),
        ),
      ),
    );
  }

  // ── Stat tiles ────────────────────────────────────────────────────────────

  Widget _statCard(String label, int value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text('$value',
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: kKitNavy)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(List<KitDelivery> scoped) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(children: [
        _statCard('Total Kits', scoped.length, kKitNavy,
            Icons.inventory_2_rounded),
        _statCard('Pending', scoped.where((k) => k.isPending).length,
            kKitAmber, Icons.pending_actions_rounded),
        _statCard('Due / Overdue',
            scoped.where((k) => k.isDueOrOverdue).length, kKitRed,
            Icons.notifications_active_rounded),
        _statCard('Completed', scoped.where((k) => k.isComplete).length,
            kKitGreen, Icons.check_circle_rounded),
      ]),
    );
  }

  Widget _buildHistoryStats(List<KitDelivery> all) {
    final scoped = _branchOnly(all);
    final events = scoped.fold<int>(0, (a, k) => a + k.handovers.length);
    final items = scoped.fold<int>(
        0, (a, k) => a + k.handovers.fold<int>(0, (b, h) => b + h.totalQty));
    final customers = scoped.map((k) => k.customerName.toLowerCase()).toSet();
    final pendingItems = scoped.fold<int>(0, (a, k) => a + k.totalPending);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(children: [
        _statCard('Hand-overs', events, kKitNavy, Icons.local_shipping_rounded),
        _statCard('Items Given', items, kKitBlue, Icons.inventory_rounded),
        _statCard('Customers', customers.length, kKitPurple,
            Icons.people_alt_rounded),
        _statCard('Items Pending', pendingItems, kKitRed,
            Icons.hourglass_empty_rounded),
      ]),
    );
  }

  // ── Overdue banner ────────────────────────────────────────────────────────

  Widget _buildOverdueBanner(List<KitDelivery> scoped) {
    final due = scoped.where((k) => k.isDueOrOverdue).toList();
    if (due.isEmpty) return const SizedBox.shrink();
    final overdue = due.where((k) => k.isOverdue).toList();
    final worst = overdue.isEmpty
        ? 0
        : overdue.map((k) => k.daysOverdue).reduce((a, b) => a > b ? a : b);
    final parts = due.fold<int>(0, (a, k) => a + k.totalPending);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() {
          _viewMode = 'list';
          _filter = KitFilter.due;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: kKitRed.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kKitRed.withValues(alpha: 0.5)),
          ),
          child: Row(children: [
            const Icon(Icons.notification_important_rounded,
                color: kKitRed, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${due.length} kit${due.length == 1 ? '' : 's'} '
                        'with pending products ${overdue.isEmpty ? 'due today' : 'past the promised date'}',
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: kKitNavy),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${overdue.isEmpty ? '' : 'Longest overdue: ${worst}d · '}'
                        '$parts item${parts == 1 ? '' : 's'} to hand over · tap to view',
                    style:
                    TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: kKitRed),
          ]),
        ),
      ),
    );
  }

  // ── Branch chips ──────────────────────────────────────────────────────────

  Widget _buildBranchRow() {
    Widget chip(String label, String value) {
      final selected = _branch == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : kKitNavy)),
          selected: selected,
          onSelected: (_) => setState(() => _branch = value),
          selectedColor: kKitNavy,
          backgroundColor: Colors.white,
          showCheckmark: false,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
                color: selected ? kKitNavy : Colors.grey.shade300),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          chip('All Branch', KitDeliveryService.branchAll),
          for (final b in kBranchOptions) chip(kBranchLabels[b] ?? b, b),
        ]),
      ),
    );
  }

  // ── List / Calendar / History switch ──────────────────────────────────────

  Widget _buildViewToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(
              child: _toggleBtn('List', Icons.view_list_rounded,
                  _viewMode == 'list', () => setState(() => _viewMode = 'list'))),
          Expanded(
              child: _toggleBtn(
                  'Calendar',
                  Icons.calendar_month_rounded,
                  _viewMode == 'calendar',
                      () => setState(() => _viewMode = 'calendar'))),
          Expanded(
              child: _toggleBtn(
                  'History',
                  Icons.history_rounded,
                  _viewMode == 'history',
                      () => setState(() => _viewMode = 'history'))),
        ]),
      ),
    );
  }

  Widget _toggleBtn(
      String label, IconData icon, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? kKitBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 15,
                color: selected ? Colors.white : Colors.grey.shade500),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  // ── Search + status chips + sort chips ────────────────────────────────────

  InputDecoration _searchDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
    prefixIcon:
    Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(vertical: 0),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none),
  );

  Widget _buildSearchAndStatusRow(List<KitDelivery> scoped) {
    final counts = {
      KitFilter.all: scoped.length,
      KitFilter.pending: scoped.where((k) => k.isPending).length,
      KitFilter.due: scoped.where((k) => k.isDueOrOverdue).length,
      KitFilter.completed: scoped.where((k) => k.isComplete).length,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(children: [
        TextField(
          onChanged: (v) => setState(() => _search = v),
          cursorColor: kKitNavy,
          style: const TextStyle(
              color: kKitNavy, fontSize: 14, fontWeight: FontWeight.w500),
          decoration:
          _searchDecoration('Search customer, phone, invoice, product…'),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _statusChip('All', KitFilter.all, kKitNavy, counts),
              _statusChip('Pending', KitFilter.pending, kKitAmber, counts),
              _statusChip('Due / Overdue', KitFilter.due, kKitRed, counts),
              _statusChip('Completed', KitFilter.completed, kKitGreen, counts),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildSortRow(),
        const SizedBox(height: 4),
      ]),
    );
  }

  Widget _statusChip(
      String label, KitFilter value, Color color, Map<KitFilter, int> counts) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text('$label (${counts[value] ?? 0})',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : color)),
        selected: selected,
        onSelected: (_) => setState(() => _filter = value),
        selectedColor: color,
        backgroundColor: color.withValues(alpha: 0.08),
        showCheckmark: false,
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
    );
  }

  Widget _buildSortRow() {
    Widget chip(String label, bool ascending, IconData icon) {
      final selected = _sortAscending == ascending;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          avatar: Icon(icon,
              size: 14, color: selected ? Colors.white : kKitNavy),
          label: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : kKitNavy)),
          selected: selected,
          onSelected: (_) => setState(() => _sortAscending = ascending),
          selectedColor: kKitBlue,
          backgroundColor: Colors.white,
          showCheckmark: false,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
                color: selected ? kKitBlue : Colors.grey.shade300),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        Icon(Icons.sort_rounded, size: 15, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        chip('Oldest → Newest', true, Icons.arrow_upward_rounded),
        chip('Newest → Oldest', false, Icons.arrow_downward_rounded),
      ]),
    );
  }

  // ── Calendar ──────────────────────────────────────────────────────────────

  List<KitDelivery> _agenda(List<KitDelivery> scoped) {
    final day = _selectedDay ?? DateTime.now();
    final list = scoped.where((k) {
      final d = _keyDate(k);
      return d.year == day.year && d.month == day.month && d.day == day.day;
    }).toList();
    list.sort((a, b) => _sortAscending
        ? _keyDate(a).compareTo(_keyDate(b))
        : _keyDate(b).compareTo(_keyDate(a)));
    return list;
  }

  Widget _buildCalendar(List<KitDelivery> scoped) {
    final markers = <DateTime, List<Color>>{};
    for (final k in scoped) {
      final d = _keyDate(k);
      final key = DateTime(d.year, d.month, d.day);
      markers.putIfAbsent(key, () => []).add(kitDueColor(k));
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: ServiceMonthCalendar(
        focusedMonth: _focusedMonth,
        selectedDay: _selectedDay,
        dayMarkers: markers,
        accent: kKitBlue,
        onMonthChanged: (m) => setState(() => _focusedMonth = m),
        onDaySelected: (d) => setState(() => _selectedDay = d),
      ),
    );
  }

  Widget _buildAgendaHeader() {
    final day = _selectedDay ?? DateTime.now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 6),
      child: Row(children: [
        Icon(Icons.event_note_rounded, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(DateFormat('EEEE, d MMM yyyy').format(day),
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: kKitNavy)),
      ]),
    );
  }

  // ── History search ────────────────────────────────────────────────────────

  Widget _buildHistorySearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        onChanged: (v) => setState(() => _historySearch = v),
        cursorColor: kKitNavy,
        style: const TextStyle(
            color: kKitNavy, fontSize: 14, fontWeight: FontWeight.w500),
        decoration:
        _searchDecoration('Search customer, phone, product, handed by…'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KIT CARD
// ─────────────────────────────────────────────────────────────────────────────

class _KitCard extends StatelessWidget {
  final KitDelivery kit;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _KitCard({
    required this.kit,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final accent = kitDueColor(kit);
    final fmt = DateFormat('d MMM yyyy');
    final delivered = kit.items.where((i) => i.deliveredQty > 0).toList();
    final pending = kit.pendingItems;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    kit.isComplete
                        ? Icons.inventory_2_rounded
                        : Icons.unarchive_rounded,
                    color: accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(kit.customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: kKitNavy)),
                      const SizedBox(height: 3),
                      Text(
                        [
                          kBranchLabels[kit.branch] ?? kit.branch,
                          if (kit.invoiceRef.isNotEmpty) kit.invoiceRef,
                        ].join(' · '),
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.access_time_rounded,
                                size: 12, color: Colors.grey.shade400),
                            const SizedBox(width: 4),
                            Text('Delivered ${fmt.format(kit.deliveredAt)}',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.grey.shade500)),
                          ]),
                          if (kit.isPending && kit.promisedDate != null)
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.event_available_rounded,
                                  size: 12, color: Colors.grey.shade400),
                              const SizedBox(width: 4),
                              Text(
                                  'Promised ${fmt.format(kit.promisedDate!)}',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.grey.shade500)),
                            ]),
                        ],
                      ),
                      if (kit.isOverdue) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: kKitRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    size: 13, color: kKitRed),
                                const SizedBox(width: 4),
                                Text(
                                  'Overdue by ${kit.daysOverdue} day${kit.daysOverdue == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: kKitRed),
                                ),
                              ]),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(kitDueText(kit),
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: accent)),
                ),
              ]),
              const Divider(height: 20),
              _ProductsLine(
                icon: Icons.check_circle_rounded,
                color: kKitGreen,
                title: 'Delivered (${kit.totalDelivered})',
                items: delivered,
                usePending: false,
                emptyText: 'Nothing delivered yet',
              ),
              const SizedBox(height: 10),
              _ProductsLine(
                icon: pending.isEmpty
                    ? Icons.task_alt_rounded
                    : Icons.pending_actions_rounded,
                color: pending.isEmpty ? kKitMuted : kKitRed,
                title: 'Pending (${kit.totalPending})',
                items: pending,
                usePending: true,
                emptyText: 'Nothing pending',
              ),
              if (kit.totalRequired > 0) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: kit.progress,
                        minHeight: 6,
                        backgroundColor: kKitBorder,
                        valueColor: AlwaysStoppedAnimation(
                            kit.isComplete ? kKitGreen : kKitBlue),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${kit.totalDelivered}/${kit.totalRequired} given',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade600)),
                ]),
              ],
              // ── Edit / Delete ─────────────────────────────────────
              EditGuard(
                hideInsteadOfDisable: true,
                child: Column(
                  children: [
                    const Divider(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_rounded, size: 16),
                          label: const Text('Edit'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kKitGreen,
                            side: BorderSide(
                                color: kKitGreen.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            textStyle: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w700),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 16),
                          label: const Text('Delete'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kKitRed,
                            side: BorderSide(
                                color: kKitRed.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            textStyle: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w700),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "✓ Delivered (3)" header + a wrap of "Drone ×1" chips.
class _ProductsLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final List<KitItem> items;
  final bool usePending;
  final String emptyText;

  const _ProductsLine({
    required this.icon,
    required this.color,
    required this.title,
    required this.items,
    required this.usePending,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: color)),
              const SizedBox(height: 5),
              if (items.isEmpty)
                Text(emptyText,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade400))
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final i in items)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: color.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '${i.name} ×${usePending ? i.pendingQty : i.deliveredQty}',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: color),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HISTORY CARD (one hand-over event)
// ─────────────────────────────────────────────────────────────────────────────

class _HandoverCard extends StatelessWidget {
  final _HandoverEntry entry;
  final VoidCallback onTap;

  const _HandoverCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final k = entry.kit;
    final h = entry.handover;
    final fmt = DateFormat('d MMM, h:mm a');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: kKitGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.local_shipping_rounded,
                  color: kKitGreen, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    h.quantities.entries
                        .map((e) => '${e.key} ×${e.value}')
                        .join(', '),
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: kKitNavy),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${k.customerName} · ${kBranchLabels[k.branch] ?? k.branch}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 5),
                  Wrap(spacing: 10, runSpacing: 4, children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.access_time_rounded,
                          size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(fmt.format(h.at),
                          style: TextStyle(
                              fontSize: 11.5, color: Colors.grey.shade500)),
                    ]),
                    if (h.by.isNotEmpty)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.person_outline_rounded,
                            size: 12, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text(h.by,
                            style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade500)),
                      ]),
                  ]),
                  if (h.note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(h.note,
                        style: TextStyle(
                            fontSize: 11.5, color: Colors.grey.shade500)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: (k.isComplete ? kKitGreen : kKitAmber)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                k.isComplete ? 'Completed' : '${k.totalPending} pending',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: k.isComplete ? kKitGreen : kKitAmber),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY VIEW
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final KitFilter filter;
  final VoidCallback onAdd;
  const _EmptyView({required this.filter, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final text = {
      KitFilter.due: 'Nothing due right now',
      KitFilter.pending: 'No kits with pending products',
      KitFilter.completed: 'No completed kits yet',
      KitFilter.all: 'No kits yet',
    }[filter]!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: kKitBlue.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inventory_2_outlined,
                  size: 36, color: kKitBlue),
            ),
            const SizedBox(height: 12),
            Text(text,
                style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            const SizedBox(height: 12),
            EditGuard(
              child: TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, color: kKitBlue),
                label: const Text('New Kit',
                    style: TextStyle(
                        color: kKitBlue, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}