// lib/screens/drone/drone_in_out_screen.dart
//
// Firestore version — IDs are Strings. Theme matched to Invoice pages.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../models/drone.dart';
import '../../services/drone_service.dart';
import '../../services/drone_reminder_service.dart';
import '../../constants/drone_categories.dart';
import '../../core/access/access_scope.dart';
import 'add_drone_entry_screen.dart';
import 'edit_drone_screen.dart';
import 'drone_history_screen.dart';

class DroneInOutScreen extends StatefulWidget {
  const DroneInOutScreen({super.key});

  @override
  State<DroneInOutScreen> createState() => _DroneInOutScreenState();
}

class _DroneInOutScreenState extends State<DroneInOutScreen>
    with TickerProviderStateMixin {
  final DroneService _service = DroneService();
  List<Drone> _drones = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  String _filter = 'ALL';
  // 'ALL' | 'Branch 1' (CDA Admin) | 'Branch 2' (CDA Ops)
  String _branchFilter = 'ALL';
  // 'newest' | 'oldest' | 'date'
  String _sortOption = 'newest';
  DateTime? _sortDate; // used when _sortOption == 'date'
  final TextEditingController _searchCtrl = TextEditingController();
  late AnimationController _headerAnim;
  late AnimationController _droneAnim;
  late AnimationController _radarAnim;

  // ── Design tokens (matches Invoice pages) ──────────────────────────────────
  static const Color kNavy = Color(0xFF0A1628);
  static const Color kNavyLight = Color(0xFF162944);
  static const Color kTeal = Color(0xFF00D4AA);
  static const Color kCoral = Color(0xFFFF6B6B);
  static const Color kAmber = Color(0xFFFFB800);
  static const Color kSurface = Color(0xFFF0F4F8);
  static const Color kGreen = Color(0xFF00B894);
  static const Color kPurple = Color(0xFF6C63FF);

  @override
  void initState() {
    super.initState();
    _headerAnim =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _droneAnim =
    AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat();
    _radarAnim =
    AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
    _loadDrones();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _headerAnim.dispose();
    _droneAnim.dispose();
    _radarAnim.dispose();
    super.dispose();
  }

  Future<void> _loadDrones() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _service.getDrones();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.success) {
        _drones = result.data!;
        _headerAnim.forward(from: 0);
      } else {
        _error = result.error;
      }
    });
  }

  Future<void> _toggleStatus(Drone drone) async {
    final newStatus = drone.status == 'IN' ? 'OUT' : 'IN';
    final currentUserName = context.read<CurrentAccess>().access?.name;

    final entry = await showDialog<_DroneActionEntry>(
      context: context,
      builder: (_) => _DroneActionDialog(
        drone: drone,
        newStatus: newStatus,
        defaultName: currentUserName,
      ),
    );
    if (entry == null) return; // cancelled

    HapticFeedback.lightImpact();

    // Optimistic local update
    setState(() {
      drone.status = newStatus;
      drone.pilotName = entry.usedBy;
    });

    final result = await _service.updateStatus(
      drone.id,
      newStatus,
      performedBy: entry.usedBy,
      actionTime: entry.time,
      purpose: entry.purpose,
    );
    if (!mounted) return;
    if (result.success) {
      final purposeSuffix =
      (newStatus == 'OUT' && entry.purpose != null && entry.purpose!.isNotEmpty)
          ? ' for ${entry.purpose}'
          : '';
      _showSnack(
        '${drone.name} marked $newStatus by ${entry.usedBy}$purposeSuffix',
        icon: newStatus == 'IN' ? Icons.flight_land : Icons.flight_takeoff,
        color: newStatus == 'IN' ? kTeal : kAmber,
      );
      // 4-hour "did you forget to bring it back?" reminder for this drone.
      // Replaces any reminder already pending for it. Only fires for OUT —
      // see DroneReminderService.scheduleReminder.
      DroneReminderService.instance.scheduleReminder(
        droneId: drone.id,
        droneName: drone.name,
        newStatus: newStatus,
        actionTime: entry.time,
        purpose: entry.purpose,
      );
    } else {
      // Roll back
      setState(() => drone.status = newStatus == 'IN' ? 'OUT' : 'IN');
      _showSnack('Update failed: ${result.error}', isError: true);
    }
  }

  Future<void> _deleteDrone(Drone drone) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Remove drone?',
        body: '"${drone.name}" will be permanently removed from the fleet.',
        confirmLabel: 'Remove',
        confirmColor: kCoral,
      ),
    );
    if (confirmed != true) return;
    final result = await _service.deleteDrone(drone.id);
    if (!mounted) return;
    if (result.success) {
      DroneReminderService.instance.cancelReminder(drone.id);
      setState(() => _drones.removeWhere((d) => d.id == drone.id));
      _showSnack('${drone.name} removed', icon: Icons.delete_outline);
    } else {
      _showSnack('Delete failed: ${result.error}', isError: true);
    }
  }

  Future<void> _openAdd() async {
    final added = await Navigator.push(
        context, _slide(AddDroneEntryScreen(service: _service)));
    if (added == true) _loadDrones();
  }

  Future<void> _openEdit(Drone drone) async {
    final updated = await Navigator.push(
        context, _slide(EditDroneScreen(service: _service, drone: drone)));
    if (updated == true) _loadDrones();
  }

  void _openHistory(Drone drone) {
    Navigator.push(
        context, _slide(DroneHistoryScreen(service: _service, drone: drone)));
  }

  PageRouteBuilder<bool> _slide(Widget page) {
    return PageRouteBuilder<bool>(
      pageBuilder: (_, animation, __) => page,
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  void _showSnack(String msg,
      {bool isError = false, IconData? icon, Color? color}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8)
          ],
          Flexible(
              child: Text(msg, style: const TextStyle(color: Colors.white))),
        ]),
        backgroundColor: isError ? kCoral : (color ?? kTeal),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  List<Drone> get _filtered => _drones.where((d) {
    final matchSearch = _search.isEmpty ||
        d.name.toLowerCase().contains(_search.toLowerCase()) ||
        d.model.toLowerCase().contains(_search.toLowerCase()) ||
        d.serialNumber.toLowerCase().contains(_search.toLowerCase()) ||
        (d.pilotName ?? '').toLowerCase().contains(_search.toLowerCase());
    final matchFilter = _filter == 'ALL' || d.status == _filter;
    final matchBranch = _branchFilter == 'ALL' || d.branch == _branchFilter;
    final matchDate = _sortOption != 'date' ||
        _sortDate == null ||
        (d.lastUpdated != null && _isSameDate(d.lastUpdated!, _sortDate!));
    return matchSearch && matchFilter && matchBranch && matchDate;
  }).toList()
    ..sort((a, b) {
      final at = a.lastUpdated;
      final bt = b.lastUpdated;
      if (at == null && bt == null) return 0;
      if (at == null) return 1; // undated drones sink to the bottom
      if (bt == null) return -1;
      return _sortOption == 'oldest' ? at.compareTo(bt) : bt.compareTo(at);
    });

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  int _branchCount(String branch) =>
      _drones.where((d) => d.branch == branch).length;

  int get _inCount => _drones.where((d) => d.status == 'IN').length;
  int get _outCount => _drones.where((d) => d.status == 'OUT').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _DroneHeaderDelegate(
              droneAnim: _droneAnim,
              radarAnim: _radarAnim,
              headerAnim: _headerAnim,
              drones: _drones,
              inCount: _inCount,
              outCount: _outCount,
              loading: _loading,
              onRefresh: _loadDrones,
              onBack: () => Navigator.maybePop(context),
            ),
          ),
          if (!_loading && _error == null && _drones.isNotEmpty)
            SliverToBoxAdapter(child: _buildSearchBar()),
          if (!_loading && _error == null && _drones.isNotEmpty)
            SliverToBoxAdapter(child: _buildFilterRow()),
          if (!_loading && _error == null && _drones.isNotEmpty)
            SliverToBoxAdapter(child: _buildBranchFilterRow()),
          if (!_loading && _error == null && _sortOption == 'date' && _sortDate != null)
            SliverToBoxAdapter(child: _buildDateFilterChip()),
          _buildContent(),
        ],
      ),
      floatingActionButton:
      _loading || _error != null ? null : _buildFAB(),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: _openAdd,
      backgroundColor: kTeal,
      foregroundColor: Colors.white,
      elevation: 2,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      icon: const Icon(Icons.add_rounded, size: 22),
      label: const Text('Register Drone',
          style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: 0.3)),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200, width: 1),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v),
                style: const TextStyle(color: kNavy, fontSize: 14),
                cursorColor: kTeal,
                decoration: InputDecoration(
                  hintText: 'Search by name, model, serial, used by…',
                  hintStyle:
                  TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  prefixIcon:
                  const Icon(Icons.search, color: kTeal, size: 20),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.close,
                        color: Colors.grey.shade500, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _search = '');
                    },
                  )
                      : null,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _SortButton(
            sortOption: _sortOption,
            sortDate: _sortDate,
            onTap: _openSortSheet,
          ),
        ],
      ),
    );
  }

  Future<void> _openSortSheet() async {
    final result = await showModalBottomSheet<_SortSelection>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SortSheet(
        current: _sortOption,
        currentDate: _sortDate,
      ),
    );
    if (result == null) return;

    if (result.option == 'date') {
      final picked = await showDatePicker(
        context: context,
        initialDate: result.date ?? DateTime.now(),
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 1)),
      );
      if (picked == null) return; // cancelled date pick, keep old sort
      setState(() {
        _sortOption = 'date';
        _sortDate = picked;
      });
    } else {
      setState(() {
        _sortOption = result.option;
        _sortDate = null;
      });
    }
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _FilterChip(
              label: 'All',
              count: _drones.length,
              selected: _filter == 'ALL',
              color: kNavy,
              onTap: () => setState(() => _filter = 'ALL')),
          const SizedBox(width: 8),
          _FilterChip(
              label: 'IN',
              count: _inCount,
              selected: _filter == 'IN',
              color: kTeal,
              onTap: () => setState(() => _filter = 'IN')),
          const SizedBox(width: 8),
          _FilterChip(
              label: 'OUT',
              count: _outCount,
              selected: _filter == 'OUT',
              color: kAmber,
              onTap: () => setState(() => _filter = 'OUT')),
        ],
      ),
    );
  }

  Widget _buildBranchFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
                label: 'All Branch',
                count: _drones.length,
                selected: _branchFilter == 'ALL',
                color: kPurple,
                onTap: () => setState(() => _branchFilter = 'ALL')),
            for (final branch in kBranchOptions) ...[
              const SizedBox(width: 8),
              _FilterChip(
                  label: kBranchLabels[branch] ?? branch,
                  count: _branchCount(branch),
                  selected: _branchFilter == branch,
                  color: kPurple,
                  onTap: () => setState(() => _branchFilter = branch)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilterChip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: GestureDetector(
        onTap: () => setState(() {
          _sortOption = 'newest';
          _sortDate = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: kTeal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kTeal.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today_outlined, size: 13, color: kTeal),
              const SizedBox(width: 6),
              Text('Showing ${DateFormat('dd MMM yyyy').format(_sortDate!)}',
                  style: const TextStyle(
                      color: kTeal, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              const Icon(Icons.close_rounded, size: 14, color: kTeal),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PulsingDroneIcon(droneAnim: _droneAnim),
              const SizedBox(height: 20),
              const Text('Scanning fleet…',
                  style: TextStyle(
                      color: kTeal,
                      fontSize: 14,
                      letterSpacing: 1)),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return SliverFillRemaining(
          child: _ErrorView(message: _error!, onRetry: _loadDrones));
    }
    final items = _filtered;
    if (_drones.isEmpty) {
      return SliverFillRemaining(child: _EmptyView(onAdd: _openAdd));
    }
    if (items.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.search_off, size: 52, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No matches',
                style:
                TextStyle(color: Colors.grey.shade500, fontSize: 16)),
          ]),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (_, i) => _DroneCard(
            drone: items[i],
            onToggle: () => _toggleStatus(items[i]),
            onEdit: () => _openEdit(items[i]),
            onDelete: () => _deleteDrone(items[i]),
            onHistory: () => _openHistory(items[i]),
          ),
          childCount: items.length,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HEADER DELEGATE
// ══════════════════════════════════════════════════════════════════════════════

class _DroneHeaderDelegate extends SliverPersistentHeaderDelegate {
  final AnimationController droneAnim;
  final AnimationController radarAnim;
  final AnimationController headerAnim;
  final List<Drone> drones;
  final int inCount, outCount;
  final bool loading;
  final VoidCallback onRefresh;
  final VoidCallback onBack;

  static const Color kNavy = Color(0xFF0A1628);
  static const Color kNavyLight = Color(0xFF162944);
  static const Color kTeal = Color(0xFF00D4AA);
  static const Color kAmber = Color(0xFFFFB800);

  const _DroneHeaderDelegate({
    required this.droneAnim,
    required this.radarAnim,
    required this.headerAnim,
    required this.drones,
    required this.inCount,
    required this.outCount,
    required this.loading,
    required this.onRefresh,
    required this.onBack,
  });

  static const double _pinnedHeight = 56.0;
  static const double _expandedHeight = 220.0;

  @override
  double get minExtent => _pinnedHeight;

  @override
  double get maxExtent => _expandedHeight;

  @override
  bool shouldRebuild(_DroneHeaderDelegate old) => true;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final expandRatio =
    (1 - shrinkOffset / (_expandedHeight - _pinnedHeight))
        .clamp(0.0, 1.0);
    final isCollapsed = expandRatio < 0.1;

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [kNavy, kNavyLight],
              ),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          Positioned(
            right: -20,
            top: -20,
            child: AnimatedBuilder(
              animation: radarAnim,
              builder: (_, __) => CustomPaint(
                size: const Size(200, 200),
                painter: _RadarPainter(radarAnim.value),
              ),
            ),
          ),
          if (expandRatio > 0.2)
            AnimatedBuilder(
              animation: droneAnim,
              builder: (_, __) => Opacity(
                opacity: expandRatio,
                child: Stack(children: [
                  _FloatingDrone(
                      progress: droneAnim.value,
                      startX: 0.15,
                      startY: 0.25,
                      maxHeight: _expandedHeight,
                      size: 18,
                      speed: 1.0),
                  _FloatingDrone(
                      progress: droneAnim.value,
                      startX: 0.65,
                      startY: 0.45,
                      maxHeight: _expandedHeight,
                      size: 14,
                      speed: 1.4),
                  _FloatingDrone(
                      progress: droneAnim.value,
                      startX: 0.40,
                      startY: 0.60,
                      maxHeight: _expandedHeight,
                      size: 10,
                      speed: 0.7),
                ]),
              ),
            ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 16,
            child: Opacity(
              opacity: expandRatio.clamp(0.0, 1.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: kTeal.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: kTeal.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.radar,
                            color: kTeal.withOpacity(0.95),
                            size: 14),
                        const SizedBox(width: 6),
                        const Text('CHENNAI DRONE ACADEMY FLEET',
                            style: TextStyle(
                                color: kTeal,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.5)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (!loading)
                    FadeTransition(
                      opacity: headerAnim,
                      child: Row(
                        children: [
                          _StatPill(
                              label: 'Total',
                              value: '${drones.length}',
                              color: Colors.white),
                          const SizedBox(width: 10),
                          _StatPill(
                              label: 'IN',
                              value: '$inCount',
                              color: kTeal),
                          const SizedBox(width: 10),
                          _StatPill(
                              label: 'OUT',
                              value: '$outCount',
                              color: kAmber),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _pinnedHeight + statusBarHeight,
            child: Container(
              decoration: BoxDecoration(
                color: isCollapsed ? kNavy : Colors.transparent,
                border: isCollapsed
                    ? Border(
                    bottom:
                    BorderSide(color: Colors.white.withOpacity(0.08), width: 1))
                    : null,
              ),
              padding: EdgeInsets.only(top: statusBarHeight),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                    onPressed: onBack,
                  ),
                  if (isCollapsed) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: kTeal,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: kTeal.withOpacity(0.8),
                              blurRadius: 6)
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Drone Control',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          letterSpacing: 0.3),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded,
                        color: Colors.white),
                    onPressed: onRefresh,
                    tooltip: 'Refresh',
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Floating drone ────────────────────────────────────────────────────────────

class _FloatingDrone extends StatelessWidget {
  final double progress, startX, startY, maxHeight, size, speed;
  const _FloatingDrone(
      {required this.progress,
        required this.startX,
        required this.startY,
        required this.maxHeight,
        required this.size,
        required this.speed});

  @override
  Widget build(BuildContext context) {
    final t = (progress * speed) % 1.0;
    final xWave = math.sin(t * 2 * math.pi) * 0.08;
    final yWave = math.cos(t * 2 * math.pi * 0.7) * 0.06;
    final top = (maxHeight * (startY + yWave)).clamp(60.0, maxHeight - 40);
    return Positioned(
      left: MediaQuery.of(context).size.width * (startX + xWave),
      top: top,
      child: Opacity(
        opacity: 0.22,
        child: Icon(Icons.flight_rounded,
            color: const Color(0xFF00D4AA), size: size),
      ),
    );
  }
}

// ── Stat Pill ─────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatPill(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color.withOpacity(0.75),
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Filter Chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label,
        required this.count,
        required this.selected,
        required this.color,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? color.withOpacity(0.6)
                : Colors.grey.shade200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                  color: selected ? color : Colors.grey.shade500,
                  fontWeight: selected
                      ? FontWeight.w700
                      : FontWeight.w500,
                  fontSize: 13,
                )),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? color.withOpacity(0.18)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count',
                  style: TextStyle(
                    color: selected ? color : Colors.grey.shade500,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  )),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sort Button + Sheet ────────────────────────────────────────────────────────

class _SortSelection {
  final String option; // 'newest' | 'oldest' | 'date'
  final DateTime? date;
  const _SortSelection(this.option, [this.date]);
}

class _SortButton extends StatelessWidget {
  final String sortOption;
  final DateTime? sortDate;
  final VoidCallback onTap;
  const _SortButton(
      {required this.sortOption, required this.sortDate, required this.onTap});

  static const Color kNavy = Color(0xFF0A1628);
  static const Color kTeal = Color(0xFF00D4AA);

  bool get _isActive => sortOption != 'newest';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        width: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: _isActive ? kTeal.withOpacity(0.5) : Colors.grey.shade200),
          color: _isActive ? kTeal.withOpacity(0.08) : Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Icon(Icons.sort_rounded,
            color: _isActive ? kTeal : kNavy.withOpacity(0.6), size: 22),
      ),
    );
  }
}

class _SortSheet extends StatelessWidget {
  final String current;
  final DateTime? currentDate;
  const _SortSheet({required this.current, required this.currentDate});

  static const Color kNavy = Color(0xFF0A1628);
  static const Color kTeal = Color(0xFF00D4AA);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text('Sort by',
                  style: TextStyle(
                      color: kNavy, fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            _SortOptionTile(
              icon: Icons.arrow_downward_rounded,
              label: 'Newest to oldest',
              selected: current == 'newest',
              onTap: () => Navigator.pop(context, const _SortSelection('newest')),
            ),
            _SortOptionTile(
              icon: Icons.arrow_upward_rounded,
              label: 'Oldest to newest',
              selected: current == 'oldest',
              onTap: () => Navigator.pop(context, const _SortSelection('oldest')),
            ),
            _SortOptionTile(
              icon: Icons.calendar_today_outlined,
              label: current == 'date' && currentDate != null
                  ? 'Date · ${DateFormat('dd MMM yyyy').format(currentDate!)}'
                  : 'Pick a date',
              selected: current == 'date',
              onTap: () =>
                  Navigator.pop(context, _SortSelection('date', currentDate)),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _SortOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SortOptionTile(
      {required this.icon,
        required this.label,
        required this.selected,
        required this.onTap});

  static const Color kNavy = Color(0xFF0A1628);
  static const Color kTeal = Color(0xFF00D4AA);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 19, color: selected ? kTeal : Colors.grey.shade500),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: selected ? kTeal : kNavy,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
            ),
            if (selected) const Icon(Icons.check_rounded, color: kTeal, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Drone Card ────────────────────────────────────────────────────────────────

class _DroneCard extends StatefulWidget {
  final Drone drone;
  final VoidCallback onToggle, onEdit, onDelete, onHistory;
  const _DroneCard(
      {required this.drone,
        required this.onToggle,
        required this.onEdit,
        required this.onDelete,
        required this.onHistory});

  @override
  State<_DroneCard> createState() => _DroneCardState();
}

class _DroneCardState extends State<_DroneCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverAnim;

  static const Color kNavy = Color(0xFF0A1628);
  static const Color kTeal = Color(0xFF00D4AA);
  static const Color kCoral = Color(0xFFFF6B6B);
  static const Color kAmber = Color(0xFFFFB800);
  static const Color kPurple = Color(0xFF6C63FF);

  @override
  void initState() {
    super.initState();
    _hoverAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
  }

  @override
  void dispose() {
    _hoverAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isIn = widget.drone.status == 'IN';
    final statusColor = isIn ? kTeal : kAmber;

    return GestureDetector(
      onTapDown: (_) => _hoverAnim.forward(),
      onTapUp: (_) => _hoverAnim.reverse(),
      onTapCancel: () => _hoverAnim.reverse(),
      child: AnimatedBuilder(
        animation: _hoverAnim,
        builder: (_, child) => Transform.scale(
          scale: 1.0 - (_hoverAnim.value * 0.01),
          child: child,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 16,
                spreadRadius: 0,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    statusColor.withOpacity(0.9),
                    statusColor.withOpacity(0.15)
                  ]),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _StatusBadge(
                            status: widget.drone.status,
                            color: statusColor),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4F8),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.grey.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.timer_outlined,
                                  color: Colors.grey.shade500, size: 12),
                              const SizedBox(width: 4),
                              Text('${widget.drone.flightHours}h',
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Show shortened Firestore document ID
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4F8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                              '#${widget.drone.id.length > 6 ? widget.drone.id.substring(0, 6) : widget.drone.id}',
                              style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: statusColor.withOpacity(0.25)),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(Icons.flight_rounded,
                                  color: statusColor.withOpacity(0.8),
                                  size: 26),
                              if (isIn)
                                Positioned(
                                  bottom: 6,
                                  right: 6,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: kTeal,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                            color: kTeal.withOpacity(0.7),
                                            blurRadius: 4)
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(widget.drone.name,
                                  style: const TextStyle(
                                      color: kNavy,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2)),
                              const SizedBox(height: 3),
                              Text(widget.drone.model,
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.tag,
                                      size: 11,
                                      color: Colors.grey.shade400),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                        widget.drone.serialNumber,
                                        style: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 11,
                                            fontFamily: 'monospace'),
                                        overflow:
                                        TextOverflow.ellipsis),
                                  ),
                                  if (widget.drone.category !=
                                      null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2),
                                      decoration: BoxDecoration(
                                        color:
                                        const Color(0xFFF0F4F8),
                                        borderRadius:
                                        BorderRadius.circular(6),
                                        border: Border.all(
                                            color: Colors
                                                .grey.shade200),
                                      ),
                                      child: Text(
                                          widget.drone.category!,
                                          style: TextStyle(
                                              color:
                                              Colors.grey.shade600,
                                              fontSize: 10,
                                              fontWeight:
                                              FontWeight.w600)),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        _BatteryWidget(
                            level: widget.drone.batteryLevel),
                      ],
                    ),
                    if (widget.drone.pilotName != null &&
                        widget.drone.pilotName!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: kPurple.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: kPurple.withOpacity(0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_outline,
                                color: kPurple, size: 14),
                            const SizedBox(width: 6),
                            Text(widget.drone.pilotName!,
                                style: const TextStyle(
                                    color: kPurple,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                    if (widget.drone.maintenanceDue != null) ...[
                      const SizedBox(height: 8),
                      _MaintenanceBadge(
                          dueDate: widget.drone.maintenanceDue!),
                    ],
                    if (widget.drone.lastUpdated != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 11, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(_formatTime(widget.drone.lastUpdated!),
                              style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 11)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    Container(height: 1, color: Colors.grey.shade200),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: widget.onToggle,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 11),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius:
                                BorderRadius.circular(12),
                                border: Border.all(
                                    color:
                                    statusColor.withOpacity(0.4)),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  Icon(
                                      isIn
                                          ? Icons.flight_takeoff_rounded
                                          : Icons.flight_land_rounded,
                                      color: statusColor,
                                      size: 16),
                                  const SizedBox(width: 7),
                                  Text(
                                      isIn ? 'Send OUT' : 'Bring IN',
                                      style: TextStyle(
                                          color: statusColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _ActionBtn(
                            icon: Icons.history_rounded,
                            color: kPurple,
                            tooltip: 'History',
                            onTap: widget.onHistory),
                        const SizedBox(width: 8),
                        _ActionBtn(
                            icon: Icons.edit_outlined,
                            color: kAmber,
                            tooltip: 'Edit',
                            onTap: widget.onEdit),
                        const SizedBox(width: 8),
                        _ActionBtn(
                            icon: Icons.delete_outline_rounded,
                            color: kCoral,
                            tooltip: 'Delete',
                            onTap: widget.onDelete),
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

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ── Status Badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    final isIn = status == 'IN';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
              isIn
                  ? Icons.flight_land_rounded
                  : Icons.flight_takeoff_rounded,
              color: color,
              size: 13),
          const SizedBox(width: 5),
          Text(status,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.2)),
        ],
      ),
    );
  }
}

// ── Battery Widget ────────────────────────────────────────────────────────────

class _BatteryWidget extends StatelessWidget {
  final int level;
  const _BatteryWidget({required this.level});

  Color get _color {
    if (level <= 20) return const Color(0xFFFF6B6B);
    if (level <= 50) return const Color(0xFFFFB800);
    return const Color(0xFF00B894);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Icon(Icons.battery_charging_full, size: 16, color: _color),
        const SizedBox(height: 2),
        Text('$level%',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _color)),
        const SizedBox(height: 4),
        Container(
          width: 28,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: level / 100,
            child: Container(
              decoration: BoxDecoration(
                  color: _color,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Action Button ─────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
        required this.color,
        required this.tooltip,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}

// ── Maintenance Badge ─────────────────────────────────────────────────────────

class _MaintenanceBadge extends StatelessWidget {
  final DateTime dueDate;
  const _MaintenanceBadge({required this.dueDate});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysLeft =
        dueDate.difference(DateTime(now.year, now.month, now.day)).inDays;
    final overdue = daysLeft < 0;
    final dueSoon = daysLeft >= 0 && daysLeft <= 7;
    final color = overdue
        ? const Color(0xFFFF6B6B)
        : dueSoon
        ? const Color(0xFFFFB800)
        : Colors.grey.shade500;
    final label = overdue
        ? 'Overdue by ${-daysLeft}d'
        : daysLeft == 0
        ? 'Due today'
        : 'Due in ${daysLeft}d';

    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.build_outlined, color: color, size: 13),
          const SizedBox(width: 5),
          Text('Maintenance · $label',
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Confirm Dialog ────────────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final String title, body, confirmLabel;
  final Color confirmColor;
  const _ConfirmDialog(
      {required this.title,
        required this.body,
        required this.confirmLabel,
        required this.confirmColor});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      title: Row(children: [
        Icon(Icons.delete_outline_rounded, color: confirmColor),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                color: Color(0xFF0A1628), fontWeight: FontWeight.bold)),
      ]),
      content: Text(body,
          style:
          TextStyle(color: Colors.grey.shade600, height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel',
              style: TextStyle(color: Colors.grey.shade600)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11)),
          ),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

// ── IN/OUT Action Dialog (who + when) ─────────────────────────────────────────

/// Result of the "who did this, and when" dialog shown before every
/// IN/OUT toggle.
class _DroneActionEntry {
  final String usedBy;
  final DateTime time;
  final String? purpose;
  const _DroneActionEntry({required this.usedBy, required this.time, this.purpose});
}

class _DroneActionDialog extends StatefulWidget {
  final Drone drone;
  final String newStatus; // 'IN' or 'OUT'
  final String? defaultName;
  const _DroneActionDialog(
      {required this.drone, required this.newStatus, this.defaultName});

  @override
  State<_DroneActionDialog> createState() => _DroneActionDialogState();
}

class _DroneActionDialogState extends State<_DroneActionDialog> {
  static const Color kNavy = Color(0xFF0A1628);
  static const Color kTeal = Color(0xFF00D4AA);
  static const Color kAmber = Color(0xFFFFB800);

  late final TextEditingController _nameCtrl;
  late DateTime _when;
  String? _purpose;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.defaultName ?? '');
    _when = DateTime.now();
    _purpose = widget.newStatus == 'OUT' ? kDronePurposes.first : null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _when = DateTime(
          picked.year, picked.month, picked.day, _when.hour, _when.minute));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (picked != null) {
      setState(() => _when = DateTime(_when.year, _when.month, _when.day,
          picked.hour, picked.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIn = widget.newStatus == 'IN';
    final color = isIn ? kTeal : kAmber;
    final canConfirm = _nameCtrl.text.trim().isNotEmpty &&
        (isIn || (_purpose != null && _purpose!.isNotEmpty));

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Row(children: [
        Icon(isIn ? Icons.flight_land_rounded : Icons.flight_takeoff_rounded,
            color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Mark "${widget.drone.name}" ${widget.newStatus}',
              style: const TextStyle(color: kNavy, fontWeight: FontWeight.bold)),
        ),
      ]),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Used by',
                style: TextStyle(
                    color: kNavy, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              onChanged: (_) => setState(() {}),
              autofocus: widget.defaultName == null || widget.defaultName!.isEmpty,
              style: const TextStyle(color: kNavy, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Name of the person doing this',
                prefixIcon: const Icon(Icons.person_outline, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            if (!isIn) ...[
              const SizedBox(height: 16),
              const Text('Purpose',
                  style: TextStyle(
                      color: kNavy, fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _purpose,
                isExpanded: true,
                style: const TextStyle(color: kNavy, fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.flag_outlined, size: 20),
                  border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: kDronePurposes
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => setState(() => _purpose = v),
              ),
            ],
            const SizedBox(height: 16),
            const Text('Date & time',
                style: TextStyle(
                    color: kNavy, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _PickerField(
                    icon: Icons.calendar_today_outlined,
                    label: DateFormat('dd MMM yyyy').format(_when),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PickerField(
                    icon: Icons.access_time,
                    label: DateFormat('hh:mm a').format(_when),
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
        ),
        ElevatedButton(
          onPressed: canConfirm
              ? () => Navigator.pop(
              context,
              _DroneActionEntry(
                  usedBy: _nameCtrl.text.trim(),
                  time: _when,
                  purpose: isIn ? null : _purpose))
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
          child: Text('Confirm ${widget.newStatus}'),
        ),
      ],
    );
  }
}

class _PickerField extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PickerField(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label,
                  style: const TextStyle(
                      color: Color(0xFF0A1628),
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Loading / Empty / Error ───────────────────────────────────────────────────

class _PulsingDroneIcon extends StatelessWidget {
  final AnimationController droneAnim;
  const _PulsingDroneIcon({required this.droneAnim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: droneAnim,
      builder: (_, __) {
        final pulse = (math.sin(droneAnim.value * 2 * math.pi) + 1) / 2;
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: const Color(0xFF00D4AA)
                    .withOpacity(0.2 + pulse * 0.3),
                width: 1.5),
            color: const Color(0xFF00D4AA)
                .withOpacity(0.05 + pulse * 0.05),
          ),
          child: Icon(Icons.flight_rounded,
              color: const Color(0xFF00D4AA)
                  .withOpacity(0.7 + pulse * 0.3),
              size: 36),
        );
      },
    );
  }
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border:
              Border.all(color: Colors.grey.shade200, width: 2),
            ),
            child: Icon(Icons.flight_rounded,
                size: 52, color: Colors.grey.shade300),
          ),
          const SizedBox(height: 22),
          const Text('Fleet is empty',
              style: TextStyle(
                  color: Color(0xFF0A1628),
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Register your first drone to begin tracking.',
              style:
              TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Register Drone',
                style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D4AA),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B).withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFFFF6B6B).withOpacity(0.3)),
              ),
              child: const Icon(Icons.cloud_off_rounded,
                  size: 48, color: Color(0xFFFF6B6B)),
            ),
            const SizedBox(height: 20),
            const Text("Can't reach Firestore",
                style: TextStyle(
                    color: Color(0xFF0A1628),
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 6),
            Text(
                'Check your Firebase project config and Firestore security rules.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey.shade400, fontSize: 12)),
            const SizedBox(height: 26),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Painters ──────────────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 0.5;
    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _RadarPainter extends CustomPainter {
  final double progress;
  _RadarPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width, 0);
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(
          center,
          i * 35.0,
          Paint()
            ..color = const Color(0xFF00D4AA).withOpacity(0.08)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5);
    }
    final angle = progress * 2 * math.pi;
    canvas.drawLine(
        center,
        Offset(center.dx + 140 * math.cos(angle),
            center.dy + 140 * math.sin(angle)),
        Paint()
          ..color = const Color(0xFF00D4AA).withOpacity(0.25)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.progress != progress;
}