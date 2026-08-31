// lib/screens/inventory/inventory_history_screen.dart
//
// "History" view for the Inventory (Products) module — shows every item
// that's been added, grouped by date, each row carrying the exact time and
// the name of whoever added it. Backed by the same `activity_logs`
// collection that already powers the admin Activity Feed
// (see ActivityLogService.logAdd(module: 'Products', ...) in
// product_service.dart / new_product_service.dart), just filtered down to
// this module and the 'added' action.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_access_models.dart';
import '../../services/activity_log_service.dart';

class InventoryHistoryScreen extends StatelessWidget {
  const InventoryHistoryScreen({super.key});

  static const Color kNavy = Color(0xFF0A1628);
  static const Color kTeal = Color(0xFF00D4AA);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Inventory History',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: StreamBuilder<List<ActivityLogModel>>(
        stream: ActivityLogService.streamForModule('Products', limit: 500),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: kTeal));
          }
          if (snap.hasError) {
            return Center(
              child: Text('Could not load history.\n${snap.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600)),
            );
          }
          final logs = (snap.data ?? [])
              .where((l) => l.action == 'added')
              .toList();

          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('No items added yet',
                      style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }

          // Group by calendar day (newest first); logs already arrive
          // newest-first from the service.
          final Map<String, List<ActivityLogModel>> grouped = {};
          final dayKeyFmt = DateFormat('yyyy-MM-dd');
          for (final log in logs) {
            final ts = log.timestamp;
            final key = ts != null ? dayKeyFmt.format(ts) : 'unknown';
            grouped.putIfAbsent(key, () => []).add(log);
          }
          final dayKeys = grouped.keys.toList()
            ..sort((a, b) => b.compareTo(a)); // newest date first

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: dayKeys.length,
            itemBuilder: (context, i) {
              final key = dayKeys[i];
              final dayLogs = grouped[key]!;
              final headerLabel = key == 'unknown'
                  ? 'Unknown date'
                  : _dayHeaderLabel(dayLogs.first.timestamp!);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Text(
                      headerLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                  for (final log in dayLogs) _historyRow(log),
                  const SizedBox(height: 6),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _dayHeaderLabel(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday =
        dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day;
    if (isToday) return 'TODAY · ${DateFormat('d MMM yyyy').format(dt).toUpperCase()}';
    if (isYesterday) return 'YESTERDAY · ${DateFormat('d MMM yyyy').format(dt).toUpperCase()}';
    return DateFormat('EEEE · d MMM yyyy').format(dt).toUpperCase();
  }

  Widget _historyRow(ActivityLogModel log) {
    final time = log.timestamp != null ? DateFormat('h:mm a').format(log.timestamp!) : '--:--';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kTeal.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.add_box_rounded, color: kTeal, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.itemName?.isNotEmpty == true ? log.itemName! : log.label,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: kNavy, fontSize: 14.5),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person_rounded, size: 13, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        log.userName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.access_time_rounded, size: 13, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(time, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}