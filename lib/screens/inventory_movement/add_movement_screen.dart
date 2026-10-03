// lib/screens/inventory_movement/add_movement_screen.dart
//
// Create a new Inventory Movement — v2.
//
//   - Add as many line items (product + quantity) as needed; the total
//     quantity is summed automatically at the bottom and saved with the
//     movement.
//   - Pick Check Out or Check In up front — whichever is picked gets its
//     date & time stamped the moment you submit. No approval step.
//   - Movement Type is a dropdown of common values, but also lets you type
//     a custom one in — same "pick or type" pattern as the Product field.
//
// Editing an existing movement only lets you change the details (type,
// from/to, purpose, remarks, used by) — the items and their quantities are
// locked in once stock has already moved.

import 'package:flutter/material.dart';

import '../../core/access/access_scope.dart';
import '../../models/inventory_movement.dart';
import '../../models/product.dart';
import '../../services/current_user_service.dart';
import '../../services/inventory_movement_service.dart';
import '../../services/product_service.dart';
import '../../shared/inventory_ui.dart';
import '../../widgets/common/auto_user_field.dart';
import '../../widgets/common/serial_scan_screen.dart';

class AddMovementScreen extends StatefulWidget {
  final InventoryMovement? editMovement;
  const AddMovementScreen({super.key, this.editMovement});

  @override
  State<AddMovementScreen> createState() => _AddMovementScreenState();
}

/// One editable line item row in the form.
class _ItemRow {
  final productController = TextEditingController();
  final quantityController = TextEditingController();
  Product? selectedProduct;
  String? selectedProductId;

  void dispose() {
    productController.dispose();
    quantityController.dispose();
  }
}

class _AddMovementScreenState extends State<AddMovementScreen> {
  final _formKey = GlobalKey<FormState>();

  final List<_ItemRow> _rows = [];

  final _typeController = TextEditingController();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _usedByController = TextEditingController();
  final _purposeController = TextEditingController();
  final _remarksController = TextEditingController();

  MovementAction _action = MovementAction.checkOut;
  bool _saving = false;
  bool _loadingProducts = true;
  List<Product> _products = [];

  // Manual date & time for the action being recorded. Defaults to "now" but
  // can be changed to backdate/forward-date a check-out or check-in.
  DateTime _actionDateTime = DateTime.now();

  // When editing, these let the existing Check Out / Check In stamps be
  // corrected independently (only shown if that side already happened).
  DateTime? _editCheckedOutAt;
  DateTime? _editCheckedInAt;

  // Whether the movement being edited was originally saved with zero items —
  // if so, the item rows are editable (safe to backfill, no stock to reconcile)
  // instead of the normal "locked" read-only display.
  bool _editItemsAreEmpty = false;

  bool get _isEditing => widget.editMovement != null;

  _ItemRow _newRow() {
    final row = _ItemRow();
    // Keep the running total-quantity chip in sync as the user types.
    row.quantityController.addListener(() {
      if (mounted) setState(() {});
    });
    return row;
  }

  @override
  void initState() {
    super.initState();
    _loadProducts();
    final editing = widget.editMovement;
    if (editing != null) {
      for (final item in editing.items) {
        final row = _newRow();
        row.productController.text = item.productName;
        row.quantityController.text = '${item.quantity}';
        row.selectedProductId = item.productId.isNotEmpty ? item.productId : null;
        _rows.add(row);
      }
      if (_rows.isEmpty) _rows.add(_newRow());
      _typeController.text = editing.movementType;
      _fromController.text = editing.from;
      _toController.text = editing.to;
      _usedByController.text = editing.usedBy;
      _purposeController.text = editing.purpose;
      _remarksController.text = editing.remarks;
      _action = editing.isCheckedOut ? MovementAction.checkOut : MovementAction.checkIn;
      _editCheckedOutAt = editing.checkedOutAt;
      _editCheckedInAt = editing.checkedInAt;
      _editItemsAreEmpty = editing.items.isEmpty;
    } else {
      _rows.add(_newRow());
      _typeController.text = MovementType.branch;
      // "Used By" starts empty — the person filling the form picks who it's
      // for, instead of it being pre-filled with whoever is logged in.
    }
  }

  Future<void> _loadProducts() async {
    try {
      final list = await ProductService.getProducts();
      if (mounted) {
        setState(() {
          _products = list;
          _loadingProducts = false;
          for (final row in _rows) {
            if (row.selectedProductId != null) {
              for (final p in list) {
                if (p.id == row.selectedProductId) {
                  row.selectedProduct = p;
                  break;
                }
              }
            }
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    _typeController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _usedByController.dispose();
    _purposeController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  int get _totalQuantity {
    var total = 0;
    for (final row in _rows) {
      total += int.tryParse(row.quantityController.text.trim()) ?? 0;
    }
    return total;
  }

  Future<void> _pickDateTime(DateTime initial, void Function(DateTime) onPicked) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    onPicked(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y  $h:$min';
  }

  Widget _dateTimePickerField({
    required String label,
    required DateTime value,
    required IconData icon,
    required ValueChanged<DateTime> onChanged,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _pickDateTime(value, onChanged),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          prefixIcon: Icon(icon, size: 20, color: Colors.grey),
          suffixIcon: const Icon(Icons.edit_calendar_rounded, size: 20, color: Colors.grey),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        child: Text(_formatDateTime(value),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.navy)),
      ),
    );
  }

  void _addRow() => setState(() => _rows.add(_newRow()));

  void _removeRow(int index) {
    if (_rows.length == 1) return; // always keep at least one row
    setState(() {
      _rows[index].dispose();
      _rows.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!requireEditAccess(context)) return;
    if (!_formKey.currentState!.validate()) return;

    final items = <MovementItem>[];
    for (final row in _rows) {
      final name = row.productController.text.trim();
      if (name.isEmpty) continue;
      final qty = int.tryParse(row.quantityController.text.trim()) ?? 0;
      final productId = (row.selectedProduct != null && row.selectedProduct!.name == name)
          ? row.selectedProduct!.id
          : (row.selectedProductId ?? '');
      items.add(MovementItem(productId: productId, productName: name, quantity: qty));
    }
    if (items.isEmpty) {
      showAppSnack(context, 'Add at least one item', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      // Logged-in user's name — never typed manually.
      final actedBy = await CurrentUserService.getName();
      final usedBy = (_isEditing && widget.editMovement!.usedBy.trim().isNotEmpty)
          ? widget.editMovement!.usedBy.trim()
          : actedBy;

      if (_isEditing) {
        await InventoryMovementService.updateMovement(
          id: widget.editMovement!.id,
          movementType: _typeController.text.trim(),
          from: _fromController.text.trim(),
          to: _toController.text.trim(),
          purpose: _purposeController.text.trim(),
          remarks: _remarksController.text.trim(),
          usedBy: usedBy,
          checkedOutAt: _editCheckedOutAt,
          checkedInAt: _editCheckedInAt,
          items: _editItemsAreEmpty ? items : null,
        );
        if (!mounted) return;
        showAppSnack(context, 'Movement updated');
      } else {
        await InventoryMovementService.createMovement(
          items: items,
          movementType: _typeController.text.trim(),
          from: _fromController.text.trim(),
          to: _toController.text.trim(),
          purpose: _purposeController.text.trim(),
          remarks: _remarksController.text.trim(),
          usedBy: usedBy,
          action: _action,
          actedBy: actedBy,
          createdBy: actedBy,
          when: _actionDateTime,
        );
        if (!mounted) return;
        showAppSnack(context,
            _action == MovementAction.checkOut ? 'Checked out' : 'Checked in');
      }
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) Navigator.pop(context, true);
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
        title: Text(_isEditing ? 'Edit Movement' : 'New Movement',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HeroBanner(
                icon: Icons.compare_arrows_rounded,
                title: _isEditing ? 'Edit Movement' : 'New Movement',
                subtitle: _isEditing
                    ? 'Update the details of this movement'
                    : 'Saved instantly — no approval needed',
              ),
              const SizedBox(height: 20),
              if (!_isEditing) ...[
                const SectionLabel('ACTION'),
                const SizedBox(height: 10),
                _actionSelector(),
                const SizedBox(height: 20),
                SectionLabel(_action == MovementAction.checkOut ? 'CHECK OUT DATE & TIME' : 'CHECK IN DATE & TIME'),
                const SizedBox(height: 10),
                _dateTimePickerField(
                  label: _action == MovementAction.checkOut ? 'Checked Out At' : 'Checked In At',
                  value: _actionDateTime,
                  icon: Icons.event_rounded,
                  onChanged: (dt) => setState(() => _actionDateTime = dt),
                ),
                const SizedBox(height: 20),
              ] else ...[
                const SectionLabel('DATE & TIME'),
                const SizedBox(height: 10),
                FormCard(children: [
                  if (_editCheckedOutAt != null) ...[
                    _dateTimePickerField(
                      label: 'Checked Out At',
                      value: _editCheckedOutAt!,
                      icon: Icons.north_east_rounded,
                      onChanged: (dt) => setState(() => _editCheckedOutAt = dt),
                    ),
                    if (_editCheckedInAt != null) const SizedBox(height: 14),
                  ],
                  if (_editCheckedInAt != null)
                    _dateTimePickerField(
                      label: 'Checked In At',
                      value: _editCheckedInAt!,
                      icon: Icons.south_west_rounded,
                      onChanged: (dt) => setState(() => _editCheckedInAt = dt),
                    ),
                  if (_editCheckedOutAt == null && _editCheckedInAt == null)
                    Text('No stamps yet for this movement.',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500)),
                ]),
                const SizedBox(height: 20),
              ],
              const SectionLabel('ITEMS'),
              const SizedBox(height: 10),
              if (_isEditing && !_editItemsAreEmpty)
                FormCard(children: [
                  for (var i = 0; i < _rows.length; i++) ...[
                    if (i > 0) const Divider(height: 20),
                    Text(_rows[i].productController.text,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy)),
                    const SizedBox(height: 2),
                    Text('Qty ${_rows[i].quantityController.text}',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                  ],
                  const SizedBox(height: 6),
                  Text('Items are locked once a movement is saved.',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
                ])
              else ...[
                if (_isEditing) ...[
                  Text('This movement was saved without a product on record — you can add one now.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 10),
                ],
                for (var i = 0; i < _rows.length; i++) ...[
                  _itemCard(i),
                  const SizedBox(height: 10),
                ],
                OutlinedButton.icon(
                  onPressed: _addRow,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Item'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.navy,
                    side: const BorderSide(color: AppColors.navy),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    minimumSize: const Size(double.infinity, 0),
                  ),
                ),
                const SizedBox(height: 12),
                _totalQuantityCard(),
              ],
              const SizedBox(height: 20),
              const SectionLabel('MOVEMENT DETAILS'),
              const SizedBox(height: 10),
              FormCard(children: [
                MovementTypeField(controller: _typeController),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _fromController,
                  label: 'From',
                  icon: Icons.trip_origin_rounded,
                  capitalization: TextCapitalization.words,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _toController,
                  label: 'To / Destination',
                  icon: Icons.place_rounded,
                  capitalization: TextCapitalization.words,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _purposeController,
                  label: 'Purpose (optional)',
                  icon: Icons.work_outline_rounded,
                  capitalization: TextCapitalization.sentences,
                ),
              ]),
              const SizedBox(height: 20),
              const SectionLabel('PEOPLE'),
              const SizedBox(height: 10),
              FormCard(children: [
                _usedByField(),
              ]),
              const SizedBox(height: 20),
              const SectionLabel('REMARKS (OPTIONAL)'),
              const SizedBox(height: 10),
              FormCard(children: [
                TextFormField(
                  controller: _remarksController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Add any notes or remarks…',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    border: InputBorder.none,
                  ),
                ),
              ]),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade200,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_isEditing
                          ? Icons.save_rounded
                          : (_action == MovementAction.checkOut ? Icons.north_east_rounded : Icons.south_west_rounded),
                          size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _isEditing
                            ? 'Save Changes'
                            : (_action == MovementAction.checkOut ? 'Check Out' : 'Check In'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionSelector() {
    Widget seg(String label, IconData icon, MovementAction value, Color color) {
      final selected = _action == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _action = value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: selected ? color : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? color : Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(icon, color: selected ? Colors.white : Colors.grey.shade400, size: 22),
                const SizedBox(height: 4),
                Text(label,
                    style: TextStyle(
                        color: selected ? Colors.white : Colors.grey.shade500,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ],
            ),
          ),
        ),
      );
    }

    return Row(children: [
      seg('Check Out', Icons.north_east_rounded, MovementAction.checkOut, AppColors.coral),
      const SizedBox(width: 10),
      seg('Check In', Icons.south_west_rounded, MovementAction.checkIn, AppColors.green),
    ]);
  }

  Widget _totalQuantityCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        const Icon(Icons.functions_rounded, color: AppColors.teal, size: 20),
        const SizedBox(width: 10),
        const Text('Total Quantity', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text('$_totalQuantity',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
      ]),
    );
  }

  Widget _itemCard(int index) {
    final row = _rows[index];
    return FormCard(children: [
      Row(children: [
        Expanded(
          child: Text('Item ${index + 1}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey)),
        ),
        if (_rows.length > 1)
          IconButton(
            onPressed: () => _removeRow(index),
            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.coral),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
          ),
      ]),
      const SizedBox(height: 4),
      _loadingProducts
          ? const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(color: AppColors.teal),
      )
          : _productAutocomplete(row),
      const SizedBox(height: 14),
      AppTextField(
        controller: row.quantityController,
        label: 'Quantity',
        icon: Icons.numbers_rounded,
        keyboardType: TextInputType.number,
        validator: (v) {
          if (row.productController.text.trim().isEmpty) return null;
          if (v == null || v.trim().isEmpty) return 'Required';
          final n = int.tryParse(v.trim());
          if (n == null || n <= 0) return 'Enter a valid quantity';
          if (_action == MovementAction.checkOut &&
              row.selectedProduct != null &&
              n > row.selectedProduct!.quantity) {
            return 'Only ${row.selectedProduct!.quantity} available';
          }
          return null;
        },
      ),
    ]);
  }

  // Auto-filled from the logged-in user — not editable. When editing an
  // existing movement the original "Used By" name is kept.
  Widget _usedByField() {
    return AutoUserField(
      controller: _usedByController,
      label: 'Used By (auto)',
      accent: AppColors.teal,
      preferExisting: _isEditing,
    );
  }

  Future<void> _scanProduct(_ItemRow row) async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const SerialScanScreen(title: 'Scan Product Serial'),
      ),
    );
    if (code == null || code.trim().isEmpty || !mounted) return;
    final scanned = code.trim();

    Product? match;
    for (final p in _products) {
      if ((p.serialNumber ?? '').trim() == scanned) {
        match = p;
        break;
      }
    }
    match ??= await ProductService.getBySerial(scanned);

    if (!mounted) return;
    if (match != null) {
      setState(() {
        row.selectedProduct = match;
        row.selectedProductId = match!.id;
        row.productController.text = match!.name;
      });
      showAppSnack(context, '${match.name} selected');
    } else {
      showAppSnack(context, 'No product found for serial "$scanned"', isError: true);
    }
  }

  Widget _productAutocomplete(_ItemRow row) {
    return Autocomplete<Product>(
      initialValue: TextEditingValue(text: row.productController.text),
      displayStringForOption: (p) => p.name,
      optionsBuilder: (value) {
        if (value.text.trim().isEmpty) return const Iterable<Product>.empty();
        final q = value.text.toLowerCase();
        return _products.where((p) => p.name.toLowerCase().contains(q));
      },
      onSelected: (selection) {
        setState(() {
          row.selectedProduct = selection;
          row.selectedProductId = selection.id;
          row.productController.text = selection.name;
        });
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 400),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(option.name),
                    subtitle: Text('${option.category} · Qty ${option.quantity}',
                        style: const TextStyle(fontSize: 11)),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        if (controller.text != row.productController.text) {
          controller.text = row.productController.text;
        }
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.words,
          onChanged: (v) {
            row.productController.text = v;
            if (row.selectedProduct != null && v.trim() != row.selectedProduct!.name) {
              row.selectedProduct = null;
              row.selectedProductId = null;
            }
            setState(() {});
          },
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.navy),
          decoration: InputDecoration(
            labelText: 'Product',
            helperText: 'Pick from the list, or type a name manually',
            helperStyle: TextStyle(color: Colors.grey.shade400, fontSize: 11.5),
            labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            prefixIcon: const Icon(Icons.inventory_2_rounded, size: 20, color: Colors.grey),
            suffixIcon: IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: Colors.grey),
              tooltip: 'Scan product serial',
              onPressed: () => _scanProduct(row),
            ),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.teal, width: 1.5)),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
          validator: (v) {
            // Only the first row is strictly required; extra blank rows
            // are simply ignored on save.
            return null;
          },
        );
      },
    );
  }
}

/// Movement Type field — a dropdown of the common values (Branch, Workshop,
/// Expo, Repair, Other) that can also be typed into freely, same "pick or
/// type" pattern as the Product picker above.
class MovementTypeField extends StatelessWidget {
  final TextEditingController controller;
  const MovementTypeField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (value) {
        if (value.text.trim().isEmpty) return MovementType.all;
        final q = value.text.toLowerCase();
        return MovementType.all.where((t) => t.toLowerCase().contains(q));
      },
      onSelected: (selection) => controller.text = selection,
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 400),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(option),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
      fieldViewBuilder: (context, fieldController, focusNode, onSubmitted) {
        if (fieldController.text != controller.text) {
          fieldController.text = controller.text;
        }
        return TextFormField(
          controller: fieldController,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.words,
          onChanged: (v) => controller.text = v,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.navy),
          decoration: InputDecoration(
            labelText: 'Movement Type',
            helperText: 'Pick from the list, or type your own',
            helperStyle: TextStyle(color: Colors.grey.shade400, fontSize: 11.5),
            labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            prefixIcon: const Icon(Icons.category_rounded, size: 20, color: Colors.grey),
            suffixIcon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.teal, width: 1.5)),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
        );
      },
    );
  }
}