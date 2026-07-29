// lib/screens/inventory_movement/movement_detail_screen.dart
//
// Full detail view of a single movement plus the approval-workflow action
// buttons: Approve / Reject (admin-gated, via CurrentAccess.isAdmin — same
// gate used by AdminGuard elsewhere) and Dispatch / Return (any editor,
// via EditGuard/requireEditAccess — the same guard already used across
// every other write action in the app).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/access/access_scope.dart';
import '../../models/inventory_movement.dart';
import '../../services/inventory_movement_service.dart';
import '../../services/movement_reminder_service.dart';
import '../../shared/inventory_ui.dart';

class MovementDetailScreen extends StatefulWidget {
  final String movementId;
  const MovementDetailScreen({super.key, required this.movementId});

  @override
  State<MovementDetailScreen> createState() => _MovementDetailScreenState();
}

class _MovementDetailScreenState extends State<MovementDetailScreen> {
  InventoryMovement? _movement;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final m = await InventoryMovementService.fetchById(widget.movementId);
    if (mounted) setState(() { _movement = m; _loading = false; });
  }

  Future<void> _act(Future<void> Function() action, {required String successMsg}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      showAppSnack(context, successMsg);
      await _load();
    } catch (e) {
      final raw = e.toString();
      final msg = raw.startsWith('Exception: ') ? raw.substring(11) : raw;
      if (mounted) showAppSnack(context, msg, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve() async {
    final access = context.read<CurrentAccess>().access;
    await _act(
          () => InventoryMovementService.approveMovement(
        id: widget.movementId,
        approvedBy: access?.name.isNotEmpty == true ? access!.name : (access?.email ?? 'Admin'),
      ),
      successMsg: 'Movement approved',
    );
  }

  Future<void> _reject() async {
    final reason = await _promptText('Reject Movement', 'Reason for rejection (optional)');
    if (reason == null) return; // cancelled
    final access = context.read<CurrentAccess>().access;
    await _act(
          () => InventoryMovementService.rejectMovement(
        id: widget.movementId,
        rejectedBy: access?.name.isNotEmpty == true ? access!.name : (access?.email ?? 'Admin'),
        reason: reason,
      ),
      successMsg: 'Movement rejected',
    );
  }

  Future<void> _dispatch() async {
    if (!requireEditAccess(context)) return;
    final access = context.read<CurrentAccess>().access;
    final dispatchedBy = access?.name.isNotEmpty == true ? access!.name : (access?.email ?? 'Unknown');
    await _act(
          () async {
        await InventoryMovementService.dispatchMovement(id: widget.movementId, dispatchedBy: dispatchedBy);
        final m = _movement;
        if (m?.expectedReturnAt != null) {
          MovementReminderService.instance.scheduleReminder(
            movementId: widget.movementId,
            productName: m!.productName,
            quantity: m.quantity,
            expectedReturnAt: m.expectedReturnAt!,
          );
        }
      },
      successMsg: 'Marked as Dispatched — stock updated',
    );
  }

  Future<void> _return() async {
    if (!requireEditAccess(context)) return;
    final access = context.read<CurrentAccess>().access;
    final returnedBy = access?.name.isNotEmpty == true ? access!.name : (access?.email ?? 'Unknown');
    await _act(
          () async {
        await InventoryMovementService.returnMovement(id: widget.movementId, returnedBy: returnedBy);
        MovementReminderService.instance.cancelReminder(widget.movementId);
      },
      successMsg: 'Marked as Returned — stock restored',
    );
  }

  Future<String?> _promptText(String title, String hint) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 2,
          decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral, foregroundColor: Colors.white),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Movement Detail', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : _movement == null
          ? const Center(child: Text('Movement not found'))
          : _body(context, _movement!),
    );
  }

  Widget _body(BuildContext context, InventoryMovement m) {
    final isAdmin = context.watch<CurrentAccess>().isAdmin;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.navy, Color(0xFF13294B)]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(m.productName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                  ),
                  _statusPill(m),
                ]),
                const SizedBox(height: 6),
                Text('Qty ${m.quantity} · ${m.movementType}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                if (m.isOverdue) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.18), borderRadius: BorderRadius.circular(8)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
                      SizedBox(width: 6),
                      Text('Overdue for return', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700, fontSize: 12)),
                    ]),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionLabel('MOVEMENT DETAILS'),
          const SizedBox(height: 10),
          FormCard(children: [
            _kv('From', m.from),
            _kv('To', m.to),
            _kv('Purpose', m.purpose.isEmpty ? '—' : m.purpose),
            _kv('Taken By', m.takenBy),
            _kv('Used By', m.usedBy.isEmpty ? '—' : m.usedBy),
            _kv('Returned By', m.returnedBy.isEmpty ? '—' : m.returnedBy),
            _kv('Remarks', m.remarks.isEmpty ? '—' : m.remarks, isLast: true),
          ]),
          const SizedBox(height: 20),
          const SectionLabel('TIMELINE'),
          const SizedBox(height: 10),
          FormCard(children: [
            _kv('Created', _fmt(m.createdAt), sub: m.createdBy),
            _kv('Expected Return', _fmt(m.expectedReturnAt)),
            _kv('Approved', _fmt(m.approvedAt), sub: m.approvedBy),
            _kv('Dispatched', _fmt(m.dispatchedAt), sub: m.dispatchedBy),
            _kv('Returned', _fmt(m.returnedAt), sub: m.returnedBy, isLast: true),
            if (m.isRejected && (m.rejectionReason ?? '').isNotEmpty) ...[
              const Divider(height: 20),
              _kv('Rejection Reason', m.rejectionReason!, isLast: true),
            ],
          ]),
          const SizedBox(height: 28),
          _actionButtons(m, isAdmin),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _actionButtons(InventoryMovement m, bool isAdmin) {
    if (m.isPending) {
      if (!isAdmin) {
        return _infoNote('Waiting for admin approval.');
      }
      return Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _reject,
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Reject'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.coral,
              side: const BorderSide(color: AppColors.coral),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _busy ? null : _approve,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Approve'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ]);
    }
    if (m.isApproved) {
      return EditGuard(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _busy ? null : _dispatch,
            icon: const Icon(Icons.north_east_rounded, size: 18),
            label: const Text('Mark as Dispatched'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.coral,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      );
    }
    if (m.isDispatched) {
      return EditGuard(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _busy ? null : _return,
            icon: const Icon(Icons.south_west_rounded, size: 18),
            label: const Text('Mark as Returned'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      );
    }
    if (m.isReturned) return _infoNote('This movement is complete.');
    if (m.isRejected) return _infoNote('This movement request was rejected.');
    return const SizedBox.shrink();
  }

  Widget _infoNote(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      Icon(Icons.info_outline_rounded, size: 18, color: Colors.grey.shade500),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
    ]),
  );

  Widget _kv(String label, String value, {String? sub, bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 13.5, color: AppColors.navy, fontWeight: FontWeight.w600)),
                if (sub != null && sub.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('by $sub', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime? d) {
    if (d == null) return '—';
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final min = d.minute.toString().padLeft(2, '0');
    final p = d.hour < 12 ? 'AM' : 'PM';
    return '${d.day}-${d.month}-${d.year}  •  $h:$min $p';
  }

  Widget _statusPill(InventoryMovement m) {
    Color c;
    String label = m.status;
    if (m.isOverdue) {
      c = Colors.redAccent;
      label = 'Overdue';
    } else {
      switch (m.status) {
        case MovementStatus.pending:
          c = AppColors.amber;
          break;
        case MovementStatus.approved:
          c = AppColors.teal;
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: c.withOpacity(0.22), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 11.5)),
    );
  }
}