// lib/screens/inventory_movement/request_item_screen.dart
//
// "Request Item" — every movement between Adambakkam and Gojan (in either
// direction) shows up here, like a notification inbox for item movements.
// The alert card at the top (always English) tells staff exactly which items
// still need to be put into the Inventory app for each direction.
//
// Data comes from the existing `inventory_movements` collection through
// InventoryMovementService — nothing new is written to Firestore.

import 'package:flutter/material.dart';

import '../../models/inventory_movement.dart';
import '../../services/inventory_movement_service.dart';
import '../../shared/inventory_ui.dart';
import 'add_request_screen.dart';
import 'movement_detail_screen.dart';

/// Which way a movement is going between the two sites.
enum RequestDirection { adambakkamToGojan, gojanToAdambakkam }

/// Returns the direction if this movement is Adambakkam <-> Gojan, else null.
/// Matches on the free-text `from` / `to` fields (case-insensitive).
RequestDirection? requestDirectionOf(InventoryMovement m) {
  final from = m.from.toLowerCase();
  final to = m.to.toLowerCase();
  if (from.contains('adambakkam') && to.contains('gojan')) {
    return RequestDirection.adambakkamToGojan;
  }
  if (from.contains('gojan') && to.contains('adambakkam')) {
    return RequestDirection.gojanToAdambakkam;
  }
  return null;
}

/// Only the Adambakkam <-> Gojan movements, newest first (input order kept).
List<InventoryMovement> requestItemMovements(List<InventoryMovement> all) =>
    all.where((m) => requestDirectionOf(m) != null).toList();

/// Movements that still need attention — checked out but not checked in yet.
/// This drives the badge count on the dashboard button.
List<InventoryMovement> pendingRequestMovements(List<InventoryMovement> all) =>
    requestItemMovements(all).where((m) => m.isOpen).toList();

String _directionLabel(RequestDirection d) => d == RequestDirection.adambakkamToGojan
    ? 'Adambakkam → Gojan'
    : 'Gojan → Adambakkam';

class RequestItemScreen extends StatelessWidget {
  const RequestItemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text('Request Item',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          bottom: const TabBar(
            indicatorColor: AppColors.teal,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Adambakkam → Gojan'),
              Tab(text: 'Gojan → Adambakkam'),
            ],
          ),
        ),
        floatingActionButton: Builder(
          builder: (ctx) => FloatingActionButton.extended(
            backgroundColor: AppColors.teal,
            foregroundColor: AppColors.navy,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Request', style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: () {
              // Pre-select the direction of the tab the user is on.
              final tab = DefaultTabController.of(ctx).index;
              Navigator.push(
                ctx,
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'Add Request'),
                  builder: (_) => AddRequestScreen(
                    initialDirection: tab == 1
                        ? RequestDirection.adambakkamToGojan
                        : tab == 2
                        ? RequestDirection.gojanToAdambakkam
                        : null,
                  ),
                ),
              );
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
            final all = requestItemMovements(snapshot.data ?? const <InventoryMovement>[]);
            final a2g = all
                .where((m) => requestDirectionOf(m) == RequestDirection.adambakkamToGojan)
                .toList();
            final g2a = all
                .where((m) => requestDirectionOf(m) == RequestDirection.gojanToAdambakkam)
                .toList();

            return TabBarView(
              children: [
                _MovementList(movements: all, showAlert: true),
                _MovementList(
                    movements: a2g, showAlert: true, only: RequestDirection.adambakkamToGojan),
                _MovementList(
                    movements: g2a, showAlert: true, only: RequestDirection.gojanToAdambakkam),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MovementList extends StatelessWidget {
  final List<InventoryMovement> movements;
  final bool showAlert;
  final RequestDirection? only; // null = both directions
  const _MovementList({required this.movements, required this.showAlert, this.only});

  @override
  Widget build(BuildContext context) {
    final pending = movements.where((m) => m.isOpen).toList();
    return RefreshIndicator(
      color: AppColors.teal,
      onRefresh: () => InventoryMovementService.fetchAll(forceRefresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (showAlert) _InventoryAlert(pending: pending, only: only),
          if (showAlert) const SizedBox(height: 16),
          const SectionLabel('MOVEMENTS'),
          const SizedBox(height: 10),
          if (movements.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Column(children: [
                Icon(Icons.swap_horiz_rounded, size: 44, color: Colors.black26),
                SizedBox(height: 10),
                Text('No movements between Adambakkam and Gojan yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black45, fontSize: 13)),
              ]),
            )
          else
            for (final m in movements) _RequestRow(movement: m),
        ],
      ),
    );
  }
}

/// The alert under "Request Item": tells the user, in English, which items
/// must be put into the Inventory app for each direction.
class _InventoryAlert extends StatelessWidget {
  final List<InventoryMovement> pending;
  final RequestDirection? only;
  const _InventoryAlert({required this.pending, required this.only});

  /// Sums quantities per product name across the given movements.
  Map<String, int> _totals(Iterable<InventoryMovement> list) {
    final totals = <String, int>{};
    for (final m in list) {
      for (final i in m.items) {
        final name = i.productName.trim().isEmpty ? 'Unnamed item' : i.productName.trim();
        totals.update(name, (v) => v + i.quantity, ifAbsent: () => i.quantity);
      }
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    final directions = only == null ? RequestDirection.values : [only!];
    final sections = <Widget>[];

    for (final d in directions) {
      final totals = _totals(pending.where((m) => requestDirectionOf(m) == d));
      if (totals.isEmpty) continue;
      sections.add(Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_directionLabel(d),
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.navy)),
          const SizedBox(height: 2),
          const Text('Please add these items to the Inventory app:',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 6),
          for (final e in totals.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('•  ', style: TextStyle(color: Colors.black54)),
                Expanded(
                  child: Text('${e.key}  ×  ${e.value}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
        ]),
      ));
    }

    final hasItems = sections.isNotEmpty;
    final color = hasItems ? AppColors.amber : AppColors.green;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(hasItems ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
              color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasItems ? 'Inventory update needed' : 'All caught up',
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.navy),
            ),
          ),
        ]),
        if (hasItems) ...sections else
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('No items are waiting to be added to the Inventory app.',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
          ),
      ]),
    );
  }
}

class _RequestRow extends StatelessWidget {
  final InventoryMovement movement;
  const _RequestRow({required this.movement});

  String _fmt(DateTime? d) {
    if (d == null) return '';
    const mon = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${mon[d.month - 1]} · $h:$mm ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    final dir = requestDirectionOf(movement);
    final open = movement.isOpen;
    final statusColor = movement.isCheckedIn
        ? AppColors.green
        : (open ? AppColors.coral : Colors.grey);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: 'Movement Detail'),
          builder: (_) => MovementDetailScreen(movementId: movement.id),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              dir == RequestDirection.adambakkamToGojan
                  ? Icons.east_rounded
                  : Icons.west_rounded,
              color: statusColor, size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(movement.itemsSummary,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              const SizedBox(height: 2),
              Text(
                '${dir == null ? '' : _directionLabel(dir)} · Qty ${movement.totalQuantity}',
                style: const TextStyle(fontSize: 11.5, color: Colors.black54),
              ),
              Text(
                [
                  if ((movement.checkedOutBy ?? movement.usedBy).trim().isNotEmpty)
                    'Sent by ${(movement.checkedOutBy ?? movement.usedBy).trim()}',
                  if (movement.checkedOutAt != null || movement.createdAt != null)
                    _fmt(movement.checkedOutAt ?? movement.createdAt),
                ].join(' · '),
                style: const TextStyle(fontSize: 10.5, color: Colors.black45),
              ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(movement.statusLabel,
                style: TextStyle(
                    color: statusColor, fontSize: 10.5, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}