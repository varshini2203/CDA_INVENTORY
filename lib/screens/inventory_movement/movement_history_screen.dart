// lib/screens/inventory_movement/movement_history_screen.dart
//
// Filterable Movement History — v2. Filters: Today / This Week / This
// Month, Movement Type, Direction (Checked Out / Checked In / Still Out),
// Destination. No more Status/Pending/Approved filter.

import 'package:flutter/material.dart';

import '../../models/inventory_movement.dart';
import '../../services/inventory_movement_service.dart';
import '../../shared/inventory_ui.dart';
import 'add_movement_screen.dart';
import 'movement_detail_screen.dart';

class MovementHistoryScreen extends StatefulWidget {
  final String initialDirection;
  final String initialDateFilter;

  const MovementHistoryScreen({
    super.key,
    this.initialDirection = 'All',
    this.initialDateFilter = 'All',
  });

  @override
  State<MovementHistoryScreen> createState() => _MovementHistoryScreenState();
}

class _MovementHistoryScreenState extends State<MovementHistoryScreen> {
  late String _dateFilter = widget.initialDateFilter;
  late String _direction = widget.initialDirection;
  String _movementType = 'All';
  final _destinationController = TextEditingController();

  static const _dateFilters = ['All', 'Today', 'This Week', 'This Month'];
  static const _directions = ['All', 'Checked Out', 'Checked In', 'Open'];
  static const _types = ['All', ...MovementType.all];

  List<InventoryMovement> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() => _loading = true);
    try {
      final list = await InventoryMovementService.fetchHistory(
        dateFilter: _dateFilter,
        movementType: _movementType,
        direction: _direction,
        destination: _destinationController.text,
        forceRefresh: forceRefresh,
      );
      if (mounted) setState(() { _results = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Movement History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _load(forceRefresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          _filterBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
                : _results.isEmpty
                ? Center(
              child: Text('No movements match these filters',
                  style: TextStyle(color: Colors.grey.shade500)),
            )
                : RefreshIndicator(
              color: AppColors.teal,
              onRefresh: () => _load(forceRefresh: true),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                itemCount: _results.length,
                itemBuilder: (context, i) => _row(_results[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _destinationController,
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Filter by destination…',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.place_outlined, size: 18),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.search_rounded, color: AppColors.navy),
              onPressed: () => _load(),
            ),
          ]),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _chipGroup('Date', _dateFilters, _dateFilter, (v) { setState(() => _dateFilter = v); _load(); }),
              const SizedBox(width: 10),
              _chipGroup('Direction', _directions, _direction, (v) { setState(() => _direction = v); _load(); }),
              const SizedBox(width: 10),
              _chipGroup('Type', _types, _movementType, (v) { setState(() => _movementType = v); _load(); }),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _chipGroup(String label, List<String> options, String selected, ValueChanged<String> onSelect) {
    return Row(
      children: options.map((o) {
        final isSelected = o == selected;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            label: Text(o, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppColors.navy)),
            selected: isSelected,
            onSelected: (_) => onSelect(o),
            selectedColor: AppColors.navy,
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
            visualDensity: VisualDensity.compact,
          ),
        );
      }).toList(),
    );
  }

  static const _iconBtnConstraints = BoxConstraints(minWidth: 32, minHeight: 32);

  Widget _row(InventoryMovement m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _view(m),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.itemsSummary,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.navy)),
                          const SizedBox(height: 3),
                          Text('Qty ${m.totalQuantity} · ${m.movementType} · ${m.from} → ${m.to}',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                          const SizedBox(height: 2),
                          Text('Used by ${m.usedBy.isEmpty ? '—' : m.usedBy}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          if (m.createdAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(_fmtDate(m.createdAt!), style: TextStyle(fontSize: 10.5, color: Colors.grey.shade400)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _statusBadgeFor(m),
                  ],
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _timeStamp(Icons.north_east_rounded, 'Out', m.checkedOutAt, AppColors.coral)),
                  const SizedBox(width: 8),
                  Expanded(child: _timeStamp(Icons.south_west_rounded, 'In', m.checkedInAt, AppColors.green)),
                ]),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: () => _view(m),
                      tooltip: 'View',
                      icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.navy),
                      visualDensity: VisualDensity.compact,
                      constraints: _iconBtnConstraints,
                      padding: EdgeInsets.zero,
                    ),
                    IconButton(
                      onPressed: () => _edit(m),
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.navy),
                      visualDensity: VisualDensity.compact,
                      constraints: _iconBtnConstraints,
                      padding: EdgeInsets.zero,
                    ),
                    IconButton(
                      onPressed: () => _delete(m),
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.coral),
                      visualDensity: VisualDensity.compact,
                      constraints: _iconBtnConstraints,
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _view(InventoryMovement m) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'Movement Detail'),
        builder: (_) => MovementDetailScreen(movementId: m.id),
      ),
    );
    _load(forceRefresh: true);
  }

  Future<void> _edit(InventoryMovement m) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'Edit Movement'),
        builder: (_) => AddMovementScreen(editMovement: m),
      ),
    );
    _load(forceRefresh: true);
  }

  Future<void> _delete(InventoryMovement m) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Movement?'),
        content: Text('Delete this movement (${m.itemsSummary})? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await InventoryMovementService.deleteMovement(m.id);
      if (mounted) showAppSnack(context, 'Movement deleted');
      _load(forceRefresh: true);
    } catch (e) {
      final raw = e.toString();
      final msg = raw.startsWith('Exception: ') ? raw.substring(11) : raw;
      if (mounted) showAppSnack(context, msg, isError: true);
    }
  }

  String _fmtDate(DateTime d) => '${d.day}-${d.month}-${d.year}';
}

Widget _timeStamp(IconData icon, String label, DateTime? at, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [
      Icon(icon, size: 13, color: at != null ? color : Colors.grey.shade400),
      const SizedBox(width: 5),
      Expanded(
        child: Text(
          at == null ? '$label —' : '$label ${_fmtDateTime(at)}',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: at != null ? color : Colors.grey.shade400),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ]),
  );
}

String _fmtDateTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  final p = d.hour < 12 ? 'AM' : 'PM';
  return '${d.day}-${d.month}  $h:$m$p';
}

Widget _statusBadgeFor(InventoryMovement m) {
  Color c;
  String label;
  if (m.isCheckedIn) {
    c = AppColors.green;
    label = 'Checked In';
  } else if (m.isOpen) {
    c = AppColors.coral;
    label = 'Out';
  } else {
    c = Colors.grey;
    label = m.statusLabel;
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
    child: Text(label, style: TextStyle(color: c, fontSize: 10.5, fontWeight: FontWeight.w700)),
  );
}