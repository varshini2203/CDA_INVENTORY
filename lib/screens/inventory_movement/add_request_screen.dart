// lib/screens/inventory_movement/add_request_screen.dart
//
// "Add Request" — opened from the Request Item page. Records one request for
// items going Adambakkam -> Gojan or Gojan -> Adambakkam, with every detail:
// item(s), quantity, date, time, direction and who is sending it.
//
// Saved as a normal Inventory Movement (checked out at the chosen date/time,
// sent by the chosen person). Items are typed by name with no product link,
// so no stock counts are touched — it simply appears on the Request Item
// page and in the "Please add these items to the Inventory app" alert until
// it is checked in.

import 'package:flutter/material.dart';

import '../../core/access/access_scope.dart';
import '../../models/inventory_movement.dart';
import '../../services/current_user_service.dart';
import '../../services/inventory_movement_service.dart';
import '../../shared/inventory_ui.dart';
import 'request_item_screen.dart' show RequestDirection;

class _ItemRow {
  final name = TextEditingController();
  final qty = TextEditingController(text: '1');
  void dispose() {
    name.dispose();
    qty.dispose();
  }
}

class AddRequestScreen extends StatefulWidget {
  /// Pre-selects the direction (e.g. the tab the user was on).
  final RequestDirection? initialDirection;
  const AddRequestScreen({super.key, this.initialDirection});

  @override
  State<AddRequestScreen> createState() => _AddRequestScreenState();
}

class _AddRequestScreenState extends State<AddRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<_ItemRow> _rows = [_ItemRow()];
  final _sentByController = TextEditingController();
  final _remarksController = TextEditingController();

  late RequestDirection _direction =
      widget.initialDirection ?? RequestDirection.adambakkamToGojan;
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Default "Sent by" to the logged-in user; can still be changed.
    _sentByController.text = CurrentUserService.nameSync;
    CurrentUserService.getName().then((n) {
      if (!mounted) return;
      final cur = _sentByController.text.trim();
      if (cur.isEmpty || cur == 'Unknown') _sentByController.text = n;
    });
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    _sentByController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  int get _totalQty =>
      _rows.fold(0, (sum, r) => sum + (int.tryParse(r.qty.text.trim()) ?? 0));

  String get _from =>
      _direction == RequestDirection.adambakkamToGojan ? 'Adambakkam' : 'Gojan';
  String get _to =>
      _direction == RequestDirection.adambakkamToGojan ? 'Gojan' : 'Adambakkam';

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  String _fmtDate(DateTime d) {
    const mon = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${mon[d.month - 1]} ${d.year}';
  }

  Future<void> _save() async {
    if (!requireEditAccess(context)) return;
    if (!_formKey.currentState!.validate()) return;

    final items = <MovementItem>[];
    for (final r in _rows) {
      final name = r.name.text.trim();
      if (name.isEmpty) continue;
      items.add(MovementItem(
        productId: '',
        productName: name,
        quantity: int.tryParse(r.qty.text.trim()) ?? 0,
      ));
    }
    if (items.isEmpty) {
      showAppSnack(context, 'Add at least one item', isError: true);
      return;
    }

    final when = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    final sentBy = _sentByController.text.trim();

    setState(() => _saving = true);
    try {
      final me = await CurrentUserService.getName();
      await InventoryMovementService.createMovement(
        items: items,
        movementType: MovementType.branch,
        from: _from,
        to: _to,
        purpose: 'Item Request',
        remarks: _remarksController.text.trim(),
        usedBy: sentBy,
        action: MovementAction.checkOut,
        actedBy: sentBy,
        createdBy: me,
        when: when,
      );
      if (!mounted) return;
      showAppSnack(context, 'Request added');
      Navigator.pop(context, true);
    } catch (e) {
      final raw = e.toString();
      final msg = raw.startsWith('Exception: ') ? raw.substring(11) : raw;
      if (mounted) showAppSnack(context, msg, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
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
        title: const Text('Add Request',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionLabel('DIRECTION'),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _dirChip('Adambakkam → Gojan', RequestDirection.adambakkamToGojan)),
              const SizedBox(width: 8),
              Expanded(child: _dirChip('Gojan → Adambakkam', RequestDirection.gojanToAdambakkam)),
            ]),
            const SizedBox(height: 20),

            const SectionLabel('ITEMS'),
            const SizedBox(height: 10),
            for (int i = 0; i < _rows.length; i++) _itemRow(i),
            TextButton.icon(
              onPressed: () => setState(() => _rows.add(_ItemRow())),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add another item'),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text('Total quantity: $_totalQty',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            const SizedBox(height: 20),

            const SectionLabel('DATE & TIME'),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: _pickerTile(
                    Icons.calendar_today_rounded, _fmtDate(_date), _pickDate),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _pickerTile(
                    Icons.access_time_rounded, _time.format(context), _pickTime),
              ),
            ]),
            const SizedBox(height: 20),

            const SectionLabel('SENT BY'),
            const SizedBox(height: 10),
            AppTextField(
              controller: _sentByController,
              label: 'Sent by',
              icon: Icons.person_outline_rounded,
              capitalization: TextCapitalization.words,
              validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Enter who is sending' : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _remarksController,
              label: 'Remarks (optional)',
              icon: Icons.notes_rounded,
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: AppColors.navy,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.navy))
                    : const Icon(Icons.send_rounded),
                label: const Text('Add Request',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dirChip(String label, RequestDirection d) {
    final selected = _direction == d;
    return GestureDetector(
      onTap: () => setState(() => _direction = d),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.navy : Colors.black12),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.navy)),
      ),
    );
  }

  Widget _pickerTile(IconData icon, String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.navy)),
          ),
        ]),
      ),
    );
  }

  Widget _itemRow(int i) {
    final row = _rows[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 3,
          child: AppTextField(
            controller: row.name,
            label: 'Item name',
            hint: 'e.g. Blue Pen',
            icon: Icons.inventory_2_outlined,
            capitalization: TextCapitalization.words,
            validator: (v) {
              // Only the first row is mandatory; blank extra rows are skipped.
              if (i == 0 && (v == null || v.trim().isEmpty)) return 'Enter item';
              return null;
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 1,
          child: TextFormField(
            controller: row.qty,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Qty',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            ),
            validator: (v) {
              if (row.name.text.trim().isEmpty) return null;
              final n = int.tryParse((v ?? '').trim()) ?? 0;
              return n <= 0 ? '> 0' : null;
            },
          ),
        ),
        if (_rows.length > 1)
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.coral),
            onPressed: () => setState(() {
              _rows[i].dispose();
              _rows.removeAt(i);
            }),
          ),
      ]),
    );
  }
}