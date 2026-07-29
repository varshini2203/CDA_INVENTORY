// lib/screens/inventory_movement/movement_history_screen.dart
//
// Filterable Movement History / Pending Approvals list. Filters: Today /
// This Week / This Month, Movement Type, Status, Destination — matches the
// filter set requested for the module and reuses
// InventoryMovementService.fetchHistory() for the actual filtering logic.

import 'package:flutter/material.dart';

import '../../models/inventory_movement.dart';
import '../../services/inventory_movement_service.dart';
import '../../shared/inventory_ui.dart';
import 'add_movement_screen.dart';
import 'movement_detail_screen.dart';

class MovementHistoryScreen extends StatefulWidget {
  final String initialStatus;
  final String initialDateFilter;
  final bool overdueOnly;

  const MovementHistoryScreen({
    super.key,
    this.initialStatus = 'All',
    this.initialDateFilter = 'All',
    this.overdueOnly = false,
  });

  @override
  State<MovementHistoryScreen> createState() => _MovementHistoryScreenState();
}

class _MovementHistoryScreenState extends State<MovementHistoryScreen> {
  late String _dateFilter = widget.initialDateFilter;
  late String _status = widget.initialStatus;
  String _movementType = 'All';
  final _destinationController = TextEditingController();

  static const _dateFilters = ['All', 'Today', 'This Week', 'This Month'];
  static const _statuses = ['All', ...MovementStatus.all];
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
      var list = await InventoryMovementService.fetchHistory(
        dateFilter: _dateFilter,
        movementType: _movementType,
        status: _status,
        destination: _destinationController.text,
        forceRefresh: forceRefresh,
      );
      if (widget.overdueOnly) {
        list = list.where((m) => m.isOverdue).toList();
      }
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
              _chipGroup('Status', _statuses, _status, (v) { setState(() => _status = v); _load(); }),
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
    final canEdit = m.isPending;
    final canDelete = !m.isDispatched && !m.isReturned;
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
                          Text(m.productName,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.navy)),
                          const SizedBox(height: 3),
                          Text('Qty ${m.quantity} · ${m.movementType} · ${m.from} → ${m.to}',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                          if (m.createdAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(_fmt(m.createdAt!), style: TextStyle(fontSize: 10.5, color: Colors.grey.shade400)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _statusBadgeFor(m),
                  ],
                ),
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
                    if (canEdit)
                      IconButton(
                        onPressed: () => _edit(m),
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.navy),
                        visualDensity: VisualDensity.compact,
                        constraints: _iconBtnConstraints,
                        padding: EdgeInsets.zero,
                      ),
                    if (canDelete)
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
        content: Text('Delete the request for "${m.productName}"? This cannot be undone.'),
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

  String _fmt(DateTime d) => '${d.day}-${d.month}-${d.year}';
}

Widget _statusBadgeFor(InventoryMovement m) {
  Color c;
  String label = m.status;
  if (m.isOverdue) {
    c = const Color(0xFFE8374A);
    label = 'Overdue';
  } else {
    switch (m.status) {
      case MovementStatus.pending:
        c = AppColors.amber;
        break;
      case MovementStatus.approved:
        c = const Color(0xFF1E5FC8);
        break;
      case MovementStatus.dispatched:
        c = AppColors.coral;
        break;
      case MovementStatus.returned:
        c = AppColors.green;
        break;
      default:
        c = Colors.grey;
    }
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
    child: Text(label, style: TextStyle(color: c, fontSize: 10.5, fontWeight: FontWeight.w700)),
  );
}