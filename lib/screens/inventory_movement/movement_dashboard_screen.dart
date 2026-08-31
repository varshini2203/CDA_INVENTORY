// lib/screens/inventory_movement/movement_dashboard_screen.dart
//
// Home screen for the Enterprise Inventory Movement module — v2. Cards and
// list rows now reflect the simple Check Out / Check In model: no more
// Pending / Approved / Overdue states.

import 'package:flutter/material.dart';

import '../../core/access/access_scope.dart';
import '../../models/inventory_movement.dart';
import '../../services/inventory_movement_service.dart';
import '../../shared/inventory_ui.dart';
import 'add_movement_screen.dart';
import 'movement_history_screen.dart';
import 'movement_detail_screen.dart';

class MovementDashboardScreen extends StatefulWidget {
  const MovementDashboardScreen({super.key});

  @override
  State<MovementDashboardScreen> createState() => _MovementDashboardScreenState();
}

class _MovementDashboardScreenState extends State<MovementDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Inventory Movement',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Movement History',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: 'Movement History'),
                builder: (_) => const MovementHistoryScreen(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: EditGuard(
        child: FloatingActionButton.extended(
          backgroundColor: AppColors.teal,
          foregroundColor: AppColors.navy,
          icon: const Icon(Icons.add_rounded),
          label: const Text('New Movement', style: TextStyle(fontWeight: FontWeight.w700)),
          onPressed: () async {
            final created = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: 'New Movement'),
                builder: (_) => const AddMovementScreen(),
              ),
            );
            if (created == true) setState(() {});
          },
        ),
      ),
      body: StreamBuilder<List<InventoryMovement>>(
        stream: InventoryMovementService.streamAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.teal));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load: ${snapshot.error}',
                  style: TextStyle(color: Colors.grey.shade600)),
            );
          }
          final all = snapshot.data ?? const <InventoryMovement>[];
          final total = all.length;
          final open = all.where((m) => m.isOpen).length;
          final inToday = all.where((m) => m.isCheckedInToday).length;
          final outToday = all.where((m) => m.isCheckedOutToday).length;
          final recent = all.take(8).toList();

          return RefreshIndicator(
            color: AppColors.teal,
            onRefresh: () async {
              await InventoryMovementService.fetchAll(forceRefresh: true);
              setState(() {});
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const HeroBanner(
                  icon: Icons.compare_arrows_rounded,
                  title: 'Inventory Movement',
                  subtitle: 'Track items in & out across branches, workshops & repairs',
                ),
                const SizedBox(height: 20),
                const SectionLabel('OVERVIEW'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _DashboardCard(
                      icon: Icons.compare_arrows_rounded,
                      label: 'Total',
                      value: '$total',
                      color: AppColors.navy,
                      onTap: () => _openHistory(direction: 'All'),
                    ),
                    const SizedBox(width: 8),
                    _DashboardCard(
                      icon: Icons.north_east_rounded,
                      label: 'Still Out',
                      value: '$open',
                      color: AppColors.coral,
                      onTap: () => _openHistory(direction: 'Open'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _DashboardCard(
                      icon: Icons.south_west_rounded,
                      label: 'Checked In Today',
                      value: '$inToday',
                      color: AppColors.green,
                      onTap: () => _openHistory(direction: 'Checked In', dateFilter: 'Today'),
                    ),
                    const SizedBox(width: 8),
                    _DashboardCard(
                      icon: Icons.north_east_rounded,
                      label: 'Checked Out Today',
                      value: '$outToday',
                      color: AppColors.amber,
                      onTap: () => _openHistory(direction: 'Checked Out', dateFilter: 'Today'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const SectionLabel('RECENT MOVEMENTS'),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _openHistory(direction: 'All'),
                      child: const Text('View All',
                          style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (recent.isEmpty)
                  _EmptyState(onCreate: () async {
                    final created = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => const AddMovementScreen()),
                    );
                    if (created == true) setState(() {});
                  })
                else
                  ...recent.map((m) => _MovementTile(
                    movement: m,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        settings: const RouteSettings(name: 'Movement Detail'),
                        builder: (_) => MovementDetailScreen(movementId: m.id),
                      ),
                    ),
                  )),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openHistory({
    String direction = 'All',
    String dateFilter = 'All',
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'Movement History'),
        builder: (_) => MovementHistoryScreen(
          initialDirection: direction,
          initialDateFilter: dateFilter,
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.12), blurRadius: 6, offset: const Offset(0, 2)),
              ],
              border: Border(left: BorderSide(color: color, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  final InventoryMovement movement;
  final VoidCallback onTap;
  const _MovementTile({required this.movement, required this.onTap});

  Future<void> _edit(BuildContext context) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'Edit Movement'),
        builder: (_) => AddMovementScreen(editMovement: movement),
      ),
    );
    // Dashboard is stream-driven, so no manual refresh needed here.
  }

  Future<void> _delete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Movement?'),
        content: Text('Delete this movement (${movement.itemsSummary})? This cannot be undone.'),
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
      await InventoryMovementService.deleteMovement(movement.id);
      if (context.mounted) showAppSnack(context, 'Movement deleted');
    } catch (e) {
      final raw = e.toString();
      final msg = raw.startsWith('Exception: ') ? raw.substring(11) : raw;
      if (context.mounted) showAppSnack(context, msg, isError: true);
    }
  }

  static const _iconBtnConstraints = BoxConstraints(minWidth: 32, minHeight: 32);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        movement.isOpen ? Icons.north_east_rounded : Icons.south_west_rounded,
                        color: AppColors.navy,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(movement.itemsSummary,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.navy),
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text('Qty ${movement.totalQuantity} · ${movement.movementType} · ${movement.from} → ${movement.to}',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text('Used by ${movement.usedBy.isEmpty ? '—' : movement.usedBy}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _statusBadge(movement),
                  ],
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _timeStamp(Icons.north_east_rounded, 'Out', movement.checkedOutAt, movement.checkedOutBy, AppColors.coral)),
                  const SizedBox(width: 8),
                  Expanded(child: _timeStamp(Icons.south_west_rounded, 'In', movement.checkedInAt, movement.checkedInBy, AppColors.green)),
                ]),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: onTap,
                      tooltip: 'View',
                      icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.navy),
                      visualDensity: VisualDensity.compact,
                      constraints: _iconBtnConstraints,
                      padding: EdgeInsets.zero,
                    ),
                    IconButton(
                      onPressed: () => _edit(context),
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.navy),
                      visualDensity: VisualDensity.compact,
                      constraints: _iconBtnConstraints,
                      padding: EdgeInsets.zero,
                    ),
                    IconButton(
                      onPressed: () => _delete(context),
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
}

Widget _timeStamp(IconData icon, String label, DateTime? at, String? by, Color color) {
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

Widget _statusBadge(InventoryMovement m) {
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

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Icon(Icons.compare_arrows_rounded, size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No movements yet', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Create the first inventory movement to get started.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          const SizedBox(height: 16),
          EditGuard(
            child: ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New Movement'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}