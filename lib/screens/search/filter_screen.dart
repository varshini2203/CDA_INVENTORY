// lib/screens/filter_screen.dart

import 'package:flutter/material.dart';
import 'package:cda_inventory/models/product.dart';
import 'package:cda_inventory/services/product_service.dart';

class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  // ── Filter state ──────────────────────────────────────────────────────────
  String selectedCategory = "All";
  String selectedBranch = "All";

  // ── Data state ────────────────────────────────────────────────────────────
  List<Product> _allProducts = [];
  List<Product> _filtered = [];
  bool _isLoading = true;
  String? _error;

  // ── Options ───────────────────────────────────────────────────────────────
  final List<String> categories = [
    "All",
    "RPTO",
    "R&D",
    "On Field",
    "Fixed Assets",
    "Consumables",
  ];

  final List<String> branches = [
    "All",
    "Branch 1",
    "Branch 2",
  ];

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  // ── Firestore fetch ───────────────────────────────────────────────────────
  // forceRefresh: false on initState (reuse the shared ProductService cache
  // if another screen already warmed it up this session). The Refresh
  // button below always passes true, so it never shows stale data.
  Future<void> _loadProducts({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final products =
      await ProductService.getProducts(forceRefresh: forceRefresh);
      setState(() {
        _allProducts = products;
        _filtered = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // ── Apply filters locally after fetch ────────────────────────────────────
  void _applyFilters() {
    setState(() {
      _filtered = _allProducts.where((p) {
        final matchCategory =
            selectedCategory == "All" || p.category == selectedCategory;
        // Branch is not stored in the Product model yet;
        // wire it up once you add a 'branch' field to Firestore.
        // For now, branch filter is a UI-only placeholder.
        return matchCategory;
      }).toList();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Filter Applied: $selectedCategory / $selectedBranch"
              " — ${_filtered.length} result${_filtered.length == 1 ? '' : 's'}",
        ),
        backgroundColor: Colors.blue.shade900,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Filter Products"),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        actions: [
          // Manual refresh
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => _loadProducts(forceRefresh: true),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : _buildBody(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 56, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text("Failed to load products",
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.grey.shade800)),
            const SizedBox(height: 8),
            Text(_error!,
                textAlign: TextAlign.center,
                style:
                TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadProducts,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Retry"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade900,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Result count badge ───────────────────────────────────────────
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 16, color: Colors.blue.shade900),
                const SizedBox(width: 8),
                Text(
                  "${_filtered.length} of ${_allProducts.length} products",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade900,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── CATEGORY FILTER ──────────────────────────────────────────────
          _filterCard(
            label: "Category",
            child: Wrap(
              spacing: 10,
              runSpacing: 6,
              children: categories.map((cat) {
                final isSelected = selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: Colors.blue.shade900,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                  onSelected: (_) => setState(() => selectedCategory = cat),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // ── BRANCH FILTER ────────────────────────────────────────────────
          _filterCard(
            label: "Branch",
            child: Wrap(
              spacing: 10,
              runSpacing: 6,
              children: branches.map((branch) {
                final isSelected = selectedBranch == branch;
                return ChoiceChip(
                  label: Text(branch),
                  selected: isSelected,
                  selectedColor: Colors.blue.shade900,
                  labelStyle: TextStyle(
                    color:
                    isSelected ? Colors.white : Colors.grey.shade700,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                  onSelected: (_) =>
                      setState(() => selectedBranch = branch),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 25),

          // ── APPLY BUTTON ─────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade900,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.filter_list_rounded),
              label: const Text("Apply Filter",
                  style: TextStyle(fontSize: 16)),
              onPressed: _applyFilters,
            ),
          ),

          const SizedBox(height: 16),

          // ── RESET BUTTON ─────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue.shade900,
                side: BorderSide(color: Colors.blue.shade900),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.clear_rounded),
              label: const Text("Reset Filters"),
              onPressed: () {
                setState(() {
                  selectedCategory = "All";
                  selectedBranch = "All";
                  _filtered = _allProducts;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterCard({required String label, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}