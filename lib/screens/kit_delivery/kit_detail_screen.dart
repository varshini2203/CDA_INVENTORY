// lib/screens/kit_delivery/kit_detail_screen.dart
//
// One kit: customer, every part with its delivered / pending count, the
// promised date, and the hand-over history. Main action: "Hand over
// pending parts" — records what was given now and, when nothing is left,
// completes the kit and stops the reminder.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../constants/drone_categories.dart';
import '../../models/kit_delivery.dart';
import '../../services/kit_delivery_service.dart';
import 'add_edit_kit_screen.dart';
import 'kit_dashboard_screen.dart';

class KitDetailScreen extends StatefulWidget {
  final String kitId;
  const KitDetailScreen({super.key, required this.kitId});

  @override
  State<KitDetailScreen> createState() => _KitDetailScreenState();
}

class _KitDetailScreenState extends State<KitDetailScreen> {
  final KitDeliveryService _service = KitDeliveryService();
  late final Stream<KitDelivery?> _stream = _service.kitStream(widget.kitId);

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _handOver(KitDelivery kit) async {
    final result = await showModalBottomSheet<_HandOverResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _HandOverSheet(kit: kit),
    );
    if (result == null) return;

    final r = await _service.deliverItems(
      kit.id,
      result.quantities,
      note: result.note,
      newPromisedDate: result.nextDate,
    );
    if (!mounted) return;
    if (r.success) {
      _snack(r.data!.isComplete
          ? 'Kit complete — reminder stopped.'
          : 'Saved. Still pending: ${r.data!.pendingSummary}');
    } else {
      _snack(r.error ?? 'Could not save.');
    }
  }

  Future<void> _changeDate(KitDelivery kit) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: kit.promisedDate != null && kit.promisedDate!.isAfter(now)
          ? kit.promisedDate!
          : now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: DateTime(2100),
      helpText: 'Remind me again on',
    );
    if (d == null) return;
    final r = await _service.setPromisedDate(kit, d);
    if (!mounted) return;
    _snack(r.success ? 'Reminder moved to ${DateFormat('dd MMM').format(d)}.'
        : (r.error ?? 'Could not save.'));
  }

  Future<void> _delete(KitDelivery kit) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this kit?'),
        content: Text(
            'This removes the record for ${kit.customerName} and its '
                'reminder. This cannot be undone.'),
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
    final r = await _service.deleteKit(kit);
    if (!mounted) return;
    if (r.success) {
      Navigator.pop(context);
    } else {
      _snack(r.error ?? 'Could not delete.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<KitDelivery?>(
      stream: _stream,
      builder: (context, snap) {
        final kit = snap.data;

        return Scaffold(
          backgroundColor: kKitBg,
          appBar: AppBar(
            backgroundColor: kKitNavy,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text(
              'Kit Details',
              style:
              TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
            actions: [
              if (kit != null)
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          settings: const RouteSettings(name: 'Edit Kit'),
                          builder: (_) => AddEditKitScreen(kit: kit),
                        ),
                      );
                    } else if (v == 'delete') {
                      _delete(kit);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
            ],
          ),
          body: () {
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }
            if (snap.connectionState == ConnectionState.waiting &&
                kit == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (kit == null) {
              return const Center(child: Text('This kit no longer exists.'));
            }
            return _Body(
              kit: kit,
              onHandOver: () => _handOver(kit),
              onChangeDate: () => _changeDate(kit),
            );
          }(),
          bottomNavigationBar: (kit != null && kit.isPending)
              ? SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _handOver(kit),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kKitBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('Hand over pending parts'),
                ),
              ),
            ),
          )
              : null,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  final KitDelivery kit;
  final VoidCallback onHandOver;
  final VoidCallback onChangeDate;

  const _Body({
    required this.kit,
    required this.onHandOver,
    required this.onChangeDate,
  });

  Widget _row(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: kKitMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(color: kKitNavy, fontSize: 13)),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd MMM yyyy');
    final dateTime = DateFormat('dd MMM yyyy, hh:mm a');
    final dueColor = kitDueColor(kit);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // ── Customer + status ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kKitBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          kit.customerName,
                          style: const TextStyle(
                            color: kKitNavy,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: dueColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          kitDueText(kit),
                          style: TextStyle(
                            color: dueColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (kit.customerPhone.isNotEmpty)
                    _row(Icons.phone, kit.customerPhone),
                  if (kit.customerAddress.isNotEmpty)
                    _row(Icons.location_on_outlined, kit.customerAddress),
                  _row(Icons.business,
                      kBranchLabels[kit.branch] ?? kit.branch),
                  if (kit.invoiceRef.isNotEmpty)
                    _row(Icons.receipt_long, 'Invoice ${kit.invoiceRef}'),
                  _row(Icons.event, 'Delivered ${date.format(kit.deliveredAt)}'),
                  if (kit.completedAt != null)
                    _row(Icons.check_circle_outline,
                        'Completed ${date.format(kit.completedAt!)}'),
                  if (kit.notes.isNotEmpty) _row(Icons.notes, kit.notes),
                ],
              ),
            ),

            // ── Reminder card (only while pending) ──────────────────────
            if (kit.isPending) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: dueColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: dueColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.notifications_active, color: dueColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            kit.promisedDate == null
                                ? 'No promised date set — no reminder'
                                : 'Promised by ${date.format(kit.promisedDate!)}',
                            style: TextStyle(
                                color: dueColor, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Pending: ${kit.pendingSummary}',
                            style: const TextStyle(
                                color: kKitNavy, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: onChangeDate,
                      child: const Text('Change date'),
                    ),
                  ],
                ),
              ),
            ],

            // ── Parts ───────────────────────────────────────────────────
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Parts',
                    style: TextStyle(
                      color: kKitNavy,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                _Pill('Delivered ${kit.totalDelivered}', kKitGreen),
                const SizedBox(width: 6),
                _Pill('Pending ${kit.totalPending}',
                    kit.totalPending > 0 ? kKitRed : kKitMuted),
              ],
            ),
            const SizedBox(height: 8),
            for (final i in kit.items)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: i.isPending
                      ? kKitRed.withValues(alpha: 0.04)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: i.isPending
                        ? kKitRed.withValues(alpha: 0.4)
                        : kKitBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      i.isPending
                          ? Icons.pending_actions
                          : Icons.check_circle,
                      color: i.isPending ? kKitRed : kKitGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(i.name,
                              style: const TextStyle(
                                  color: kKitNavy,
                                  fontWeight: FontWeight.w700)),
                          Text('${i.category}  ·  Total ${i.requiredQty}',
                              style: const TextStyle(
                                  color: kKitMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                    _QtyBox(
                        label: 'Delivered',
                        value: i.deliveredQty,
                        color: kKitGreen),
                    const SizedBox(width: 8),
                    _QtyBox(
                        label: 'Pending',
                        value: i.pendingQty,
                        color: i.isPending ? kKitRed : kKitMuted),
                  ],
                ),
              ),

            // ── History ─────────────────────────────────────────────────
            if (kit.handovers.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'Hand-over history',
                style: TextStyle(
                  color: kKitNavy,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              for (final h in kit.handovers.reversed)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kKitBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        h.quantities.entries
                            .map((e) => '${e.key} ×${e.value}')
                            .join(', '),
                        style: const TextStyle(
                            color: kKitNavy, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${dateTime.format(h.at)}${h.by.isEmpty ? '' : '  ·  ${h.by}'}'
                            '${h.note.isEmpty ? '' : '\n${h.note}'}',
                        style:
                        const TextStyle(color: kKitMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
          color: color, fontWeight: FontWeight.w800, fontSize: 11),
    ),
  );
}

class _QtyBox extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _QtyBox(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: 64,
    padding: const EdgeInsets.symmetric(vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 10)),
        Text('$value',
            style: TextStyle(
                color: color, fontWeight: FontWeight.w800, fontSize: 17)),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// HAND-OVER BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _HandOverResult {
  final Map<String, int> quantities;
  final String note;

  /// New promised date for whatever is STILL pending after this hand-over
  /// (null when the kit becomes complete).
  final DateTime? nextDate;
  const _HandOverResult(this.quantities, this.note, this.nextDate);
}

class _HandOverSheet extends StatefulWidget {
  final KitDelivery kit;
  const _HandOverSheet({required this.kit});

  @override
  State<_HandOverSheet> createState() => _HandOverSheetState();
}

class _HandOverSheetState extends State<_HandOverSheet> {
  // Typed by hand for each pending part (empty = 0). Starts empty so the
  // user enters exactly what is being given now.
  late final Map<String, TextEditingController> _ctl = {
    for (final i in widget.kit.pendingItems) i.name: TextEditingController(),
  };

  /// Quantity typed for each part, clamped to what is still pending.
  Map<String, int> get _qty => {
    for (final i in widget.kit.pendingItems)
      i.name: (() {
        final v = int.tryParse(_ctl[i.name]!.text.trim()) ?? 0;
        return v > i.pendingQty ? i.pendingQty : v;
      })(),
  };
  final _note = TextEditingController();

  /// Date the leftover parts are promised for. Starts at the existing
  /// promised date if it is still today/in the future, otherwise a fresh
  /// default (a few days from now).
  late DateTime _next;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final p = widget.kit.promisedDate;
    _next = (p != null && !DateTime(p.year, p.month, p.day).isBefore(today))
        ? DateTime(p.year, p.month, p.day)
        : KitDeliveryService.defaultPromisedDate();
  }

  @override
  void dispose() {
    _note.dispose();
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  int get _total => _qty.values.fold(0, (a, b) => a + b);

  /// Parts that will STILL be pending after this hand-over.
  int get _stillPending {
    final q = _qty;
    return widget.kit.pendingItems
        .fold<int>(0, (a, i) => a + i.pendingQty - (q[i.name] ?? 0));
  }

  Future<void> _pickNext() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _next,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(2100),
      helpText: 'Remaining parts promised by',
    );
    if (d != null) setState(() => _next = d);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hand over to ${widget.kit.customerName}',
              style: const TextStyle(
                color: kKitNavy,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Type how many of each pending part you are giving now.',
              style: TextStyle(color: kKitMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            for (final i in widget.kit.pendingItems)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(i.name,
                              style: const TextStyle(
                                  color: kKitNavy,
                                  fontWeight: FontWeight.w700)),
                          Text('${i.pendingQty} pending',
                              style: const TextStyle(
                                  color: kKitRed, fontSize: 11)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(
                              () => _ctl[i.name]!.text = '${i.pendingQty}'),
                      child: const Text('All'),
                    ),
                    SizedBox(
                      width: 72,
                      child: TextField(
                        controller: _ctl[i.name],
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        textAlign: TextAlign.center,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: '0',
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_stillPending > 0) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: _pickNext,
                child: InputDecorator(
                  decoration: InputDecoration(
                    isDense: true,
                    labelText:
                    'Remaining $_stillPending part(s) now promised by',
                    prefixIcon: const Icon(Icons.event, size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(DateFormat('dd MMM yyyy').format(_next)),
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              decoration: InputDecoration(
                isDense: true,
                labelText: 'Note (optional)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _total == 0
                    ? null
                    : () => Navigator.pop(
                  context,
                  _HandOverResult(
                    Map<String, int>.from(_qty)
                      ..removeWhere((_, v) => v <= 0),
                    _note.text,
                    _stillPending > 0 ? _next : null,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kKitBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Confirm hand-over ($_total)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}