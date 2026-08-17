// lib/screens/drone_tracking/drone_inout_history_screen.dart
//
// Fleet-wide Drone In/Out history — every check-in / check-out entry across
// every drone, newest first, so staff can see who used which drone and
// when. (The existing DroneHistoryScreen shows this scoped to one drone;
// this screen is the combined/all-drones view, reached from the Drone
// In/Out module's app bar.)

import 'package:flutter/material.dart';
import '../../models/drone.dart';
import '../../services/drone_service.dart';

class DroneInOutHistoryScreen extends StatefulWidget {
  final DroneService service;
  const DroneInOutHistoryScreen({super.key, required this.service});

  @override
  State<DroneInOutHistoryScreen> createState() =>
      _DroneInOutHistoryScreenState();
}

class _DroneInOutHistoryScreenState extends State<DroneInOutHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<DroneHistory> _history = [];
  Map<String, Drone> _droneById = {};

  String _search = '';
  String _statusFilter = 'ALL'; // 'ALL' | 'IN' | 'OUT'
  final _searchCtrl = TextEditingController();

  // ── Design tokens (matches Drone In/Out & history screens) ────────────
  static const Color kNavy = Color(0xFF0A1628);
  static const Color kTeal = Color(0xFF00D4AA);
  static const Color kCoral = Color(0xFFFF6B6B);
  static const Color kAmber = Color(0xFFFFB800);
  static const Color kSurface = Color(0xFFF0F4F8);
  static const Color kPurple = Color(0xFF6C63FF);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final results = await Future.wait([
      widget.service.getAllHistory(),
      widget.service.getDrones(),
    ]);
    if (!mounted) return;
    final historyResult = results[0] as ApiResult<List<DroneHistory>>;
    final dronesResult = results[1] as ApiResult<List<Drone>>;

    if (!historyResult.success) {
      setState(() {
        _loading = false;
        _error = historyResult.error;
      });
      return;
    }
    setState(() {
      _loading = false;
      _history = historyResult.data!;
      _droneById = {
        for (final d in dronesResult.data ?? const <Drone>[]) d.id: d,
      };
    });
  }

  List<DroneHistory> get _filtered => _history.where((h) {
    final drone = _droneById[h.droneId];
    final droneName = drone?.name ?? '';
    final model = drone?.model ?? '';
    final matchSearch = _search.isEmpty ||
        droneName.toLowerCase().contains(_search.toLowerCase()) ||
        model.toLowerCase().contains(_search.toLowerCase()) ||
        h.pilot.toLowerCase().contains(_search.toLowerCase()) ||
        (h.purpose ?? '').toLowerCase().contains(_search.toLowerCase());
    final matchStatus = _statusFilter == 'ALL' || h.status == _statusFilter;
    return matchSearch && matchStatus;
  }).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        title: const Text('Drone In / Out History',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_loading && _error == null && _history.isNotEmpty) ...[
            _buildSearchBar(),
            _buildFilterRow(),
          ],
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
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
            hintText: 'Search by drone, model or used by…',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: kTeal, size: 20),
            suffixIcon: _search.isNotEmpty
                ? IconButton(
              icon: Icon(Icons.close, color: Colors.grey.shade500, size: 18),
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
    );
  }

  Widget _buildFilterRow() {
    final options = ['ALL', 'IN', 'OUT'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: options.map((opt) {
          final selected = _statusFilter == opt;
          final label = opt == 'ALL'
              ? 'All'
              : opt == 'IN'
              ? 'Checked In'
              : 'Checked Out';
          final color = opt == 'IN'
              ? kTeal
              : opt == 'OUT'
              ? kAmber
              : kNavy;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _statusFilter = opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? color.withValues(alpha: 0.12) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: selected ? color : Colors.grey.shade200,
                      width: selected ? 1.5 : 1),
                ),
                child: Text(label,
                    style: TextStyle(
                        color: selected ? color : Colors.grey.shade500,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kTeal));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, color: kCoral, size: 40),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    final filtered = _filtered;
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_rounded, color: Colors.grey.shade300, size: 48),
              const SizedBox(height: 12),
              Text(
                _history.isEmpty
                    ? 'No drone activity yet'
                    : 'No entries match your search/filter',
                style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: kTeal,
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: filtered.length,
        itemBuilder: (context, i) => _historyCard(filtered[i]),
      ),
    );
  }

  Widget _historyCard(DroneHistory entry) {
    final drone = _droneById[entry.droneId];
    final isIn = entry.status == 'IN';
    final color = isIn ? kTeal : kAmber;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withValues(alpha: 0.8), color.withValues(alpha: 0.15)]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: color.withValues(alpha: 0.4)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(isIn ? Icons.login_rounded : Icons.logout_rounded, size: 12, color: color),
                        const SizedBox(width: 4),
                        Text(isIn ? 'CHECKED IN' : 'CHECKED OUT',
                            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.6)),
                      ]),
                    ),
                    const Spacer(),
                    Icon(Icons.access_time, color: Colors.grey.shade400, size: 12),
                    const SizedBox(width: 5),
                    Text(entry.time, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Icon(Icons.flight_rounded, color: kNavy, size: 15),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      drone != null ? '${drone.name} (${drone.model})' : 'Unknown drone',
                      style: const TextStyle(color: kNavy, fontSize: 14, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(color: kPurple.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.person_outline, color: kPurple, size: 14),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    entry.pilot.isEmpty ? 'Used by: Unknown' : 'Used by: ${entry.pilot}',
                    style: const TextStyle(color: kNavy, fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                ]),
                if (entry.purpose != null && entry.purpose!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.flag_outlined, color: Colors.grey.shade400, size: 13),
                    const SizedBox(width: 7),
                    Text('Purpose: ${entry.purpose}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ],
                if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.notes, color: Colors.grey.shade400, size: 13),
                        const SizedBox(width: 7),
                        Expanded(child: Text(entry.notes!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
