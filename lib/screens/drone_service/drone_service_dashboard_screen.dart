// lib/screens/drone_service/drone_service_dashboard_screen.dart
//
// "Drone Services" module — service & maintenance bookings, distinct from
// the Drone In/Out flight-log module. Covers all branches (All Branch /
// CDA Admin / CDA Ops), a list view and a calendar view, and an "Add
// Service" flow. Theme matched to the Drone In/Out & Invoice pages.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/drone_service_record.dart';
import '../../services/drone_service_booking_service.dart';
import '../../constants/drone_categories.dart';
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
  bool _calendarView = false;
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

  @override
  void initState() {
    super.initState();
    _load();
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
          s.technician.toLowerCase().contains(_search.toLowerCase());
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
                SliverToBoxAdapter(child: _buildStatsRow()),
                SliverToBoxAdapter(child: _buildBranchFilterRow()),
                SliverToBoxAdapter(child: _buildViewToggle()),
                if (!_calendarView) ...[
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
                          ),
                        ),
                        childCount: _filtered.length,
                      ),
                    ),
                  ),
                ] else ...[
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
                          ),
                        ),
                        childCount: _agendaList.length,
                      ),
                    ),
                  ),
                ],
              ],
          ],
        ),
      ),
      floatingActionButton: EditGuard(
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

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: kNavy,
      pinned: true,
      expandedHeight: 108,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
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
        card('In Progress', s['In Progress']!, kAmber, Icons.pending_actions_rounded),
        card('Completed', s['Completed']!, kGreen, Icons.check_circle_rounded),
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
          Expanded(child: _toggleBtn('List', Icons.view_list_rounded, !_calendarView, () => setState(() => _calendarView = false))),
          Expanded(child: _toggleBtn('Calendar', Icons.calendar_month_rounded, _calendarView, () => setState(() => _calendarView = true))),
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
          decoration: InputDecoration(
            hintText: 'Search drone, service type, technician…',
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
              for (final s in kServiceStatuses) _statusChip(s, s, _statusColor(s)),
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
  const _ServiceCard({required this.record, required this.statusColor, required this.icon, required this.onTap});

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
          child: Row(children: [
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
                ],
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(record.status, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: statusColor)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── DETAIL BOTTOM SHEET ────────────────────────────────────────────────────

class _ServiceDetailSheet extends StatelessWidget {
  final DroneServiceRecord record;
  final Color Function(String) statusColor;
  final VoidCallback onStart;
  final VoidCallback onComplete;
  final VoidCallback onCancel;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  const _ServiceDetailSheet({
    required this.record,
    required this.statusColor,
    required this.onStart,
    required this.onComplete,
    required this.onCancel,
    required this.onDelete,
    required this.onEdit,
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
              child: Text(record.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
            ),
          ]),
          const SizedBox(height: 14),
          _row(Icons.airplanemode_active_rounded, 'Drone / Asset', record.droneName),
          _row(Icons.apartment_rounded, 'Branch', kBranchLabels[record.branch] ?? record.branch),
          _row(Icons.event_rounded, 'Scheduled', DateFormat('EEE, d MMM yyyy · h:mm a').format(record.scheduledAt)),
          _row(Icons.person_outline_rounded, 'Technician', record.technician.isEmpty ? '—' : record.technician),
          _row(Icons.flag_outlined, 'Priority', record.priority),
          if (record.cost != null) _row(Icons.currency_rupee_rounded, 'Cost', record.cost!.toStringAsFixed(2)),
          if (record.notes != null && record.notes!.trim().isNotEmpty) _row(Icons.notes_rounded, 'Notes', record.notes!),
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