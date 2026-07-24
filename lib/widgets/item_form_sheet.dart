// lib/widgets/item_form_sheet.dart

import 'package:flutter/material.dart';
import 'package:cda_inventory/models/inventory_item.dart';
import 'package:cda_inventory/services/branch_inventory_service.dart';

class ItemFormSheet extends StatefulWidget {
  final int branchId;
  final InventoryItem? existingItem; // null = add mode
  final String? initialCategory;

  const ItemFormSheet({
    super.key,
    required this.branchId,
    this.existingItem,
    this.initialCategory,
  });

  @override
  State<ItemFormSheet> createState() => _ItemFormSheetState();
}

class _ItemFormSheetState extends State<ItemFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _qtyController;
  late TextEditingController _notesController;
  late String _category;
  late String _status;
  String? _dateIn;
  String? _dateOut;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;
    _nameController = TextEditingController(text: item?.itemName ?? '');
    _qtyController = TextEditingController(text: (item?.quantity ?? 1).toString());
    _notesController = TextEditingController(text: item?.notes ?? '');
    _category = item?.category ?? widget.initialCategory ?? kFormCategories.first.key;
    _status = item?.status ?? 'in_stock';
    _dateIn = item?.dateIn;
    _dateOut = item?.dateOut;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _tracksDates => categoryByKey(_category).tracksDates;

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final formatted =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    setState(() {
      if (isStart) {
        _dateIn = formatted;
      } else {
        _dateOut = formatted;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final item = InventoryItem(
      id: widget.existingItem?.id,
      branchId: widget.branchId,
      category: _category,
      itemName: _nameController.text.trim(),
      quantity: int.tryParse(_qtyController.text.trim()) ?? 1,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      dateIn: _tracksDates ? _dateIn : null,
      dateOut: _tracksDates ? _dateOut : null,
      status: _status,
    );

    try {
      final saved = _isEdit
          ? await BranchInventoryService.updateItem(widget.branchId, item)
          : await BranchInventoryService.createItem(widget.branchId, item);
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;

    // This sheet's background is hardcoded to solid white (below), but its
    // Text/label/border colors were relying on the AMBIENT app theme. When
    // the app is in dark mode (the default — see ThemeProvider), the
    // ambient theme's default text/label/border colors resolve to white,
    // which is invisible against this sheet's white background — every
    // label, the "Edit Item" title, and every field outline disappeared,
    // leaving only the explicitly-colored category icon and the
    // explicitly-colored Save button visible. Forcing a fixed light theme
    // for this subtree guarantees dark, readable text/borders here no
    // matter what theme mode the rest of the app is using.
    return Theme(
      data: ThemeData.light().copyWith(
        primaryColor: Theme.of(context).primaryColor,
        colorScheme: ThemeData.light().colorScheme.copyWith(
          secondary: Theme.of(context).colorScheme.secondary,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: Colors.black87),
          hintStyle: TextStyle(color: Colors.black45),
          floatingLabelStyle: TextStyle(color: Colors.black87),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blue, width: 2),
          ),
        ),
      ),
      child: AnimatedPadding(
        padding: viewInsets,
        duration: const Duration(milliseconds: 150),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Text(
                    _isEdit ? 'Edit Item' : 'Add Item',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                    items: kFormCategories
                        .map((c) => DropdownMenuItem(
                      value: c.key,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(c.icon, size: 18, color: c.color),
                          const SizedBox(width: 8),
                          Text(c.label),
                        ],
                      ),
                    ))
                        .toList(),
                    onChanged: (v) => setState(() => _category = v!),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Item name', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Item name is required' : null,
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _qtyController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
                          validator: (v) {
                            final n = int.tryParse(v?.trim() ?? '');
                            if (n == null || n < 0) return 'Enter a valid quantity';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _status,
                          decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                          items: kStatusLabels.entries
                              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                              .toList(),
                          onChanged: (v) => setState(() => _status = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
                  ),

                  if (_tracksDates) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _DateField(label: 'Date In', value: _dateIn, onTap: () => _pickDate(isStart: true)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DateField(label: 'Date Out', value: _dateOut, onTap: () => _pickDate(isStart: false)),
                        ),
                      ],
                    ),
                  ],

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ],

                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade900,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : Text(_isEdit ? 'Save Changes' : 'Add Item'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _DateField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        child: Text(value ?? 'Tap to set', style: TextStyle(color: value == null ? Colors.grey : Colors.black87)),
      ),
    );
  }
}