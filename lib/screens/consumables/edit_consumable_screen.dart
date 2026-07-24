import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';           // for FieldValue.serverTimestamp()
import 'package:intl/intl.dart';                                  // for date/time formatting
import 'package:cda_inventory/models/consumable.dart';         // ← absolute import
import 'package:cda_inventory/services/consumable_service.dart'; // ← absolute import

class EditConsumableScreen extends StatefulWidget {
  final Consumable item;

  const EditConsumableScreen({super.key, required this.item});

  @override
  State<EditConsumableScreen> createState() => _EditConsumableScreenState();
}

class _EditConsumableScreenState extends State<EditConsumableScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nameController;
  late TextEditingController quantityController;
  late TextEditingController minimumStockController;
  late TextEditingController descriptionController;
  late TextEditingController addedByController;   // Added By field controller

  late String selectedCategory;
  late String selectedBranch; // raw value: 'Branch 1' or 'Branch 2'
  bool _isSaving = false;

  static const Color kNavy    = Color(0xFF0A1628);
  static const Color kTeal    = Color(0xFF00D4AA);
  static const Color kCoral   = Color(0xFFFF6B6B);
  static const Color kAmber   = Color(0xFFFFB800);
  static const Color kSurface = Color(0xFFF0F4F8);
  static const Color kGreen   = Color(0xFF00B894);

  static const List<Map<String, dynamic>> categories = [
    {'label': 'Stationery',  'icon': Icons.edit_note,           'color': Color(0xFF4F8EF7)},
    {'label': 'Drone Parts', 'icon': Icons.flight,              'color': Color(0xFF7C3AED)},
    {'label': 'Electronics', 'icon': Icons.electrical_services, 'color': Color(0xFF059669)},
    {'label': 'Training',    'icon': Icons.school,              'color': Color(0xFFD97706)},
  ];

  // Raw Firestore value → display label (same mapping as Add screen /
  // ConsumableListScreen so everything stays consistent).
  static const List<Map<String, String>> branchOptions = [
    {'value': 'Branch 1', 'label': 'CDA Admin'},
    {'value': 'Branch 2', 'label': 'CDA Ops'},
  ];

  @override
  void initState() {
    super.initState();
    nameController         = TextEditingController(text: widget.item.name);
    quantityController     = TextEditingController(text: widget.item.quantity.toString());
    minimumStockController = TextEditingController(text: widget.item.minimumStock.toString());
    descriptionController  = TextEditingController(text: widget.item.description);
    addedByController       = TextEditingController(text: widget.item.addedBy ?? '');
    selectedCategory        = widget.item.category;
    selectedBranch           = _normalizeBranch(widget.item.branch);
  }

  // Existing items may have branch as '', a single value, a
  // comma-joined multi-value (e.g. "Branch 1, Branch 2"), or a legacy
  // free-text value scraped from description. The dropdown only supports
  // a single selection, so: take the first recognised branch value found,
  // and default to 'Branch 1' (CDA Admin) if nothing matches.
  String _normalizeBranch(String raw) {
    final parts = raw.split(',').map((e) => e.trim()).toList();
    for (final opt in branchOptions) {
      if (parts.contains(opt['value'])) return opt['value']!;
    }
    return branchOptions.first['value']!;
  }

  @override
  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    minimumStockController.dispose();
    descriptionController.dispose();
    addedByController.dispose();
    super.dispose();
  }

  Color get _selectedColor => categories.firstWhere(
        (c) => c['label'] == selectedCategory,
    orElse: () => categories[0],
  )['color'] as Color;

  IconData get _selectedIcon => categories.firstWhere(
        (c) => c['label'] == selectedCategory,
    orElse: () => categories[0],
  )['icon'] as IconData;

  bool get _hasChanges {
    return nameController.text.trim()     != widget.item.name         ||
        selectedCategory                   != widget.item.category     ||
        selectedBranch                     != _normalizeBranch(widget.item.branch) ||
        quantityController.text.trim()     != widget.item.quantity.toString() ||
        minimumStockController.text.trim() != widget.item.minimumStock.toString() ||
        descriptionController.text.trim()  != widget.item.description ||
        addedByController.text.trim()      != (widget.item.addedBy ?? '');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      await ConsumableService.updateConsumable(widget.item.id, {
        'name':         nameController.text.trim(),
        'category':     selectedCategory,
        'quantity':     int.parse(quantityController.text.trim()),
        'minimumStock': int.parse(minimumStockController.text.trim()),
        'description':  descriptionController.text.trim(),
        'branch':       selectedBranch,
        'addedBy':      addedByController.text.trim(),          // who made this change
        'updatedAt':    FieldValue.serverTimestamp(),            // correct server time, not device time
      });

      if (!mounted) return;
      _showSnack('Changes saved');
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to update: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: isError ? kCoral : kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes. Leave without saving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kCoral,
              foregroundColor: Colors.white,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: kSurface,
        appBar: AppBar(
          backgroundColor: kNavy,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
            onPressed: () async {
              if (await _onWillPop()) Navigator.pop(context);
            },
          ),
          title: const Text(
            'Edit Item',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero banner ──────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE6A817), kAmber],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.edit_document,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Edit Consumable',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Update item details below',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Live preview card ────────────────────────────────────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _selectedColor.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _selectedColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(_selectedIcon, color: _selectedColor, size: 30),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nameController.text.isEmpty
                                  ? widget.item.name
                                  : nameController.text,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: kNavy,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _selectedColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                selectedCategory,
                                style: TextStyle(
                                  color: _selectedColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: kAmber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Editing',
                          style: TextStyle(
                            color: kAmber,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Item Details ─────────────────────────────────────────────
                _sectionLabel('ITEM DETAILS'),
                const SizedBox(height: 10),
                _card(children: [
                  _buildField(
                    controller: nameController,
                    label: 'Item Name',
                    icon: Icons.label_outline,
                    onChanged: (_) => setState(() {}),
                    validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name is required' : null,
                  ),
                ]),

                const SizedBox(height: 20),

                // ── Category ─────────────────────────────────────────────────
                _sectionLabel('CATEGORY'),
                const SizedBox(height: 10),
                _card(children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.8,
                    children: categories.map((cat) {
                      final isSelected = selectedCategory == cat['label'];
                      final color = cat['color'] as Color;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => selectedCategory = cat['label']),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected ? color : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? color : Colors.grey.shade200,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                              BoxShadow(
                                color: color.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                cat['icon'] as IconData,
                                color: isSelected ? Colors.white : color,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                cat['label'] as String,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ]),

                const SizedBox(height: 20),

                // ── Branch ───────────────────────────────────────────────────
                _sectionLabel('BRANCH'),
                const SizedBox(height: 10),
                _card(children: [
                  _buildBranchDropdown(),
                ]),

                const SizedBox(height: 20),

                // ── Stock Information ─────────────────────────────────────────
                _sectionLabel('STOCK INFORMATION'),
                const SizedBox(height: 10),
                _card(children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildField(
                          controller: quantityController,
                          label: 'Quantity',
                          icon: Icons.inventory_2_outlined,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            if (int.tryParse(v) == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildField(
                          controller: minimumStockController,
                          label: 'Min. Alert',
                          icon: Icons.warning_amber_outlined,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            if (int.tryParse(v) == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ]),

                const SizedBox(height: 20),

                // ── Added By ─────────────────────────────────────────────────
                // Whoever edits the item types their name here; the date/time
                // row below it shows when the item was last saved.
                _sectionLabel('ADDED BY'),
                const SizedBox(height: 10),
                _card(children: [
                  _buildField(
                    controller: addedByController,
                    label: 'Your Name',
                    hint: 'Enter your name',
                    icon: Icons.person_outline,
                    onChanged: (_) => setState(() {}),
                    validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 12),
                  _buildDateTimeRow(),           // shows last-updated / created date & time
                ]),

                const SizedBox(height: 20),

                // ── Notes ────────────────────────────────────────────────────
                _sectionLabel('NOTES'),
                const SizedBox(height: 10),
                _card(children: [
                  _buildField(
                    controller: descriptionController,
                    label: 'Description (optional)',
                    hint: 'Add any notes about this item…',
                    icon: Icons.notes,
                    maxLines: 3,
                  ),
                ]),

                const SizedBox(height: 28),

                // ── Save button ───────────────────────────────────────────────
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _hasChanges ? 1.0 : 0.5,
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: (_isSaving || !_hasChanges) ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAmber,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade200,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                          : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Save Changes',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.grey.shade500,
        letterSpacing: 1.4,
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  // Branch dropdown — stores 'Branch 1'/'Branch 2' but displays
  // 'CDA Admin'/'CDA Ops'. dropdownColor + explicit text styles are set
  // so the popup and closed-field text don't inherit dark/invisible
  // styling from the app's root Theme (which is what caused the dark
  // navy-on-navy unreadable dropdown).
  Widget _buildBranchDropdown() {
    return DropdownButtonFormField<String>(
      value: selectedBranch,
      isExpanded: true,
      dropdownColor: Colors.white, // 🔧 force white popup background
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade400),
      style: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w500, color: kNavy),
      decoration: InputDecoration(
        labelText: 'Branch',
        labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        prefixIcon: Icon(Icons.business_rounded, size: 20, color: Colors.grey.shade400),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kAmber, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      items: branchOptions
          .map((b) => DropdownMenuItem<String>(
        value: b['value'],
        child: Text(
          b['label']!,
          style: const TextStyle(              // 🔧 explicit popup item text style
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: kNavy,
          ),
        ),
      ))
          .toList(),
      selectedItemBuilder: (context) => branchOptions // 🔧 explicit closed-field text style
          .map((b) => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          b['label']!,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: kNavy,
          ),
        ),
      ))
          .toList(),
      onChanged: (value) {
        if (value != null) setState(() => selectedBranch = value);
      },
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      validator: validator,
      style: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w500, color: kNavy),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        hintStyle: TextStyle(color: Colors.grey.shade300, fontSize: 14),
        prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade400),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kAmber, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kCoral),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kCoral, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  // Read-only row showing when this item was last saved.
  // Prefers updatedAt (most recent edit); falls back to createdAt for
  // items that have never been edited since creation.
  Widget _buildDateTimeRow() {
    final ts = widget.item.updatedAt ?? widget.item.createdAt;
    final label = widget.item.updatedAt != null ? 'Last updated' : 'Created';

    if (ts == null) {
      return Row(
        children: [
          Icon(Icons.access_time, size: 16, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          Text(
            'Not saved yet',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      );
    }

    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate());

    return Row(
      children: [
        Icon(Icons.access_time, size: 16, color: Colors.grey.shade400),
        const SizedBox(width: 8),
        Text(
          '$label: $dateStr',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}