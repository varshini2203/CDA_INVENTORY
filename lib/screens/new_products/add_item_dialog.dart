// lib/screens/new_products/add_item_dialog.dart
//
// QUICK ADD -- opened from the "Add Item" button on the Add Product page.
//
// Item Name shows suggestions: focus the box and every existing product name
// is listed; type "s" and the list narrows to names starting with / containing
// "s" (same behaviour as Product Name on the Add Product page).
//
// Fields: Item Name, Item Code (blank = auto), Category, Sale Price, GST
// (With / Without), Opening Stock, Opening Date, Branch, Description and the
// website / branches group. Everything else gets a sensible default
// (Unit = Pcs, vendor blank). Use the normal Add Product page when you need
// full details (HSN, brand, vendor, image, discount, wholesale...).
//
// Save               -> saves and closes (Add Product page closes too, the
//                       New Products list refreshes).
// Save & Add Another -> saves, clears Name / Code / Price / Description and
//                       stays open. Category, GST, Branch, Date and Group stay
//                       selected so a batch of similar items is quick to enter.

import 'package:flutter/material.dart';

import 'package:cda_inventory/models/new_product.dart';
import 'package:cda_inventory/services/new_product_service.dart';
import 'package:cda_inventory/services/current_user_service.dart';

class AddItemDialog extends StatefulWidget {
  const AddItemDialog({super.key});

  /// Opens the Quick Add popup. Returns true when at least one item was saved.
  /// ([existing] is kept only so older calls still compile; it is ignored.)
  static Future<bool?> show(BuildContext context, {NewProduct? existing}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      routeSettings: const RouteSettings(name: 'Quick Add Item'),
      builder: (_) => const AddItemDialog(),
    );
  }

  @override
  State<AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<AddItemDialog> {
  static const Color _blue = Color(0xFF1565C0);
  static const Color _navy = Color(0xFF0D1B4B);

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _price = TextEditingController();
  final _qty = TextEditingController(text: '1');
  final _desc = TextEditingController();
  final _nameFocus = FocusNode();

  // These stay selected after "Save & Add Another".
  String _category = 'Other';
  String _gstChoice = NewProductGst.dropdownLabelFor(0);
  String _branch = 'CDA Admin';
  bool _listedOnWebsite = false;
  DateTime _openingDate = DateTime.now();

  List<String> _allNames = const []; // existing product names (suggestions)

  bool _saving = false;
  int _savedCount = 0; // items saved in this popup session
  String? _lastSaved; // name of the last saved item (for the green message)

  @override
  void initState() {
    super.initState();
    _loadProductNames();
  }

  Future<void> _loadProductNames() async {
    try {
      final all = await NewProductService.getNewProducts();
      final seen = <String>{};
      final names = <String>[];
      for (final p in all) {
        final n = p.productName.trim();
        if (n.isNotEmpty && seen.add(n.toLowerCase())) names.add(n);
      }
      names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      if (mounted) setState(() => _allNames = names);
    } catch (_) {
      // Suggestions are a convenience only -- typing still works without.
    }
  }

  /// Item Name box with a suggestion list of existing product names.
  Widget _nameField(TextStyle txt) {
    return LayoutBuilder(builder: (context, constraints) {
      return RawAutocomplete<String>(
        textEditingController: _name,
        focusNode: _nameFocus,
        optionsBuilder: (TextEditingValue v) {
          final q = v.text.trim().toLowerCase();
          if (q.isEmpty) return _allNames;
          final starts =
          _allNames.where((n) => n.toLowerCase().startsWith(q));
          final contains = _allNames.where((n) =>
          !n.toLowerCase().startsWith(q) && n.toLowerCase().contains(q));
          return [...starts, ...contains];
        },
        displayStringForOption: (s) => s,
        fieldViewBuilder: (ctx, controller, focusNode, onSubmitted) =>
            TextFormField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              style: txt,
              decoration: _dec('Item Name *'),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Item name is required'
                  : null,
            ),
        optionsViewBuilder: (ctx, onSelected, options) {
          final list = options.toList();
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 6,
              color: Colors.white,
              surfaceTintColor: Colors.white,
              borderRadius: BorderRadius.circular(10),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: 240, maxWidth: constraints.maxWidth),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: list.length,
                  itemBuilder: (_, i) => InkWell(
                    onTap: () => onSelected(list[i]),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      child: Text(list[i],
                          style: const TextStyle(
                              color: Color(0xFF1A1A2E), fontSize: 14.5)),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _price.dispose();
    _qty.dispose();
    _desc.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  String _autoCode() {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    return 'PRD-${ts.substring(ts.length - 6)}';
  }

  static String _fmtDate(DateTime d) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${m[d.month - 1]} ${d.year}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _openingDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) setState(() => _openingDate = picked);
  }

  /// Returns true when the item was saved.
  Future<bool> _saveOne() async {
    if (!(_formKey.currentState?.validate() ?? false)) return false;

    setState(() => _saving = true);
    try {
      final user = await CurrentUserService.getName();
      final qty = int.tryParse(_qty.text.trim()) ?? 1;
      final name = _name.text.trim();
      final code = _code.text.trim().isEmpty ? _autoCode() : _code.text.trim();

      final product = NewProduct(
        productId: '',
        productName: name,
        productCode: code,
        category: _category,
        description: _desc.text.trim(),
        vendorName: '',
        purchaseDate: _openingDate,
        quantity: qty,
        unit: 'Pcs',
        salePrice: double.tryParse(_price.text.trim()) ?? 0,
        gstRate: NewProductGst.presetFromDropdownLabel(_gstChoice) ?? 0,
        availableQuantityForSale: qty,
        branch: _branch,
        status: qty <= 0
            ? NewProductService.stockOutOfStock
            : NewProductService.stockIn,
        listedOnWebsite: _listedOnWebsite,
        addedBy: user,
      );

      await NewProductService.addNewProduct(product);

      if (!mounted) return true;
      setState(() {
        _savedCount++;
        _lastSaved = name;
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ));
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    if (await _saveOne() && mounted) Navigator.pop(context, true);
  }

  Future<void> _saveAndAddAnother() async {
    if (!await _saveOne() || !mounted) return;
    _name.clear();
    _code.clear();
    _price.clear();
    _desc.clear();
    _qty.text = '1';
    _formKey.currentState?.reset();
    _nameFocus.requestFocus();
  }

  void _close() => Navigator.pop(context, _savedCount > 0 ? true : null);

  String? _vNum(String? v) {
    if (v == null || v.trim().isEmpty) return null; // price is optional
    final n = double.tryParse(v.trim());
    if (n == null || n < 0) return 'Invalid price';
    return null;
  }

  String? _vQty(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final n = int.tryParse(v.trim());
    if (n == null || n < 0) return 'Invalid';
    return null;
  }

  InputDecoration _dec(String label, {String? prefix, Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        prefixText: prefix,
        suffixIcon: suffix,
        labelStyle: TextStyle(color: Colors.grey.shade600),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _blue, width: 1.5)),
      );

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    // Safety: never pass a value that is not in the list.
    final list = items.contains(value) ? items : [value, ...items];
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      dropdownColor: Colors.white,
      style: const TextStyle(color: Colors.black87, fontSize: 14),
      decoration: _dec(label),
      items: [
        for (final i in list)
          DropdownMenuItem(
            value: i,
            child: Text(i,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, color: Colors.black87)),
          ),
      ],
      onChanged: onChanged,
    );
  }

  Widget _groupChip(String label, bool websiteValue) {
    final sel = _listedOnWebsite == websiteValue;
    return ChoiceChip(
      label: Text(label,
          style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: sel ? Colors.white : Colors.black87)),
      selected: sel,
      selectedColor: _blue,
      backgroundColor: Colors.white,
      showCheckmark: false,
      onSelected: (_) => setState(() => _listedOnWebsite = websiteValue),
    );
  }

  Widget _row(Widget a, Widget b) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: a),
      const SizedBox(width: 12),
      Expanded(child: b),
    ],
  );

  @override
  Widget build(BuildContext context) {
    const txt = TextStyle(color: Colors.black87, fontSize: 15);

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: AbsorbPointer(
          absorbing: _saving,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt_rounded, color: _blue),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Quick Add Item',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: _navy)),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: _saving ? null : _close,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Quick entry. Use Add Product when you need full details.',
                      style: TextStyle(
                          fontSize: 12.5, color: Colors.grey.shade600)),
                  const SizedBox(height: 14),

                  // Item Name
                  _nameField(txt),
                  const SizedBox(height: 12),

                  // Item Code | Category
                  _row(
                    TextFormField(
                      controller: _code,
                      textInputAction: TextInputAction.next,
                      style: txt,
                      decoration: _dec(
                        'Item Code (auto if empty)',
                        suffix: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: const Size(0, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () =>
                                setState(() => _code.text = _autoCode()),
                            child: const Text('Assign',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ),
                    _dropdown(
                      label: 'Category',
                      value: _category,
                      items: NewProductOptions.categories,
                      onChanged: (v) => setState(() => _category = v!),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Sale Price | GST
                  _row(
                    TextFormField(
                      controller: _price,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      textInputAction: TextInputAction.next,
                      style: txt,
                      decoration: _dec('Sale Price', prefix: '\u20B9 '),
                      validator: _vNum,
                    ),
                    _dropdown(
                      label: 'GST',
                      value: _gstChoice,
                      items: [
                        for (final l in NewProductGst.dropdownLabels)
                          if (l != NewProductGst.customLabel) l,
                      ],
                      onChanged: (v) => setState(() => _gstChoice = v!),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Opening Stock | Opening Date
                  _row(
                    TextFormField(
                      controller: _qty,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      style: txt,
                      decoration: _dec('Opening Stock *'),
                      validator: _vQty,
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: _dec(
                          'Opening Date',
                          suffix: const Icon(Icons.calendar_today_rounded,
                              size: 18, color: Colors.grey),
                        ),
                        child: Text(_fmtDate(_openingDate), style: txt),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Branch
                  _dropdown(
                    label: 'Branch',
                    value: _branch,
                    items: NewProductOptions.branches,
                    onChanged: (v) => setState(() => _branch = v!),
                  ),
                  const SizedBox(height: 12),

                  // Description
                  TextFormField(
                    controller: _desc,
                    minLines: 2,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    style: txt,
                    decoration: _dec('Description (optional)'),
                  ),
                  const SizedBox(height: 12),

                  // Group
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _groupChip('Product Availability Branches', false),
                      _groupChip('List of Products in Website', true),
                    ],
                  ),

                  if (_lastSaved != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_rounded,
                              size: 18, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Saved "$_lastSaved"  ($_savedCount added)',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: _saving ? null : _close,
                        child: Text(_savedCount > 0 ? 'Done' : 'Cancel'),
                      ),
                      OutlinedButton(
                        onPressed: _saving ? null : _saveAndAddAnother,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _blue,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Save & Add Another'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_rounded, size: 18),
                        label: Text(_saving ? 'Saving…' : 'Save'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
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