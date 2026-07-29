// lib/screens/inventory_movement/add_movement_screen.dart
//
// Create a new Inventory Movement request (always starts as Pending —
// see InventoryMovementService.createMovement). Product selection reuses
// ProductService.getProducts() + an Autocomplete<Product>, the same
// pattern already used in screens/invoices/add_invoice_screen.dart.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/access/access_scope.dart';
import '../../models/inventory_movement.dart';
import '../../models/product.dart';
import '../../services/inventory_movement_service.dart';
import '../../services/product_service.dart';
import '../../shared/inventory_ui.dart';

class AddMovementScreen extends StatefulWidget {
  final InventoryMovement? editMovement;
  const AddMovementScreen({super.key, this.editMovement});

  @override
  State<AddMovementScreen> createState() => _AddMovementScreenState();
}

class _AddMovementScreenState extends State<AddMovementScreen> {
  final _formKey = GlobalKey<FormState>();

  final _productController = TextEditingController();
  final _quantityController = TextEditingController();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _takenByController = TextEditingController();
  final _usedByController = TextEditingController();
  final _purposeController = TextEditingController();
  final _remarksController = TextEditingController();

  String _movementType = MovementType.branch;
  Product? _selectedProduct;
  String? _selectedProductId;
  DateTime? _expectedReturnAt;
  bool _saving = false;
  bool _loadingProducts = true;
  List<Product> _products = [];

  bool get _isEditing => widget.editMovement != null;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    final editing = widget.editMovement;
    if (editing != null) {
      _productController.text = editing.productName;
      _selectedProductId = editing.productId.isNotEmpty ? editing.productId : null;
      _quantityController.text = '${editing.quantity}';
      _movementType = editing.movementType;
      _fromController.text = editing.from;
      _toController.text = editing.to;
      _takenByController.text = editing.takenBy;
      _usedByController.text = editing.usedBy;
      _purposeController.text = editing.purpose;
      _remarksController.text = editing.remarks;
      _expectedReturnAt = editing.expectedReturnAt;
    } else {
      // Pre-fill "Taken By" with the current user's name — same convenience
      // pattern as other create screens that know who's logged in.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final access = context.read<CurrentAccess>().access;
        if (access != null && access.name.isNotEmpty) {
          _takenByController.text = access.name;
        }
      });
    }
  }

  Future<void> _loadProducts() async {
    try {
      final list = await ProductService.getProducts();
      if (mounted) {
        setState(() {
          _products = list;
          _loadingProducts = false;
          if (_selectedProductId != null) {
            for (final p in list) {
              if (p.id == _selectedProductId) {
                _selectedProduct = p;
                break;
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
    _productController.dispose();
    _quantityController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _takenByController.dispose();
    _usedByController.dispose();
    _purposeController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _pickExpectedReturn() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _expectedReturnAt ?? now.add(const Duration(days: 1)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 3),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.navy, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_expectedReturnAt ?? now),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.navy, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (time == null) return;
    setState(() {
      _expectedReturnAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  String get _expectedReturnLabel {
    if (_expectedReturnAt == null) return '';
    final d = _expectedReturnAt!;
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final p = d.hour < 12 ? 'AM' : 'PM';
    return '${d.day}-${d.month}-${d.year}  •  $h:$m $p';
  }

  Future<void> _save() async {
    if (!requireEditAccess(context)) return;
    if (!_formKey.currentState!.validate()) return;
    final productName = _productController.text.trim();
    if (productName.isEmpty) {
      showAppSnack(context, 'Please enter or select a product', isError: true);
      return;
    }
    // Selected from the autocomplete list -> use its id (so stock stays in
    // sync). Typed manually / no longer matches the selection -> submit as
    // a free-text item with no productId; dispatch simply skips the stock
    // decrement for it.
    final productId = (_selectedProduct != null && _selectedProduct!.name == productName)
        ? _selectedProduct!.id
        : (_selectedProductId ?? '');

    setState(() => _saving = true);
    try {
      final access = context.read<CurrentAccess>().access;
      final createdBy = (access?.name.isNotEmpty ?? false) ? access!.name : (access?.email ?? 'Unknown');

      if (_isEditing) {
        await InventoryMovementService.updateMovement(
          id: widget.editMovement!.id,
          productId: productId,
          productName: productName,
          quantity: int.parse(_quantityController.text.trim()),
          movementType: _movementType,
          from: _fromController.text.trim(),
          to: _toController.text.trim(),
          purpose: _purposeController.text.trim(),
          remarks: _remarksController.text.trim(),
          takenBy: _takenByController.text.trim(),
          usedBy: _usedByController.text.trim(),
          expectedReturnAt: _expectedReturnAt,
        );
        if (!mounted) return;
        showAppSnack(context, 'Movement updated');
      } else {
        await InventoryMovementService.createMovement(
          productId: productId,
          productName: productName,
          quantity: int.parse(_quantityController.text.trim()),
          movementType: _movementType,
          from: _fromController.text.trim(),
          to: _toController.text.trim(),
          purpose: _purposeController.text.trim(),
          remarks: _remarksController.text.trim(),
          takenBy: _takenByController.text.trim(),
          usedBy: _usedByController.text.trim(),
          createdBy: createdBy,
          expectedReturnAt: _expectedReturnAt,
        );
        if (!mounted) return;
        showAppSnack(context, 'Movement request submitted for approval');
      }
      await Future.delayed(const Duration(milliseconds: 500));
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
    if (_isEditing && !widget.editMovement!.isPending) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text('Edit Movement', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'This movement has already moved past Pending and can no longer be edited.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ),
      );
    }
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
                title: _isEditing ? 'Edit Movement' : 'Request a Movement',
                subtitle: _isEditing
                    ? 'Update the details of this pending request'
                    : 'Goes to Pending — an admin approves before it can be dispatched',
              ),
              const SizedBox(height: 20),
              const SectionLabel('PRODUCT & QUANTITY'),
              const SizedBox(height: 10),
              FormCard(children: [
                _loadingProducts
                    ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(color: AppColors.teal),
                )
                    : _productAutocomplete(),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _quantityController,
                  label: 'Quantity',
                  icon: Icons.numbers_rounded,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final n = int.tryParse(v.trim());
                    if (n == null || n <= 0) return 'Enter a valid quantity';
                    if (_selectedProduct != null && n > _selectedProduct!.quantity) {
                      return 'Only ${_selectedProduct!.quantity} available';
                    }
                    return null;
                  },
                ),
              ]),
              const SizedBox(height: 20),
              const SectionLabel('MOVEMENT DETAILS'),
              const SizedBox(height: 10),
              FormCard(children: [
                AppDropdown(
                  value: _movementType,
                  label: 'Movement Type',
                  icon: Icons.category_rounded,
                  items: MovementType.all,
                  onChanged: (v) => setState(() => _movementType = v!),
                ),
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
                  label: 'Purpose',
                  icon: Icons.work_outline_rounded,
                  capitalization: TextCapitalization.sentences,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                AppDatePickerField(
                  value: _expectedReturnLabel,
                  placeholder: 'Expected Return Date & Time',
                  onTap: _pickExpectedReturn,
                ),
              ]),
              const SizedBox(height: 20),
              const SectionLabel('PEOPLE'),
              const SizedBox(height: 10),
              FormCard(children: [
                AppTextField(
                  controller: _takenByController,
                  label: 'Taken By',
                  icon: Icons.person_rounded,
                  capitalization: TextCapitalization.words,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _usedByController,
                  label: 'Used By (optional)',
                  icon: Icons.badge_rounded,
                  capitalization: TextCapitalization.words,
                ),
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
                      Icon(_isEditing ? Icons.save_rounded : Icons.send_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(_isEditing ? 'Save Changes' : 'Submit for Approval',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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

  Widget _productAutocomplete() {
    return Autocomplete<Product>(
      initialValue: TextEditingValue(text: _productController.text),
      displayStringForOption: (p) => p.name,
      optionsBuilder: (value) {
        if (value.text.trim().isEmpty) return const Iterable<Product>.empty();
        final q = value.text.toLowerCase();
        return _products.where((p) => p.name.toLowerCase().contains(q));
      },
      onSelected: (selection) {
        setState(() {
          _selectedProduct = selection;
          _selectedProductId = selection.id;
          _productController.text = selection.name;
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
        // Keep Autocomplete's internal controller in sync with ours, same
        // pattern as the Item picker in add_invoice_screen.dart.
        if (controller.text != _productController.text) {
          controller.text = _productController.text;
        }
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.words,
          onChanged: (v) {
            _productController.text = v;
            // Typing something that no longer matches the picked product
            // turns this back into a free-text (manual) entry instead of
            // silently keeping the old product's id.
            if (_selectedProduct != null && v.trim() != _selectedProduct!.name) {
              _selectedProduct = null;
              _selectedProductId = null;
            }
          },
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.navy),
          decoration: InputDecoration(
            labelText: 'Product',
            helperText: 'Pick from the list, or type a name manually',
            helperStyle: TextStyle(color: Colors.grey.shade400, fontSize: 11.5),
            labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            prefixIcon: const Icon(Icons.inventory_2_rounded, size: 20, color: Colors.grey),
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