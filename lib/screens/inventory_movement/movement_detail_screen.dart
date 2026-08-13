// lib/screens/inventory_movement/movement_detail_screen.dart
//
// Full detail view of a single movement, with a single common CHECK IN /
// CHECK OUT toggle button — usable by admin AND employee alike (no
// role-gating, unlike the old Approve/Reject/Dispatch/Return flow).
//
// Tap 1 -> "Check In"  : current date + time auto-captured, who did it
//                        auto-captured from the logged-in user.
// Tap 2 -> "Check Out" : current date + time auto-captured, who did it
//                        auto-captured from the logged-in user.
//
// Timeline section shows Check In (date/time) and Check Out (date/time)
// automatically, same pattern as the Drone In/Out module.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/access/access_scope.dart';
import '../../models/inventory_movement.dart';
import '../../services/inventory_movement_service.dart';
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

  String _currentUserName() {
    final access = context.read<CurrentAccess>().access;
    return access?.name.isNotEmpty == true ? access!.name : (access?.email ?? 'User');
  }

  // Single toggle handler — decides Check In vs Check Out from current state.
  // Common to admin + employee, no access-level gating.
  Future<void> _toggle() async {
    final m = _movement;
    if (m == null) return;
    final who = _currentUserName();

    if (!m.isCheckedIn) {
      await _act(
            () => InventoryMovementService.checkIn(id: widget.movementId, checkedInBy: who),
        successMsg: 'Checked In',
      );
    } else {
      await _act(
            () => InventoryMovementService.checkOut(id: widget.movementId, checkedOutBy: who),
        successMsg: 'Checked Out',
      );
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
            _kv('Remarks', m.remarks.isEmpty ? '—' : m.remarks, isLast: true),
          ]),
          const SizedBox(height: 20),
          const SectionLabel('TIMELINE'),
          const SizedBox(height: 10),
          FormCard(children: [
            _kv('Created', _fmt(m.createdAt), sub: m.createdBy),
            _kv('Check In', _fmt(m.checkedInAt), sub: m.checkedInBy),
            _kv('Check Out', _fmt(m.checkedOutAt), sub: m.checkedOutBy, isLast: true),
          ]),
          const SizedBox(height: 28),
          _actionButton(m),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Single common toggle — same button for admin and employee.
  Widget _actionButton(InventoryMovement m) {
    if (m.isCheckedOut) {
      return _infoNote('Checked out on ${_fmt(m.checkedOutAt)} by ${m.checkedOutBy ?? '—'}.');
    }

    final isIn = m.isCheckedIn;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _busy ? null : _toggle,
        icon: Icon(isIn ? Icons.logout_rounded : Icons.login_rounded, size: 18),
        label: Text(isIn ? 'Check Out' : 'Check In'),
        style: ElevatedButton.styleFrom(
          backgroundColor: isIn ? AppColors.coral : AppColors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
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
    String label;
    if (m.isCheckedOut) {
      c = AppColors.green;
      label = 'Checked Out';
    } else if (m.isCheckedIn) {
      c = AppColors.coral;
      label = 'Checked In';
    } else {
      c = AppColors.amber;
      label = 'Not Checked In';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: c.withOpacity(0.22), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 11.5)),
    );
  }
}