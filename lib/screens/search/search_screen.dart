// lib/screens/search_screen.dart

import 'package:flutter/material.dart';
import 'package:cda_inventory/models/product.dart';
import 'package:cda_inventory/services/product_service.dart';
import 'package:cda_inventory/services/seed_guard_service.dart';
import 'package:cda_inventory/data/seed_search_products.dart';
import 'package:cda_inventory/data/seed_adambakkam_products.dart';

// ─────────────────────────────────────────────
//  CATEGORIES
// ─────────────────────────────────────────────
const List<String> kCategories = [
  'All',
  'On Field',
  'RPTO',
  'Stationary',
  'Electronics & Electrical',
  'Manager Room',
  'Housekeeping Supplies',
  'Instructor Room',
  'Lab Room',
  'Tool Kits',
  'Charging Station',
  'Navin Kit',
  'FPV Drones',
  'Remote Controller',
  'Additional Drone Spare',
  '3D Printer',
  'Corridor Things',
  'Rest Room Things',
  'Service & Delivery In',
  'Gojan In Products',
];

const Map<String, IconData> kCategoryIcons = {
  'On Field': Icons.landscape_rounded,
  'RPTO': Icons.flight_takeoff_rounded,
  'Stationary': Icons.edit_rounded,
  'Electronics & Electrical': Icons.electric_bolt_rounded,
  'Manager Room': Icons.meeting_room_rounded,
  'Housekeeping Supplies': Icons.cleaning_services_rounded,
  'Instructor Room': Icons.school_rounded,
  'Lab Room': Icons.science_rounded,
  'Tool Kits': Icons.build_rounded,
  'Charging Station': Icons.battery_charging_full_rounded,
  'Navin Kit': Icons.cases_rounded,
  'FPV Drones': Icons.videocam_rounded,
  'Remote Controller': Icons.settings_remote_rounded,
  'Additional Drone Spare': Icons.handyman_rounded,
  '3D Printer': Icons.print_rounded,
  'Corridor Things': Icons.door_sliding_rounded,
  'Rest Room Things': Icons.bathroom_rounded,
  'Service & Delivery In': Icons.local_shipping_rounded,
  'Gojan In Products': Icons.inventory_rounded,
};

const Map<String, Color> kCategoryColors = {
  'On Field': Color(0xFF059669),
  'RPTO': Color(0xFF2563EB),
  'Stationary': Color(0xFF7C3AED),
  'Electronics & Electrical': Color(0xFFD97706),
  'Manager Room': Color(0xFF0E7490),
  'Housekeeping Supplies': Color(0xFF65A30D),
  'Instructor Room': Color(0xFF9333EA),
  'Lab Room': Color(0xFF0891B2),
  'Tool Kits': Color(0xFF92400E),
  'Charging Station': Color(0xFFDC2626),
  'Navin Kit': Color(0xFF0F766E),
  'FPV Drones': Color(0xFF7C3AED),
  'Remote Controller': Color(0xFF1D4ED8),
  'Additional Drone Spare': Color(0xFF374151),
  '3D Printer': Color(0xFF6D28D9),
  'Corridor Things': Color(0xFF047857),
  'Rest Room Things': Color(0xFF0369A1),
  'Service & Delivery In': Color(0xFFB45309),
  'Gojan In Products': Color(0xFF4338CA),
};

// ─────────────────────────────────────────────
//  SCREEN
// ─────────────────────────────────────────────
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const Color _darkNavy = Color(0xFF0A1628);
  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _lightBg = Color(0xFFF0F4F8);

  // ── Firestore: single one-shot read, reused for the auto-seed check
  //    (was: a live watchProducts() listener + a duplicate full-collection
  //    get() for the auto-seed check — 2x full reads on every screen open) ──
  List<Product> _allItems = [];
  bool _isLoading = true;
  String? _streamError;

  // ── Seeding state ─────────────────────────────────────────────────────────
  bool _isSeeding = false;

  // ── Local filter state ─────────────────────────────────────────────────────
  String _search = '';
  String _selectedCategory = 'All';
  final TextEditingController _searchCtrl = TextEditingController();

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadProductsOnce();
  }

  // ── Single one-shot read. Called from initState, pull-to-refresh, and
  //    after any add/edit/delete/seed — never on every keystroke. ──────────
  Future<void> _loadProductsOnce() async {
    setState(() {
      _isLoading = true;
      _streamError = null;
    });
    try {
      final items = await ProductService.getProducts();
      if (!mounted) return;
      setState(() {
        _allItems = items;
        _isLoading = false;
      });
      // Reuse the list we just read instead of a second full-collection
      // read just to check "is it empty".
      if (items.isEmpty) {
        // Guard: only ever auto-seed 'products' ONE time, ever — not
        // once per empty-check. Without this, deleting all products to
        // test the empty-state UI and reopening this screen would
        // silently rewrite ~1,600 documents on every single visit.
        final alreadySeeded = await SeedGuardService.hasSeeded('products');
        if (!alreadySeeded) {
          await ProductService.seedProducts(SeedSearchProducts.allItems);
          await ProductService.seedProducts(SeedAdambakkamProducts.allItems);
          await SeedGuardService.markSeeded('products');
          if (mounted) await _loadProductsOnce();
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _streamError = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Derived filtered list ─────────────────────────────────────────────────
  List<Product> get _filtered {
    return _allItems.where((item) {
      final matchesSearch =
      item.name.toLowerCase().contains(_search.toLowerCase());
      final matchesCategory =
          _selectedCategory == 'All' || item.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  Color _catColor(String cat) => kCategoryColors[cat] ?? _accentBlue;
  IconData _catIcon(String cat) =>
      kCategoryIcons[cat] ?? Icons.inventory_rounded;

  // ── SEED ALL PRODUCTS ────────────────────────────────────────────────────
  Future<void> _seedAllProducts() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cloud_upload_rounded, color: _accentBlue),
            SizedBox(width: 8),
            Text("Seed All Products"),
          ],
        ),
        content: Text(
          'This will add all ${SeedSearchProducts.allItems.length} pre-defined '
              'products to Firestore.\n\nThis is typically a one-time setup action. '
              'Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton.icon(
            style:
            ElevatedButton.styleFrom(backgroundColor: _accentBlue),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.upload_rounded,
                color: Colors.white, size: 16),
            label: const Text("Seed Now",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSeeding = true);

    try {
      final result =
      await ProductService.seedProducts(SeedSearchProducts.allItems);
      await SeedGuardService.markSeeded('products');
      if (!mounted) return;
      _showSnack(
        "Seeded: ${result['success']} added, ${result['failed']} skipped",
        Colors.green.shade700,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack("Seeding failed: $e", Colors.red.shade700);
    }

    if (mounted) setState(() => _isSeeding = false);
    await _loadProductsOnce(); // one fresh read after the write
  }

  // ── SEED ADAMBAKKAM (Branch 1) PRODUCTS ─────────────────────────────────
  Future<void> _seedAdambakkamProducts() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cloud_upload_rounded, color: _accentBlue),
            SizedBox(width: 8),
            Text("Seed Adambakkam Products"),
          ],
        ),
        content: Text(
          'This will add all ${SeedAdambakkamProducts.allItems.length} products '
              'from the Adambakkam (Branch 1) inventory spreadsheet to Firestore.\n\n'
              'This is safe to run once — it will not touch or duplicate any '
              'existing products. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton.icon(
            style:
            ElevatedButton.styleFrom(backgroundColor: _accentBlue),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.upload_rounded,
                color: Colors.white, size: 16),
            label: const Text("Seed Now",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSeeding = true);

    try {
      final result = await ProductService.seedProducts(
          SeedAdambakkamProducts.allItems);
      await SeedGuardService.markSeeded('products');
      if (!mounted) return;
      _showSnack(
        "Adambakkam seeded: ${result['success']} added, ${result['failed']} skipped",
        Colors.green.shade700,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack("Seeding failed: $e", Colors.red.shade700);
    }

    if (mounted) setState(() => _isSeeding = false);
    await _loadProductsOnce(); // one fresh read after the write
  }

  // ── ADD ───────────────────────────────────────────────────────────────────
  void _showAddDialog() => _showItemDialog(null);

  // ── EDIT ──────────────────────────────────────────────────────────────────
  void _showEditDialog(Product item) => _showItemDialog(item);

  // ── DELETE ────────────────────────────────────────────────────────────────
  void _deleteItem(Product item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Item',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(
                color: Color(0xFF374151), fontSize: 14, height: 1.5),
            children: [
              const TextSpan(text: 'Are you sure you want to remove '),
              TextSpan(
                text: item.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' from inventory?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                // id is now a String Firestore doc ID
                await ProductService.deleteProduct(item.id);
                await _loadProductsOnce(); // one fresh read after the write
                _showSnack('${item.name} removed', Colors.red.shade600);
              } catch (e) {
                _showSnack('Delete failed: $e', Colors.red.shade700);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── ADD / EDIT BOTTOM SHEET ───────────────────────────────────────────────
  void _showItemDialog(Product? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final qtyCtrl = TextEditingController(
        text: existing?.quantity.toString() ?? '1');

    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    // Guard against legacy/unknown category strings stored in Firestore
    // (e.g. old seed data saved "TOOLS" before the list was renamed to
    // "Tool Kits"). If the stored value isn't one of the current
    // kCategories, DropdownButtonFormField's `value` won't match any
    // `item`, which throws an assertion instead of just showing the field
    // — so fall back to a valid default in that case.
    String selectedCat = (existing != null && kCategories.contains(existing.category))
        ? existing.category
        : kCategories[1];
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      existing == null ? 'Add New Item' : 'Edit Item',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 20),

                    // Name
                    _label('Item Name *'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: nameCtrl,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                      decoration: _inputDec('e.g. DJI Mini 4 Pro'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name is required'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Category
                    _label('Category *'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedCat,
                      decoration: _inputDec(null),
                      isExpanded: true,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                      items: kCategories
                          .where((c) => c != 'All')
                          .map((c) => DropdownMenuItem(
                        value: c,
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _catColor(c),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(c,
                                style: const TextStyle(
                                    fontSize: 14, color: Color(0xFF0F172A))),
                          ],
                        ),
                      ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setModalState(() => selectedCat = v);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Quantity
                    _label('Quantity *'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: qtyCtrl,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                      decoration: _inputDec('e.g. 10'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Quantity is required';
                        }
                        final n = int.tryParse(v.trim());
                        if (n == null || n < 0) {
                          return 'Enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Notes
                    _label('Notes (optional)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: notesCtrl,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                      decoration: _inputDec('Any additional info'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(12)),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _darkNavy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) {
                                return;
                              }

                              final data = {
                                'name': nameCtrl.text.trim(),
                                'category': selectedCat,
                                'quantity':
                                int.parse(qtyCtrl.text.trim()),

                                'notes': notesCtrl.text.trim().isEmpty
                                    ? null
                                    : notesCtrl.text.trim(),
                              };

                              Navigator.pop(ctx);

                              try {
                                if (existing == null) {
                                  // ADD — Firestore assigns String id
                                  await ProductService.addProduct(data);
                                  _showSnack(
                                      '${data['name']} added',
                                      _accentBlue);
                                } else {
                                  // UPDATE — pass existing String doc id
                                  await ProductService.updateProduct(
                                      existing.id, data);
                                  _showSnack(
                                      '${data['name']} updated',
                                      _accentBlue);
                                }
                                // Stream auto-refreshes the list
                                await _loadProductsOnce(); // one fresh read after the write
                              } catch (e) {
                                _showSnack(
                                    'Error: $e', Colors.red.shade700);
                              }
                            },
                            child: Text(existing == null
                                ? 'Add Item'
                                : 'Save Changes'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: Color(0xFF374151)),
  );

  InputDecoration _inputDec(String? hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _accentBlue, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.red),
    ),
  );

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _lightBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_streamError != null) {
      return Scaffold(
        backgroundColor: _lightBg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded,
                  size: 56, color: Colors.red.shade300),
              const SizedBox(height: 16),
              const Text("Firestore connection error",
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              Text(_streamError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF94A3B8))),
            ],
          ),
        ),
      );
    }

    final filtered = _filtered;

    return Scaffold(
      backgroundColor: _lightBg,
      appBar: AppBar(
        backgroundColor: _darkNavy,
        foregroundColor: Colors.white,
        title: const Text(
          'Search Products',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          // ── Seed button — always visible, also acts as a one-time
          //    "load all spreadsheet items" action ────────────────────────
          IconButton(
            icon: _isSeeding
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
                : const Icon(Icons.cloud_upload_rounded),
            tooltip: 'Seed All Products',
            onPressed: _isSeeding ? null : _seedAllProducts,
          ),
          IconButton(
            icon: const Icon(Icons.location_city_rounded),
            tooltip: 'Seed Adambakkam (Branch 1) Products',
            onPressed: _isSeeding ? null : _seedAdambakkamProducts,
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Add Item',
            onPressed: _showAddDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: _darkNavy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Item',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          // ── Search + Category Bar ────────────────────────────────────────
          Container(
            color: _darkNavy,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search any product...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Colors.white70),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white70),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _search = '');
                      },
                    )
                        : null,
                    filled: true,
                    fillColor: Colors.white12,
                    contentPadding:
                    const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Category chips
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: kCategories.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final cat = kCategories[i];
                      final selected = _selectedCategory == cat;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.white
                                : Colors.white12,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? Colors.white
                                  : Colors.white24,
                            ),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              color: selected
                                  ? _darkNavy
                                  : Colors.white,
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── Results summary ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(
                  '${filtered.length} item${filtered.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                      fontSize: 14),
                ),
                if (_selectedCategory != 'All') ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _catColor(_selectedCategory)
                          .withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _selectedCategory,
                      style: TextStyle(
                          color: _catColor(_selectedCategory),
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  'Total: ${_allItems.length}',
                  style: const TextStyle(
                      color: Color(0xFF64748B), fontSize: 12),
                ),
              ],
            ),
          ),

          // ── Product list ─────────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? _emptyState()
                : ListView.separated(
              padding:
              const EdgeInsets.fromLTRB(16, 4, 16, 100),
              itemCount: filtered.length,
              separatorBuilder: (_, __) =>
              const SizedBox(height: 8),
              itemBuilder: (_, i) => _itemCard(filtered[i]),
            ),
          ),
        ],
      ),
    );
  }

  // ── ITEM CARD ─────────────────────────────────────────────────────────────
  Widget _itemCard(Product item) {
    final color = _catColor(item.category);
    final icon = _catIcon(item.category);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left color accent
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 3),
                    // Category badge only — price badge removed.
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.category,
                        style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (item.notes != null &&
                        item.notes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.notes!,
                        style: const TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Qty badge + action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: item.isOutOfStock
                          ? Colors.red.shade50
                          : item.isLowStock
                          ? Colors.orange.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: item.isOutOfStock
                            ? Colors.red.shade200
                            : item.isLowStock
                            ? Colors.orange.shade200
                            : Colors.green.shade200,
                      ),
                    ),
                    child: Text(
                      item.quantity.toString(),
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: item.isOutOfStock
                              ? Colors.red.shade700
                              : item.isLowStock
                              ? Colors.orange.shade700
                              : Colors.green.shade700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _showEditDialog(item),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _accentBlue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(Icons.edit_rounded,
                              color: _accentBlue, size: 16),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _deleteItem(item),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Icon(Icons.delete_outline_rounded,
                              color: Colors.red.shade600, size: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _search.isNotEmpty
                ? 'No results for "$_search"'
                : 'No items in this category',
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
                fontSize: 15),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try a different search or category,\nor add a new item.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: _showAddDialog,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Item'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _darkNavy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              if (_allItems.isEmpty) ...[
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _isSeeding ? null : _seedAllProducts,
                  icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                  label: const Text('Seed All'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _accentBlue,
                    side: const BorderSide(color: _accentBlue),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
