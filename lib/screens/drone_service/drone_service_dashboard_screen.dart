// lib/screens/drone_service/drone_service_dashboard_screen.dart
//
// "Drone Services" module — service & maintenance bookings, distinct from
// the Drone In/Out flight-log module. Covers all branches (All Branch /
// CDA Admin / CDA Ops), a list view and a calendar view, and an "Add
// Service" flow. Theme matched to the Drone In/Out & Invoice pages.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/drone_service_record.dart';
import '../../services/drone_service_booking_service.dart';
import '../../services/drone_service_alert_service.dart';
import '../../constants/drone_categories.dart';
import '../../services/current_user_service.dart';
import '../../constants/drone_service_options.dart';
import '../../core/access/access_scope.dart';
import 'add_service_screen.dart';

class DroneServiceDashboardScreen extends StatefulWidget {
  const DroneServiceDashboardScreen({super.key});

  @override
  State<DroneServiceDashboardScreen> createState() =>
      _DroneServiceDashboardScreenState();
}

class _DroneServiceDashboardScreenState
    extends State<DroneServiceDashboardScreen> {
  final DroneServiceBookingService _service = DroneServiceBookingService();

  List<DroneServiceRecord> _all = [];
  bool _loading = true;
  String? _error;

  String _branchFilter = DroneServiceBookingService.branchAll;
  String _statusFilter = DroneServiceBookingService.statusAll;
  String _search = '';
  String _viewMode = 'list'; // 'list' | 'calendar' | 'history' — three-way switch shown as List/Calendar/History
  String _historySearch = '';
  // 'all' | 'checkedIn' | 'checkedOut' | 'awaiting'
  String _historyInOutFilter = 'all';
  bool _sortAscending = true; // true = Oldest → Newest, false = Newest → Oldest
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? _selectedDay;

  // ── Design tokens (matches Drone In/Out & Invoice pages) ────────────────
  static const Color kNavy = Color(0xFF0A1628);
  static const Color kTeal = Color(0xFF00D4AA);
  static const Color kCoral = Color(0xFFFF6B6B);
  static const Color kAmber = Color(0xFFFFB800);
  static const Color kSurface = Color(0xFFF0F4F8);
  static const Color kGreen = Color(0xFF00B894);
  static const Color kPurple = Color(0xFF6C63FF);

  // ── Overdue alert state ────────────────────────────────────────────────
  // ids already announced with a pop-up this session, so the dialog only
  // appears again when a *new* service goes past its scheduled date.
  final Set<String> _alertedIds = {};
  Timer? _overdueTimer;
  bool _alertOpen = false;

  @override
  void initState() {
    super.initState();
    _load();
    // Re-check every minute so a service that crosses its scheduled time
    // while this screen is open triggers the alert without a refresh.
    _overdueTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {}); // refresh "overdue by …" labels
      _checkOverdue();
    });
  }

  @override
  void dispose() {
    _overdueTimer?.cancel();
    super.dispose();
  }

  List<DroneServiceRecord> get _overdue => DroneServiceAlertService.overdueOf(
      _branchFilter == DroneServiceBookingService.branchAll
          ? _all
          : _all.where((s) => s.branch == _branchFilter).toList());

  /// Pops the alert dialog when there are overdue services we haven't
  /// announced yet. [force] re-opens it on demand (banner tap).
  Future<void> _checkOverdue({bool force = false}) async {
    if (!mounted || _alertOpen) return;
    final list = DroneServiceAlertService.overdueOf(_all);
    if (list.isEmpty) return;
    final fresh = list.where((s) => !_alertedIds.contains(s.id)).toList();
    if (fresh.isEmpty && !force) return;
    _alertedIds.addAll(list.map((s) => s.id));
    _alertOpen = true;
    await showDialog<void>(
      context: context,
      builder: (_) => _OverdueAlertDialog(
        items: list,
        onView: (r) {
          Navigator.pop(context);
          _openDetail(r);
        },
      ),
    );
    _alertOpen = false;
  }

  Widget _buildOverdueBanner() {
    final list = _overdue;
    if (list.isEmpty) return const SizedBox.shrink();
    final worst = list.first.overdueBy;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _checkOverdue(force: true),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: kCoral.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kCoral.withValues(alpha: 0.5)),
          ),
          child: Row(children: [
            const Icon(Icons.notification_important_rounded, color: kCoral, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  '${list.length} service${list.length == 1 ? '' : 's'} past the scheduled date',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: kNavy),
                ),
                const SizedBox(height: 2),
                Text('Longest overdue: ${DroneServiceAlertService.formatOverdue(worst)} · tap to view',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: kCoral),
          ]),
        ),
      ),
    );
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _service.getServices(forceRefresh: forceRefresh);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.success) {
        _all = result.data!;
      } else {
        _error = result.error;
      }
    });
    if (result.success) {
      // Re-arm device notifications for open bookings, then alert in-app.
      for (final r in _all) {
        if (r.status == 'Scheduled' || r.status == 'In Progress') {
          DroneServiceAlertService.instance.schedule(r);
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverdue());
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Scheduled':
        return kPurple;
      case 'In Progress':
        return kAmber;
      case 'Completed':
        return kGreen;
      case 'Cancelled':
        return kCoral;
      default:
        return Colors.grey;
    }
  }

  IconData _serviceIcon(String type) {
    switch (type) {
      case 'Battery Service':
        return Icons.battery_charging_full_rounded;
      case 'Motor Repair':
        return Icons.settings_rounded;
      case 'Propeller Replacement':
        return Icons.air_rounded;
      case 'Firmware Update':
        return Icons.system_update_rounded;
      case 'Full Maintenance':
        return Icons.build_circle_rounded;
      case 'Calibration':
        return Icons.tune_rounded;
      case 'Pre-Flight Inspection':
        return Icons.checklist_rounded;
      case 'Camera / Gimbal Repair':
        return Icons.camera_alt_rounded;
      case 'Frame Repair':
        return Icons.construction_rounded;
      default:
        return Icons.miscellaneous_services_rounded;
    }
  }

  List<DroneServiceRecord> get _filtered {
    var list = _all.where((s) {
      final matchBranch =
          _branchFilter == DroneServiceBookingService.branchAll || s.branch == _branchFilter;
      final matchStatus =
          _statusFilter == DroneServiceBookingService.statusAll || s.status == _statusFilter;
      final matchSearch = _search.isEmpty ||
          s.droneName.toLowerCase().contains(_search.toLowerCase()) ||
          s.serviceType.toLowerCase().contains(_search.toLowerCase()) ||
          s.technician.toLowerCase().contains(_search.toLowerCase()) ||
          (s.customerName ?? '').toLowerCase().contains(_search.toLowerCase()) ||
          (s.customerPhone ?? '').contains(_search);
      return matchBranch && matchStatus && matchSearch;
    }).toList();
    list.sort((a, b) => _sortAscending
        ? a.scheduledAt.compareTo(b.scheduledAt)
        : b.scheduledAt.compareTo(a.scheduledAt));
    return list;
  }

  List<DroneServiceRecord> get _branchOnly => _all
      .where((s) => _branchFilter == DroneServiceBookingService.branchAll || s.branch == _branchFilter)
      .toList();

  Map<String, int> get _stats {
    final list = _branchOnly;
    return {
      'total': list.length,
      'Scheduled': list.where((s) => s.status == 'Scheduled').length,
      'In Progress': list.where((s) => s.status == 'In Progress').length,
      'Completed': list.where((s) => s.status == 'Completed').length,
    };
  }

  Future<void> _openAdd() async {
    if (!requireEditAccess(context)) return;
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddServiceScreen()),
    );
    if (added == true) _load(forceRefresh: true);
  }

  void _openHistory() => setState(() => _viewMode = 'history');

  // ── Drone check-in / check-out toggle ──────────────────────────────────
  // ON  = drone has physically arrived and is at the shop for this service.
  // OFF = either not yet arrived, or already handed back after service.
  Future<void> _toggleCheckInOut(DroneServiceRecord r) async {
    if (!requireEditAccess(context)) return;
    if (r.isDroneCheckedOut) {
      _showSnack('This drone has already been checked out for this service.');
      return;
    }
    final isCheckingIn = !r.isDroneCheckedIn;
    // Logged-in user's name — never typed manually.
    final currentUserName = await CurrentUserService.getName();
    if (!mounted) return;

    final entry = await showDialog<_CheckInOutEntry>(
      context: context,
      builder: (_) => _CheckInOutDialog(
        record: r,
        isCheckingIn: isCheckingIn,
        defaultName: currentUserName,
      ),
    );
    if (entry == null) return;

    final result = isCheckingIn
        ? await _service.checkIn(r, at: entry.time, by: entry.handledBy)
        : await _service.checkOut(r, at: entry.time, by: entry.handledBy);

    if (!mounted) return;
    if (result.success) {
      _showSnack(
        isCheckingIn
            ? '${r.droneName} checked IN by ${entry.handledBy}'
            : '${r.droneName} checked OUT by ${entry.handledBy}',
        icon: isCheckingIn ? Icons.login_rounded : Icons.logout_rounded,
        color: isCheckingIn ? kTeal : kGreen,
      );
      _load(forceRefresh: true);
    } else {
      _showSnack('Failed: ${result.error}', isError: true);
    }
  }

  Future<void> _quickStatus(DroneServiceRecord r, String newStatus) async {
    final result = await _service.updateStatus(r.id, newStatus,
        previousStatus: r.status, itemName: '${r.serviceType} — ${r.droneName}');
    if (!mounted) return;
    if (result.success) {
      _showSnack('${r.droneName} → $newStatus', color: _statusColor(newStatus));
      _load(forceRefresh: true);
    } else {
      _showSnack('Failed: ${result.error}', isError: true);
    }
  }

  Future<void> _delete(DroneServiceRecord r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete service?'),
        content: Text('"${r.serviceType} — ${r.droneName}" will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: kCoral)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await _service.deleteService(r);
    if (!mounted) return;
    if (result.success) {
      _showSnack('Service removed', icon: Icons.delete_outline);
      _load(forceRefresh: true);
    } else {
      _showSnack('Delete failed: ${result.error}', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false, IconData? icon, Color? color}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          if (icon != null) ...[Icon(icon, color: Colors.white, size: 18), const SizedBox(width: 8)],
          Flexible(child: Text(msg, style: const TextStyle(color: Colors.white))),
        ]),
        backgroundColor: isError ? kCoral : (color ?? kTeal),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openDetail(DroneServiceRecord r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ServiceDetailSheet(
        record: r,
        statusColor: _statusColor,
        onStart: () => _quickStatus(r, 'In Progress'),
        onComplete: () => _quickStatus(r, 'Completed'),
        onCancel: () => _quickStatus(r, 'Cancelled'),
        onDelete: () => _delete(r),
        onToggleCheckInOut: () {
          Navigator.pop(context);
          _toggleCheckInOut(r);
        },
        onEdit: () async {
          Navigator.pop(context);
          final updated = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => AddServiceScreen(existing: r)),
          );
          if (updated == true) _load(forceRefresh: true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: RefreshIndicator(
        color: kTeal,
        onRefresh: () => _load(forceRefresh: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            _buildAppBar(),
            if (_loading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: kTeal)))
            else if (_error != null)
              SliverFillRemaining(child: _ErrorView(message: _error!, onRetry: () => _load(forceRefresh: true)))
            else ...[
                SliverToBoxAdapter(child: _viewMode == 'history' ? _buildHistoryStatsRow() : _buildStatsRow()),
                SliverToBoxAdapter(child: _buildOverdueBanner()),
                SliverToBoxAdapter(child: _buildBranchFilterRow()),
                SliverToBoxAdapter(child: _buildViewToggle()),
                if (_viewMode == 'list') ...[
                  SliverToBoxAdapter(child: _buildSearchAndStatusRow()),
                  _filtered.isEmpty
                      ? SliverFillRemaining(child: _EmptyView(onAdd: _openAdd))
                      : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ServiceCard(
                            record: _filtered[i],
                            statusColor: _statusColor(_filtered[i].status),
                            icon: _serviceIcon(_filtered[i].serviceType),
                            onTap: () => _openDetail(_filtered[i]),
                            onToggleCheckInOut: () => _toggleCheckInOut(_filtered[i]),
                          ),
                        ),
                        childCount: _filtered.length,
                      ),
                    ),
                  ),
                ] else if (_viewMode == 'calendar') ...[
                  SliverToBoxAdapter(child: _buildCalendar()),
                  SliverToBoxAdapter(child: _buildAgendaHeader()),
                  _agendaList.isEmpty
                      ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text('No services on this day',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                      ),
                    ),
                  )
                      : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ServiceCard(
                            record: _agendaList[i],
                            statusColor: _statusColor(_agendaList[i].status),
                            icon: _serviceIcon(_agendaList[i].serviceType),
                            onTap: () => _openDetail(_agendaList[i]),
                            onToggleCheckInOut: () => _toggleCheckInOut(_agendaList[i]),
                          ),
                        ),
                        childCount: _agendaList.length,
                      ),
                    ),
                  ),
                ] else ...[
                  // ── History ──────────────────────────────────────────
                  SliverToBoxAdapter(child: _buildHistorySearchRow()),
                  SliverToBoxAdapter(child: _buildHistoryInOutFilterRow()),
                  _historyFiltered.isEmpty
                      ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Column(children: [
                          Icon(Icons.history_rounded, size: 44, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('No matching history', style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600)),
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
                          child: _HistoryCard(record: _historyFiltered[i]),
                        ),
                        childCount: _historyFiltered.length,
                      ),
                    ),
                  ),
                ],
              ],
          ],
        ),
      ),
      floatingActionButton: MediaQuery.of(context).viewInsets.bottom > 0
          ? null
          : EditGuard(
        child: FloatingActionButton.extended(
          onPressed: _openAdd,
          backgroundColor: kTeal,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('Add Service', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  List<DroneServiceRecord> get _agendaList {
    final day = _selectedDay ?? DateTime.now();
    return _filtered.where((s) =>
    s.scheduledAt.year == day.year &&
        s.scheduledAt.month == day.month &&
        s.scheduledAt.day == day.day).toList()
      ..sort((a, b) => _sortAscending
          ? a.scheduledAt.compareTo(b.scheduledAt)
          : b.scheduledAt.compareTo(a.scheduledAt));
  }

  // ── History (embedded — same screen, third view mode) ───────────────────

  List<DroneServiceRecord> get _historyFiltered {
    var list = _branchOnly.where((r) {
      final matchSearch = _historySearch.isEmpty ||
          r.droneName.toLowerCase().contains(_historySearch.toLowerCase()) ||
          r.serviceType.toLowerCase().contains(_historySearch.toLowerCase()) ||
          r.technician.toLowerCase().contains(_historySearch.toLowerCase()) ||
          (r.customerName ?? '').toLowerCase().contains(_historySearch.toLowerCase()) ||
          (r.customerPhone ?? '').contains(_historySearch) ||
          (r.checkedInBy ?? '').toLowerCase().contains(_historySearch.toLowerCase()) ||
          (r.checkedOutBy ?? '').toLowerCase().contains(_historySearch.toLowerCase());
      final matchInOut = switch (_historyInOutFilter) {
        'checkedIn' => r.isDroneCheckedIn,
        'checkedOut' => r.isDroneCheckedOut,
        'awaiting' => r.checkedInAt == null,
        _ => true,
      };
      return matchSearch && matchInOut;
    }).toList();
    // Most recent activity first: prefer check-out time, then check-in
    // time, then when it was scheduled.
    list.sort((a, b) {
      final at = a.checkedOutAt ?? a.checkedInAt ?? a.scheduledAt;
      final bt = b.checkedOutAt ?? b.checkedInAt ?? b.scheduledAt;
      return bt.compareTo(at);
    });
    return list;
  }

  Map<String, int> get _historyStats {
    final list = _branchOnly;
    return {
      'total': list.length,
      'checkedIn': list.where((r) => r.isDroneCheckedIn).length,
      'checkedOut': list.where((r) => r.isDroneCheckedOut).length,
      'awaiting': list.where((r) => r.checkedInAt == null).length,
    };
  }

  Widget _buildHistoryStatsRow() {
    final s = _historyStats;
    Widget card(String label, int value, Color color, IconData icon) => Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text('$value', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kNavy)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(children: [
        card('Total', s['total']!, kNavy, Icons.miscellaneous_services_rounded),
        card('At Shop', s['checkedIn']!, kTeal, Icons.garage_rounded),
        card('Handed Back', s['checkedOut']!, kGreen, Icons.task_alt_rounded),
        card('Awaiting', s['awaiting']!, Colors.grey.shade500, Icons.hourglass_empty_rounded),
      ]),
    );
  }

  Widget _buildHistorySearchRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        onChanged: (v) => setState(() => _historySearch = v),
        cursorColor: kNavy,
        style: const TextStyle(color: kNavy, fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'Search drone, customer, phone, handled by…',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildHistoryInOutFilterRow() {
    Widget chip(String label, String value, Color color) {
      final selected = _historyInOutFilter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : color)),
          selected: selected,
          onSelected: (_) => setState(() => _historyInOutFilter = value),
          selectedColor: color,
          backgroundColor: color.withValues(alpha: 0.08),
          showCheckmark: false,
          side: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: SizedBox(
        height: 34,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            chip('All', 'all', kNavy),
            chip('Currently at shop', 'checkedIn', kTeal),
            chip('Handed back out', 'checkedOut', kGreen),
            chip('Not checked in yet', 'awaiting', Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: kNavy,
      pinned: true,
      expandedHeight: 108,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 16),
        title: const Text('Drone Services',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kNavy, Color(0xFF162944)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final s = _stats;
    Widget card(String label, int value, Color color, IconData icon) => Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text('$value', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kNavy)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(children: [
        card('Total', s['total']!, kNavy, Icons.miscellaneous_services_rounded),
        card('Scheduled', s['Scheduled']!, kPurple, Icons.event_rounded),
        card(kServiceStatusLabels['In Progress']!, s['In Progress']!, kAmber, Icons.login_rounded),
        card(kServiceStatusLabels['Completed']!, s['Completed']!, kGreen, Icons.check_circle_rounded),
      ]),
    );
  }

  Widget _buildBranchFilterRow() {
    Widget chip(String label, String value) {
      final selected = _branchFilter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label, style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : kNavy)),
          selected: selected,
          onSelected: (_) => setState(() => _branchFilter = value),
          selectedColor: kNavy,
          backgroundColor: Colors.white,
          showCheckmark: false,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: selected ? kNavy : Colors.grey.shade300),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          chip('All Branch', DroneServiceBookingService.branchAll),
          for (final b in kBranchOptions) chip(kBranchLabels[b] ?? b, b),
        ]),
      ),
    );
  }

  Widget _buildViewToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(child: _toggleBtn('List', Icons.view_list_rounded, _viewMode == 'list', () => setState(() => _viewMode = 'list'))),
          Expanded(child: _toggleBtn('Calendar', Icons.calendar_month_rounded, _viewMode == 'calendar', () => setState(() => _viewMode = 'calendar'))),
          Expanded(child: _toggleBtn('History', Icons.history_rounded, _viewMode == 'history', _openHistory)),
        ]),
      ),
    );
  }

  Widget _toggleBtn(String label, IconData icon, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? kTeal : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: selected ? Colors.white : Colors.grey.shade500),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndStatusRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(children: [
        TextField(
          onChanged: (v) => setState(() => _search = v),
          cursorColor: kNavy,
          style: const TextStyle(color: kNavy, fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Search drone, customer, phone, technician…',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _statusChip('All', DroneServiceBookingService.statusAll, kNavy),
              for (final s in kServiceStatuses) _statusChip(kServiceStatusLabels[s] ?? s, s, _statusColor(s)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildSortRow(),
      ]),
    );
  }

  Widget _buildSortRow() {
    Widget chip(String label, bool ascending, IconData icon) {
      final selected = _sortAscending == ascending;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          avatar: Icon(icon, size: 14, color: selected ? Colors.white : kNavy),
          label: Text(label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : kNavy)),
          selected: selected,
          onSelected: (_) => setState(() => _sortAscending = ascending),
          selectedColor: kTeal,
          backgroundColor: Colors.white,
          showCheckmark: false,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: selected ? kTeal : Colors.grey.shade300),
          ),
        ),
      );
    }

    return Row(children: [
      Icon(Icons.sort_rounded, size: 15, color: Colors.grey.shade500),
      const SizedBox(width: 6),
      chip('Oldest → Newest', true, Icons.arrow_upward_rounded),
      chip('Newest → Oldest', false, Icons.arrow_downward_rounded),
    ]);
  }

  Widget _statusChip(String label, String value, Color color) {
    final selected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : color)),
        selected: selected,
        onSelected: (_) => setState(() => _statusFilter = value),
        selectedColor: color,
        backgroundColor: color.withValues(alpha: 0.08),
        showCheckmark: false,
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
    );
  }

  Widget _buildCalendar() {
    final markers = <DateTime, List<Color>>{};
    for (final s in _filtered) {
      final key = DateTime(s.scheduledAt.year, s.scheduledAt.month, s.scheduledAt.day);
      markers.putIfAbsent(key, () => []).add(_statusColor(s.status));
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: ServiceMonthCalendar(
        focusedMonth: _focusedMonth,
        selectedDay: _selectedDay,
        dayMarkers: markers,
        accent: kTeal,
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
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kNavy)),
      ]),
    );
  }
}

// ── SERVICE CARD ──────────────────────────────────────────────────────────

class _ServiceCard extends StatelessWidget {
  final DroneServiceRecord record;
  final Color statusColor;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onToggleCheckInOut;
  const _ServiceCard({
    required this.record,
    required this.statusColor,
    required this.icon,
    required this.onTap,
    required this.onToggleCheckInOut,
  });

  @override
  Widget build(BuildContext context) {
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
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(record.serviceType,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0A1628))),
                      const SizedBox(height: 3),
                      Text('${record.droneName} · ${kBranchLabels[record.branch] ?? record.branch}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      const SizedBox(height: 5),
                      Row(children: [
                        Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text(DateFormat('d MMM, h:mm a').format(record.scheduledAt),
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
                        if (record.technician.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.person_outline_rounded, size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Flexible(child: Text(record.technician, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500))),
                        ],
                      ]),
                      if (record.isPastSchedule) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B6B).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.warning_amber_rounded, size: 13, color: Color(0xFFFF6B6B)),
                            const SizedBox(width: 4),
                            Text(
                              'Overdue by ${DroneServiceAlertService.formatOverdue(record.overdueBy)}',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFFFF6B6B)),
                            ),
                          ]),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text(kServiceStatusLabels[record.status] ?? record.status, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: statusColor)),
                ),
              ]),
              const Divider(height: 18),
              _CheckInOutRow(record: record, onToggle: onToggleCheckInOut),
            ],
          ),
        ),
      ),
    );
  }
}

// ── DRONE IN/OUT TOGGLE ROW ─────────────────────────────────────────────
// Compact, reusable "is the drone physically here right now?" row: a
// toggle switch plus a one-line summary of the in/out timestamps. Used on
// both the list card and the detail sheet so the two never drift apart.

class _CheckInOutRow extends StatelessWidget {
  final DroneServiceRecord record;
  final VoidCallback onToggle;
  const _CheckInOutRow({required this.record, required this.onToggle});

  static const Color kNavy = Color(0xFF0A1628);
  static const Color kTeal = Color(0xFF00D4AA);
  static const Color kGreen = Color(0xFF00B894);

  @override
  Widget build(BuildContext context) {
    final checkedIn = record.isDroneCheckedIn;
    final checkedOut = record.isDroneCheckedOut;
    final fmt = DateFormat('d MMM, h:mm a');

    String label;
    String? subLabel;
    Color color;
    if (checkedOut) {
      label = 'Drone handed back out';
      subLabel = 'In: ${fmt.format(record.checkedInAt!)}  ·  Out: ${fmt.format(record.checkedOutAt!)}';
      color = kGreen;
    } else if (checkedIn) {
      label = 'Drone is at the shop';
      subLabel = 'Checked in ${fmt.format(record.checkedInAt!)}'
          '${record.checkedInBy != null && record.checkedInBy!.isNotEmpty ? ' by ${record.checkedInBy}' : ''}';
      color = kTeal;
    } else {
      label = 'Awaiting drone drop-off';
      subLabel = null;
      color = Colors.grey.shade400;
    }

    return Row(children: [
      Icon(
        checkedOut ? Icons.task_alt_rounded : (checkedIn ? Icons.garage_rounded : Icons.hourglass_empty_rounded),
        size: 15,
        color: color,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: checkedOut ? kGreen : kNavy)),
            if (subLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(subLabel, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
              ),
          ],
        ),
      ),
      if (!checkedOut)
        Switch(
          value: checkedIn,
          onChanged: (_) => onToggle(),
          activeThumbColor: kTeal,
        )
      else
        Icon(Icons.check_circle_rounded, size: 20, color: kGreen),
    ]);
  }
}

// ── DETAIL BOTTOM SHEET ────────────────────────────────────────────────────

// ── HISTORY CARD ─────────────────────────────────────────────────────────
// One row per booking with the full in/out trail visible at a glance,
// used by the embedded History view (third tab next to List/Calendar).

class _HistoryCard extends StatelessWidget {
  final DroneServiceRecord record;
  const _HistoryCard({required this.record});

  static const Color kNavy = Color(0xFF0A1628);
  static const Color kTeal = Color(0xFF00D4AA);
  static const Color kGreen = Color(0xFF00B894);
  static const Color kAmber = Color(0xFFFFB800);
  static const Color kCoral = Color(0xFFFF6B6B);
  static const Color kPurple = Color(0xFF6C63FF);

  Color get _statusColor {
    switch (record.status) {
      case 'Scheduled':
        return kPurple;
      case 'In Progress':
        return kAmber;
      case 'Completed':
        return kGreen;
      case 'Cancelled':
        return kCoral;
      default:
        return Colors.grey;
    }
  }

  String get _durationLabel {
    final d = record.turnaroundDuration;
    if (d == null) return '—';
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy, h:mm a');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.droneName, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: kNavy)),
                  const SizedBox(height: 2),
                  Text('${record.serviceType} · ${kBranchLabels[record.branch] ?? record.branch}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(kServiceStatusLabels[record.status] ?? record.status, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: _statusColor)),
            ),
          ]),
          const SizedBox(height: 10),
          if (record.technician.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Icon(Icons.engineering_outlined, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 6),
                Text('Serviced by ', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                Text(record.technician, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kNavy)),
              ]),
            ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _trailRow(
                  icon: Icons.login_rounded,
                  iconColor: kTeal,
                  label: 'In',
                  value: record.checkedInAt != null ? fmt.format(record.checkedInAt!) : 'Not checked in',
                  by: record.checkedInBy,
                ),
                const SizedBox(height: 6),
                _trailRow(
                  icon: Icons.logout_rounded,
                  iconColor: kGreen,
                  label: 'Out',
                  value: record.checkedOutAt != null ? fmt.format(record.checkedOutAt!) : 'Not handed back yet',
                  by: record.checkedOutBy,
                ),
                if (record.turnaroundDuration != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.timelapse_rounded, size: 13, color: Colors.grey.shade400),
                    const SizedBox(width: 6),
                    Text('Turnaround: $_durationLabel', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _trailRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    String? by,
  }) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 14, color: iconColor),
      const SizedBox(width: 8),
      SizedBox(width: 28, child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.grey.shade500))),
      Expanded(
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kNavy)),
              if (by != null && by.isNotEmpty)
                TextSpan(text: '  ·  $by', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
            ],
          ),
        ),
      ),
    ]);
  }
}

class _ServiceDetailSheet extends StatelessWidget {
  final DroneServiceRecord record;
  final Color Function(String) statusColor;
  final VoidCallback onStart;
  final VoidCallback onComplete;
  final VoidCallback onCancel;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onToggleCheckInOut;
  const _ServiceDetailSheet({
    required this.record,
    required this.statusColor,
    required this.onStart,
    required this.onComplete,
    required this.onCancel,
    required this.onDelete,
    required this.onEdit,
    required this.onToggleCheckInOut,
  });

  @override
  Widget build(BuildContext context) {
    final color = statusColor(record.status);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: Text(record.serviceType, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0A1628))),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(kServiceStatusLongLabels[record.status] ?? record.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
            ),
          ]),
          const SizedBox(height: 14),
          _row(Icons.airplanemode_active_rounded, 'Drone / Asset', record.droneName),
          _row(Icons.apartment_rounded, 'Branch', kBranchLabels[record.branch] ?? record.branch),
          _row(Icons.event_rounded, 'Scheduled', DateFormat('EEE, d MMM yyyy · h:mm a').format(record.scheduledAt)),
          _row(Icons.person_outline_rounded, 'Technician', record.technician.isEmpty ? '—' : record.technician),
          if ((record.customerName ?? '').trim().isNotEmpty) _row(Icons.person_pin_rounded, 'Customer', record.customerName!),
          if ((record.customerPhone ?? '').trim().isNotEmpty) _row(Icons.phone_outlined, 'Phone', record.customerPhone!),
          if ((record.customerAddress ?? '').trim().isNotEmpty) _row(Icons.location_on_outlined, 'Address', record.customerAddress!),
          if ((record.issueDescription ?? '').trim().isNotEmpty) _row(Icons.report_problem_outlined, 'Issue', record.issueDescription!),
          _row(Icons.flag_outlined, 'Priority', record.priority),
          if (record.cost != null) _row(Icons.currency_rupee_rounded, 'Cost', record.cost!.toStringAsFixed(2)),
          if (record.notes != null && record.notes!.trim().isNotEmpty) _row(Icons.notes_rounded, 'Notes', record.notes!),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _CheckInOutRow(record: record, onToggle: onToggleCheckInOut),
          ),
          const SizedBox(height: 18),
          if (record.status == 'Scheduled' || record.status == 'In Progress')
            Row(children: [
              if (record.status == 'Scheduled')
                Expanded(
                  child: _actionBtn('Start', Icons.play_arrow_rounded, const Color(0xFFFFB800), () {
                    Navigator.pop(context);
                    onStart();
                  }),
                ),
              if (record.status == 'Scheduled') const SizedBox(width: 8),
              Expanded(
                child: _actionBtn('Complete', Icons.check_rounded, const Color(0xFF00B894), () {
                  Navigator.pop(context);
                  onComplete();
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionBtn('Cancel', Icons.close_rounded, const Color(0xFFFF6B6B), () {
                  Navigator.pop(context);
                  onCancel();
                }),
              ),
            ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF0A1628), padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onDelete();
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFFF6B6B)),
                label: const Text('Delete', style: TextStyle(color: Color(0xFFFF6B6B))),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFFF6B6B)), padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 15, color: Colors.grey.shade400),
        const SizedBox(width: 10),
        SizedBox(width: 90, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0A1628)))),
      ]),
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ── CHECK-IN / CHECK-OUT DIALOG ──────────────────────────────────────────
// Captures exactly who handed over / received the drone and exactly when,
// so the history page can show a complete in/out trail. Defaults to "now"
// and the current logged-in user, both editable.

class _CheckInOutEntry {
  final String handledBy;
  final DateTime time;
  const _CheckInOutEntry({required this.handledBy, required this.time});
}

class _CheckInOutDialog extends StatefulWidget {
  final DroneServiceRecord record;
  final bool isCheckingIn;
  final String? defaultName;
  const _CheckInOutDialog({
    required this.record,
    required this.isCheckingIn,
    this.defaultName,
  });

  @override
  State<_CheckInOutDialog> createState() => _CheckInOutDialogState();
}

class _CheckInOutDialogState extends State<_CheckInOutDialog> {
  static const Color kNavy = Color(0xFF0A1628);
  static const Color kTeal = Color(0xFF00D4AA);
  static const Color kGreen = Color(0xFF00B894);

  late final TextEditingController _nameCtrl;
  late DateTime _when;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.defaultName ?? '');
    _when = DateTime.now();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Color get _accent => widget.isCheckingIn ? kTeal : kGreen;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: ColorScheme.light(primary: _accent)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _when = DateTime(picked.year, picked.month, picked.day, _when.hour, _when.minute));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: ColorScheme.light(primary: _accent)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _when = DateTime(_when.year, _when.month, _when.day, picked.hour, picked.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isCheckingIn ? 'Check In Drone' : 'Check Out Drone';
    final subtitle = widget.isCheckingIn
        ? '${widget.record.droneName} has arrived for service'
        : '${widget.record.droneName} is being handed back';
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _accent.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(widget.isCheckingIn ? Icons.login_rounded : Icons.logout_rounded, color: _accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kNavy)),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              readOnly: true, // auto-filled from login — not editable
              enableInteractiveSelection: false,
              style: const TextStyle(color: kNavy, fontSize: 14, fontWeight: FontWeight.w600),
              cursorColor: _accent,
              decoration: InputDecoration(
                suffixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                labelText: widget.isCheckingIn ? 'Received by (auto)' : 'Handed over by (auto)',
                labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                prefixIcon: Icon(Icons.person_outline_rounded, color: _accent, size: 20),
                filled: true,
                fillColor: const Color(0xFFF0F4F8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _accent, width: 1.5)),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
                    decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Icon(Icons.calendar_month_outlined, size: 16, color: _accent),
                      const SizedBox(width: 8),
                      Text(DateFormat('d MMM yyyy').format(_when), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kNavy)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: _pickTime,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
                    decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Icon(Icons.access_time_rounded, size: 16, color: _accent),
                      const SizedBox(width: 8),
                      Text(DateFormat('h:mm a').format(_when), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kNavy)),
                    ]),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final name = _nameCtrl.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a name')),
                      );
                      return;
                    }
                    Navigator.pop(context, _CheckInOutEntry(handledBy: name, time: _when));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(widget.isCheckingIn ? 'Check In' : 'Check Out',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── EMPTY / ERROR ──────────────────────────────────────────────────────────
// Both views use Center + SingleChildScrollView so they center normally
// when there's enough room, but become scrollable instead of overflowing
// (the yellow/black "RenderFlex overflowed" stripe) when there isn't.
//
// NOTE: Do NOT wrap these in LayoutBuilder — SliverFillRemaining requires
// its child to support returning intrinsic dimensions during some layout
// passes, and LayoutBuilder explicitly throws on that
// ("does not support returning intrinsic dimensions"). Center's default
// behavior handles sizing fine without needing LayoutBuilder at all.

class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade200, width: 2),
              ),
              child: Icon(Icons.miscellaneous_services_rounded, size: 52, color: Colors.grey.shade300),
            ),
            const SizedBox(height: 22),
            const Text('No services yet', style: TextStyle(color: Color(0xFF0A1628), fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Schedule your first drone service to begin tracking.', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Service', style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D4AA),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFFFF6B6B).withValues(alpha: 0.08), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFF6B6B).withValues(alpha: 0.3))),
              child: const Icon(Icons.cloud_off_rounded, size: 48, color: Color(0xFFFF6B6B)),
            ),
            const SizedBox(height: 20),
            const Text("Can't reach Firestore", style: TextStyle(color: Color(0xFF0A1628), fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 26),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ],
        ),
      ),
    );
  }
}

// ── MONTH CALENDAR ─────────────────────────────────────────────────────────
// Lightweight, dependency-free month-view calendar. Shows a coloured dot
// under any day that has one or more services scheduled, and lets the
// user page between months and tap a day to filter the agenda below it.
// Inlined here (rather than a separate widgets/ file) so this screen has
// no extra file to go missing when the project is copied/merged.

class ServiceMonthCalendar extends StatefulWidget {
  final DateTime focusedMonth;
  final DateTime? selectedDay;
  final Map<DateTime, List<Color>> dayMarkers; // date(y/m/d) -> dot colors
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onMonthChanged;
  final Color accent;

  const ServiceMonthCalendar({
    super.key,
    required this.focusedMonth,
    required this.selectedDay,
    required this.dayMarkers,
    required this.onDaySelected,
    required this.onMonthChanged,
    required this.accent,
  });

  @override
  State<ServiceMonthCalendar> createState() => _ServiceMonthCalendarState();
}

class _ServiceMonthCalendarState extends State<ServiceMonthCalendar> {
  static const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final month = widget.focusedMonth;
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Monday-first grid: weekday 1 (Mon) .. 7 (Sun)
    final leadingBlanks = firstOfMonth.weekday - 1;
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();
    final today = _stripTime(DateTime.now());

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              color: Colors.grey.shade600,
              onPressed: () => widget.onMonthChanged(
                  DateTime(month.year, month.month - 1, 1)),
            ),
            Text(
              _monthLabel(month),
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0A1628)),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              color: Colors.grey.shade600,
              onPressed: () => widget.onMonthChanged(
                  DateTime(month.year, month.month + 1, 1)),
            ),
          ],
        ),
        Row(
          children: _weekdayLabels
              .map((l) => Expanded(
            child: Center(
              child: Text(l,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade400)),
            ),
          ))
              .toList(),
        ),
        const SizedBox(height: 4),
        for (int r = 0; r < rows; r++)
          Row(
            children: [
              for (int c = 0; c < 7; c++) _buildCell(r, c, leadingBlanks, daysInMonth, month, today),
            ],
          ),
      ],
    );
  }

  Widget _buildCell(int r, int c, int leadingBlanks, int daysInMonth,
      DateTime month, DateTime today) {
    final cellIndex = r * 7 + c;
    final dayNum = cellIndex - leadingBlanks + 1;
    if (dayNum < 1 || dayNum > daysInMonth) {
      return const Expanded(child: SizedBox(height: 44));
    }
    final date = DateTime(month.year, month.month, dayNum);
    final isToday = date == today;
    final isSelected =
        widget.selectedDay != null && _stripTime(widget.selectedDay!) == date;
    final markers = widget.dayMarkers[date] ?? const [];

    return Expanded(
      child: GestureDetector(
        onTap: () => widget.onDaySelected(date),
        child: Container(
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? widget.accent
                : isToday
                ? widget.accent.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isToday && !isSelected
                ? Border.all(color: widget.accent.withValues(alpha: 0.5))
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$dayNum',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected || isToday ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (isToday ? widget.accent : const Color(0xFF0A1628)),
                ),
              ),
              const SizedBox(height: 2),
              if (markers.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: markers.take(3).map((c) => Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? Colors.white : c,
                    ),
                  )).toList(),
                )
              else
                const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  String _monthLabel(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }
}

// ── OVERDUE ALERT DIALOG ─────────────────────────────────────────────────
// Shown when one or more open services have gone past their scheduled date.

class _OverdueAlertDialog extends StatelessWidget {
  final List<DroneServiceRecord> items;
  final void Function(DroneServiceRecord) onView;
  const _OverdueAlertDialog({required this.items, required this.onView});

  static const Color kNavy = Color(0xFF0A1628);
  static const Color kCoral = Color(0xFFFF6B6B);

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM, h:mm a');
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Row(children: [
        const Icon(Icons.notification_important_rounded, color: kCoral),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            items.length == 1 ? 'Service overdue' : '${items.length} services overdue',
            style: const TextStyle(color: kNavy, fontWeight: FontWeight.bold),
          ),
        ),
      ]),
      content: SizedBox(
        width: 380,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 14),
            itemBuilder: (_, i) {
              final r = items[i];
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onView(r),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${r.serviceType} — ${r.droneName}',
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: kNavy)),
                    const SizedBox(height: 3),
                    Text('Scheduled ${fmt.format(r.scheduledAt)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 2),
                    Text(
                      'Overdue by ${DroneServiceAlertService.formatOverdue(r.overdueBy)}'
                          '${r.technician.isNotEmpty ? '  ·  ${r.technician}' : ''}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kCoral),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Dismiss'),
        ),
      ],
    );
  }
}