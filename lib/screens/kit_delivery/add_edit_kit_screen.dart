// lib/screens/kit_delivery/add_edit_kit_screen.dart
//
// Create or edit a kit delivery. The parts list starts from the default kit
// (drone, propellers, motors, battery, charger, controller, bag). For each
// Two manual lists side by side: PRODUCTS DELIVERED (name + qty) and
// PRODUCTS PENDING (name + qty). Both are typed by hand. A product that
// appears in the pending list is owed to the customer and triggers the
// reminder on the promised date.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../constants/drone_categories.dart';
import '../../constants/kit_templates.dart';
import '../../models/customer_details.dart';
import '../../models/kit_delivery.dart';
import '../../services/current_user_service.dart';
import '../../services/customer_service.dart';
import '../../services/kit_delivery_service.dart';
import 'kit_dashboard_screen.dart'
    show kKitBg, kKitNavy, kKitBlue, kKitRed, kKitMuted, kKitBorder, kKitGreen;

/// One typed line: a product name and a quantity.
class _Line {
  final TextEditingController name;
  final TextEditingController qty;
  String category;

  _Line({String name = '', int qty = 0, this.category = 'Other'})
      : name = TextEditingController(text: name),
        qty = TextEditingController(text: qty == 0 ? '' : '$qty');

  int get quantity => int.tryParse(qty.text.trim()) ?? 0;

  void dispose() {
    name.dispose();
    qty.dispose();
  }
}

class AddEditKitScreen extends StatefulWidget {
  /// Null = new kit.
  final KitDelivery? kit;

  const AddEditKitScreen({super.key, this.kit});

  @override
  State<AddEditKitScreen> createState() => _AddEditKitScreenState();
}

class _AddEditKitScreenState extends State<AddEditKitScreen> {
  final _formKey = GlobalKey<FormState>();
  final KitDeliveryService _service = KitDeliveryService();

  final _customer = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _invoice = TextEditingController();
  final _notes = TextEditingController();

  String _branch = kBranchOptions.first;
  DateTime _deliveredAt = DateTime.now();
  DateTime? _promisedDate;
  bool _promisedTouched = false;

  final List<_Line> _delivered = [];
  final List<_Line> _pending = [];
  List<CustomerDetails> _customers = [];

  bool _saving = false;

  bool get _isEdit => widget.kit != null;

  @override
  void initState() {
    super.initState();

    final k = widget.kit;
    if (k != null) {
      _customer.text = k.customerName;
      _phone.text = k.customerPhone;
      _address.text = k.customerAddress;
      _invoice.text = k.invoiceRef;
      _notes.text = k.notes;
      _branch = k.branch;
      _deliveredAt = k.deliveredAt;
      _promisedDate = k.promisedDate;
      _promisedTouched = true;
      for (final i in k.items) {
        if (i.deliveredQty > 0) {
          _delivered.add(_Line(
              name: i.name, qty: i.deliveredQty, category: i.category));
        }
        if (i.pendingQty > 0) {
          _pending.add(
              _Line(name: i.name, qty: i.pendingQty, category: i.category));
        }
      }
    } else {
      // Full kit starts in the delivered list. Edit / remove lines for a
      // part delivery and type the rest into the pending list.
      for (final m in kDefaultKitItems) {
        _delivered.add(_Line(
          name: m['name'] as String,
          qty: m['qty'] as int,
          category: m['category'] as String,
        ));
      }
    }

    _loadCustomers();
  }

  @override
  void dispose() {
    _customer.dispose();
    _phone.dispose();
    _address.dispose();
    _invoice.dispose();
    _notes.dispose();
    for (final l in [..._delivered, ..._pending]) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    // Convenience only — employees without access to Customers simply get
    // no suggestions.
    try {
      final list = await CustomerService().fetchCustomers();
      if (mounted) setState(() => _customers = list);
    } catch (_) {}
  }

  bool get _hasPending =>
      _pending.any((l) => l.name.text.trim().isNotEmpty && l.quantity > 0);

  // Promised date defaults to "delivery date + N days" until the user picks
  // one themselves.
  void _syncDefaultPromised() {
    if (_promisedTouched) return;
    _promisedDate = _hasPending
        ? KitDeliveryService.defaultPromisedDate(_deliveredAt)
        : null;
  }

  Future<DateTime?> _pickDate(DateTime initial,
      {DateTime? first, DateTime? last}) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first ?? DateTime(2020),
      lastDate: last ?? DateTime(2100),
    );
  }

  String _categoryFor(String name) {
    final n = name.trim().toLowerCase();
    for (final m in kDefaultKitItems) {
      if ((m['name'] as String).toLowerCase() == n) {
        return m['category'] as String;
      }
    }
    // Keep the category of an existing part with the same name.
    for (final l in [..._delivered, ..._pending]) {
      if (l.name.text.trim().toLowerCase() == n) return l.category;
    }
    return 'Other';
  }

  void _addLine(List<_Line> list) {
    setState(() {
      list.add(_Line());
      _syncDefaultPromised();
    });
  }

  void _removeLine(List<_Line> list, int index) {
    setState(() {
      list.removeAt(index).dispose();
      _syncDefaultPromised();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Merge the two typed lists into kit parts (same name => one part).
    final delivered = <String, int>{};
    final pending = <String, int>{};
    final display = <String, String>{};
    for (final l in _delivered) {
      final n = l.name.text.trim();
      if (n.isEmpty || l.quantity <= 0) continue;
      final key = n.toLowerCase();
      display.putIfAbsent(key, () => n);
      delivered[key] = (delivered[key] ?? 0) + l.quantity;
    }
    for (final l in _pending) {
      final n = l.name.text.trim();
      if (n.isEmpty || l.quantity <= 0) continue;
      final key = n.toLowerCase();
      display.putIfAbsent(key, () => n);
      pending[key] = (pending[key] ?? 0) + l.quantity;
    }

    if (display.isEmpty) {
      _snack('Enter at least one delivered or pending product.');
      return;
    }

    if (_hasPending && _promisedDate == null) {
      _snack('Pick the date the pending products are promised for.');
      return;
    }

    setState(() => _saving = true);

    final items = [
      for (final e in display.entries)
        KitItem(
          name: e.value,
          category: _categoryFor(e.value),
          requiredQty: (delivered[e.key] ?? 0) + (pending[e.key] ?? 0),
          deliveredQty: delivered[e.key] ?? 0,
        ),
    ];

    KitResult<KitDelivery> result;

    if (_isEdit) {
      final before = widget.kit!;
      final after = before.copyWith(
        customerName: _customer.text.trim(),
        customerPhone: _phone.text.trim(),
        customerAddress: _address.text.trim(),
        branch: _branch,
        invoiceRef: _invoice.text.trim(),
        deliveredAt: _deliveredAt,
        promisedDate: _promisedDate,
        items: items,
        notes: _notes.text.trim(),
      );
      result = await _service.updateKit(before, after);
    } else {
      // Record what was handed over on the first day as the first line of
      // the hand-over history.
      final today = <String, int>{
        for (final i in items)
          if (i.deliveredQty > 0) i.name: i.deliveredQty,
      };
      final who = await CurrentUserService.getName();

      final kit = KitDelivery(
        id: '',
        customerName: _customer.text.trim(),
        customerPhone: _phone.text.trim(),
        customerAddress: _address.text.trim(),
        branch: _branch,
        invoiceRef: _invoice.text.trim(),
        deliveredAt: _deliveredAt,
        promisedDate: _promisedDate,
        items: items,
        handovers: today.isEmpty
            ? const []
            : [
          KitHandover(
            at: _deliveredAt,
            by: who,
            note: 'Initial delivery',
            quantities: today,
          ),
        ],
        notes: _notes.text.trim(),
      );
      // A kit that is complete on day one has nothing to remind about.
      result = await _service.addKit(
        kit.isComplete ? kit.copyWith(completedAt: DateTime.now()) : kit,
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (result.success) {
      Navigator.pop(context, true);
    } else {
      _snack(result.error ?? 'Could not save the kit.');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  InputDecoration _dec(String label, {IconData? icon}) => InputDecoration(
    labelText: label,
    prefixIcon: icon == null ? null : Icon(icon, size: 20),
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kKitBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kKitBorder),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');

    return Scaffold(
      backgroundColor: kKitBg,
      appBar: AppBar(
        backgroundColor: kKitNavy,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _isEdit ? 'Edit Kit' : 'New Kit Delivery',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            // ── Customer ──────────────────────────────────────────────
            const _SectionTitle('Customer'),
            LayoutBuilder(builder: (context, box) {
              final fieldWidth = box.maxWidth;
              return Autocomplete<CustomerDetails>(
                displayStringForOption: (c) => c.name,
                optionsBuilder: (v) {
                  final q = v.text.trim().toLowerCase();
                  if (q.isEmpty) return const Iterable<CustomerDetails>.empty();
                  return _customers
                      .where((c) =>
                  c.nameKey.contains(q) || c.phoneKey.contains(q))
                      .take(6);
                },
                onSelected: (c) {
                  _customer.text = c.name;
                  if ((c.phone ?? '').isNotEmpty) _phone.text = c.phone!;
                  if ((c.shippingAddress ?? c.billingAddress ?? '')
                      .isNotEmpty) {
                    _address.text = c.shippingAddress?.isNotEmpty == true
                        ? c.shippingAddress!
                        : c.billingAddress!;
                  }
                },
                // Pre-fills the field when editing an existing kit.
                initialValue: TextEditingValue(text: _customer.text),
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      color: Colors.white,
                      elevation: 6,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: 260,
                          maxWidth: fieldWidth,
                          minWidth: fieldWidth,
                        ),
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: kKitBorder),
                          itemBuilder: (_, i) {
                            final c = options.elementAt(i);
                            return InkWell(
                              onTap: () => onSelected(c),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c.name,
                                        style: const TextStyle(
                                            color: kKitNavy,
                                            fontWeight: FontWeight.w700)),
                                    if ((c.phone ?? '').isNotEmpty)
                                      Text(c.phone!,
                                          style: const TextStyle(
                                              color: kKitMuted, fontSize: 12)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
                fieldViewBuilder: (context, controller, focus, onSubmit) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focus,
                    // _customer mirrors what is typed so _save() can read it.
                    onChanged: (v) => _customer.text = v,
                    textCapitalization: TextCapitalization.words,
                    decoration: _dec('Customer name *', icon: Icons.person),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter the customer name'
                        : null,
                  );
                },
              );
            }),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: _dec('Phone', icon: Icons.phone),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              maxLines: 2,
              decoration: _dec('Address', icon: Icons.location_on_outlined),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _branch,
                    decoration: _dec('Branch'),
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: kKitNavy, fontSize: 15),
                    items: [
                      for (final b in kBranchOptions)
                        DropdownMenuItem(
                          value: b,
                          child: Text(kBranchLabels[b] ?? b,
                              style: const TextStyle(color: kKitNavy)),
                        ),
                    ],
                    onChanged: (v) => setState(() => _branch = v ?? _branch),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _invoice,
                    decoration: _dec('Invoice / challan no.'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final d = await _pickDate(_deliveredAt,
                    last: DateTime.now().add(const Duration(days: 1)));
                if (d != null) {
                  setState(() {
                    _deliveredAt = d;
                    _syncDefaultPromised();
                  });
                }
              },
              child: InputDecorator(
                decoration: _dec('Delivery date', icon: Icons.event),
                child: Text(fmt.format(_deliveredAt)),
              ),
            ),

            // ── Products delivered | Products pending ─────────────────
            const SizedBox(height: 22),
            LayoutBuilder(builder: (context, c) {
              final delivered = _ProductColumn(
                title: 'Products delivered',
                color: kKitGreen,
                icon: Icons.check_circle_outline,
                lines: _delivered,
                emptyText: 'Nothing delivered yet',
                onAdd: () => _addLine(_delivered),
                onRemove: (i) => _removeLine(_delivered, i),
                onChanged: () => setState(_syncDefaultPromised),
              );
              final pending = _ProductColumn(
                title: 'Products pending',
                color: kKitRed,
                icon: Icons.pending_actions,
                lines: _pending,
                emptyText: 'Nothing pending',
                onAdd: () => _addLine(_pending),
                onRemove: (i) => _removeLine(_pending, i),
                onChanged: () => setState(_syncDefaultPromised),
              );
              if (c.maxWidth >= 640) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: delivered),
                    const SizedBox(width: 14),
                    Expanded(child: pending),
                  ],
                );
              }
              return Column(
                children: [delivered, const SizedBox(height: 14), pending],
              );
            }),

            // ── Pending / reminder ────────────────────────────────────
            const SizedBox(height: 18),
            _PendingBanner(delivered: _delivered, pending: _pending),
            if (_hasPending) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final d = await _pickDate(
                    _promisedDate ?? DateTime.now(),
                    first: DateTime.now().subtract(const Duration(days: 365)),
                  );
                  if (d != null) {
                    setState(() {
                      _promisedDate = d;
                      _promisedTouched = true;
                    });
                  }
                },
                child: InputDecorator(
                  decoration: _dec('Pending parts promised by *',
                      icon: Icons.notifications_active_outlined),
                  child: Text(
                    _promisedDate == null
                        ? 'Pick a date'
                        : '${fmt.format(_promisedDate!)}  '
                        '(reminder at ${kKitReminderHour.toString().padLeft(2, '0')}:'
                        '${kKitReminderMinute.toString().padLeft(2, '0')}, repeats daily)',
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: _dec('Notes', icon: Icons.notes),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: kKitBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: _saving
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
                  : const Icon(Icons.check),
              label: Text(_isEdit ? 'Save changes' : 'Save kit'),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        color: kKitNavy,
        fontWeight: FontWeight.w800,
        fontSize: 15,
      ),
    ),
  );
}

class _PendingBanner extends StatelessWidget {
  final List<_Line> delivered;
  final List<_Line> pending;
  const _PendingBanner({required this.delivered, required this.pending});

  @override
  Widget build(BuildContext context) {
    final p = pending
        .where((l) => l.name.text.trim().isNotEmpty && l.quantity > 0)
        .toList();
    final ok = p.isEmpty;
    final color = ok ? kKitGreen : kKitRed;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.pending_actions, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ok
                  ? 'Complete kit — nothing pending.'
                  : 'Pending: ${p.map((l) => '${l.name.text.trim()} ×${l.quantity}').join(', ')}',
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// One column (delivered or pending): header, typed rows, "Add product".
class _ProductColumn extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final List<_Line> lines;
  final String emptyText;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final VoidCallback onChanged;

  const _ProductColumn({
    required this.title,
    required this.color,
    required this.icon,
    required this.lines,
    required this.emptyText,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final total = lines.fold<int>(0, (a, l) => a + l.quantity);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$title ($total)',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 15),
                ),
              ),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: TextButton.styleFrom(foregroundColor: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (lines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(emptyText,
                    style: const TextStyle(color: kKitMuted, fontSize: 12)),
              ),
            ),
          for (int i = 0; i < lines.length; i++)
            _LineRow(
              key: ObjectKey(lines[i]),
              line: lines[i],
              color: color,
              onChanged: onChanged,
              onRemove: () => onRemove(i),
            ),
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  final _Line line;
  final Color color;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _LineRow({
    super.key,
    required this.line,
    required this.color,
    required this.onChanged,
    required this.onRemove,
  });

  OutlineInputBorder _border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: c, width: w),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              controller: line.name,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => onChanged(),
              validator: (v) {
                final hasQty = line.quantity > 0;
                final hasName = (v ?? '').trim().isNotEmpty;
                if (!hasName && hasQty) return 'Enter product name';
                return null;
              },
              decoration: InputDecoration(
                hintText: 'Product name',
                isDense: true,
                border: _border(kKitBorder),
                enabledBorder: _border(kKitBorder),
                focusedBorder: _border(color, 1.6),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: TextFormField(
              controller: line.qty,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              textAlign: TextAlign.center,
              onChanged: (_) => onChanged(),
              validator: (v) {
                final hasName = line.name.text.trim().isNotEmpty;
                final q = int.tryParse((v ?? '').trim()) ?? 0;
                if (hasName && q <= 0) return 'Qty';
                return null;
              },
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                hintText: 'Qty',
                isDense: true,
                border: _border(kKitBorder),
                enabledBorder: _border(kKitBorder),
                focusedBorder: _border(color, 1.6),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 18, color: kKitMuted),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}