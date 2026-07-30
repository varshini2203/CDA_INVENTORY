// lib/screens/inventory/bulk_operations_screen.dart
//
// Bulk Operations module for CDA Inventory — multi-select over the same
// `InventoryItem` list the main Inventory Dashboard already shows, wired
// to `InventoryBulkOperationsService` for every write, and to the
// existing `BulkImportScreen(target: BulkImportTarget.inventory)` for
// import (already ships preview / validation / duplicate detection — see
// that screen + BulkImportPreviewScreen, reused here unmodified).
//
// Reuses, unmodified:
//   * models/inventory_model.dart       (InventoryItem)
//   * services/inventory_service.dart   (InventoryService — list + cache)
//   * services/activity_log_service.dart (via InventoryBulkOperationsService)
//   * screens/bulk_import/bulk_import_screen.dart (Bulk Import entry point)
//   * core/access/access_scope.dart     (CurrentAccess / EditGuard)
//
// New, additive only:
//   * services/inventory_bulk_operations_service.dart
//   * services/csv_export_service.dart (+ io/web platform helpers)
//   * screens/inventory/widgets/bulk_action_dialogs.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:cda_inventory/models/inventory_model.dart';
import 'package:cda_inventory/services/inventory_service.dart';
import 'package:cda_inventory/services/inventory_bulk_operations_service.dart';
import 'package:cda_inventory/core/access/access_scope.dart';
import 'package:cda_inventory/screens/bulk_import/bulk_import_screen.dart';

import 'widgets/bulk_action_dialogs.dart';

class BulkOperationsScreen extends StatefulWidget {
  const BulkOperationsScreen({super.key});

  @override
  State<BulkOperationsScreen> createState() => _BulkOperationsScreenState();
}

class _BulkOperationsScreenState extends State<BulkOperationsScreen> {
  // ── Design tokens (matches Inventory Dashboard's dark premium theme) ────
  static const Color _navy = Color(0xFF0A1628);
  static const Color _teal = Color(0xFF00D4AA);
  static const Color _coral = Color(0xFFFF6B6B);
  static const Color _amber = Color(0xFFFFB800);
  static const Color _surface = Color(0xFFF0F4F8);
  static const Color _purple = Color(0xFF6C63FF);

  static const List<String> _categories = [
    'ONFIELD',
    'RPTO',
    'STATIONARY',
    'ELECTRICAL',
    'TOOL KITS',
    'LAB ROOM',
    'CHARGING STATION',
    'NAVIN KIT',
    'FPV DRONES',
    'REMOTE CONTROLLER',
    'ADDITIONAL DRONE SPARE',
    '3D PRINTER',
    'HOUSEKEEPING SUPPLIES',
    'MANAGER ROOM',
    'INSTRUCTOR ROOM',
    'CORRIDOR THINGS',
    'REST ROOM THING',
  ];

  static const Map<String, Color> _categoryColors = {
    'ONFIELD': Color(0xFF2E7D32),
    'RPTO': Color(0xFF6A1B9A),
    'STATIONARY': Color(0xFFE65100),
    'ELECTRICAL': Color(0xFFF9A825),
    'TOOL KITS': Color(0xFF37474F),
    'LAB ROOM': Color(0xFF00838F),
    'CHARGING STATION': Color(0xFF558B2F),
    'NAVIN KIT': Color(0xFF4527A0),
    'FPV DRONES': Color(0xFFC62828),
    'REMOTE CONTROLLER': Color(0xFF00695C),
    'ADDITIONAL DRONE SPARE': Color(0xFF4E342E),
    '3D PRINTER': Color(0xFF1565C0),
    'HOUSEKEEPING SUPPLIES': Color(0xFF00838F),
    'MANAGER ROOM': Color(0xFF283593),
    'INSTRUCTOR ROOM': Color(0xFF1B5E20),
    'CORRIDOR THINGS': Color(0xFF4A148C),
    'REST ROOM THING': Color(0xFF880E4F),
  };

  Color _categoryColor(String category) =>
      _categoryColors[category.toUpperCase()] ?? _navy;

  List<InventoryItem> _allItems = [];
  List<InventoryItem> _filtered = [];
  final Set<String> _selectedIds = {};

  bool _loading = true;
  String? _loadError;
  bool _busy = false;

  String _search = '';
  String _categoryFilter = 'ALL';
  int _branchFilter = 0; // 0 = all
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool forceRefresh = true}) async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final items = await InventoryService().getInventory(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _allItems = items;
        _selectedIds.removeWhere((id) => !items.any((i) => i.id == id));
        _applyFilters();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '$e';
      });
    }
  }

  void _applyFilters() {
    final query = _search.trim().toLowerCase();
    _filtered = _allItems.where((item) {
      final matchesCategory = _categoryFilter == 'ALL' || item.category == _categoryFilter;
      final matchesBranch = _branchFilter == 0 || item.branch == _branchFilter;
      final matchesSearch = query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.location.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query);
      return matchesCategory && matchesBranch && matchesSearch;
    }).toList();
  }

  // ── SELECTION HELPERS ────────────────────────────────────────────────
  bool get _hasSelection => _selectedIds.isNotEmpty;

  List<InventoryItem> get _selectedItems =>
      _allItems.where((i) => _selectedIds.contains(i.id)).toList();

  void _toggleOne(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAllVisible() {
    setState(() {
      _selectedIds.addAll(_filtered.map((i) => i.id));
    });
  }

  /// Selects every item in the entire Inventory collection — not just what
  /// the current filters/search show — using a server-truth doc-id read
  /// (`InventoryBulkOperationsService.getAllDocIds`) rather than trusting
  /// whatever happens to already be loaded client-side.
  Future<void> _selectAllInCollection() async {
    setState(() => _busy = true);
    try {
      final ids = await InventoryBulkOperationsService.getAllDocIds();
      if (!mounted) return;
      setState(() => _selectedIds.addAll(ids));
      _showSnack('Selected ${ids.length} item(s) across all of Inventory.');
    } catch (e) {
      _showSnack('Could not select all: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _deselectAll() {
    setState(() => _selectedIds.clear());
  }

  bool get _allVisibleSelected =>
      _filtered.isNotEmpty && _filtered.every((i) => _selectedIds.contains(i.id));

  String? get _performedBy {
    try {
      final access = context.read<CurrentAccess>().access;
      if (access == null) return null;
      return access.name.isNotEmpty ? access.name : access.email;
    } catch (_) {
      return null;
    }
  }

  bool get _canEdit {
    try {
      return context.read<CurrentAccess>().canEdit;
    } catch (_) {
      // If CurrentAccess isn't registered above this screen for some
      // reason, fail open rather than block the whole module — mirrors
      // how EditGuard degrades elsewhere in this app.
      return true;
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _coral : const Color(0xFF00B894),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  BULK ACTIONS
  // ═══════════════════════════════════════════════════════════════════
  Future<void> _runUpdatePrices() async {
    if (!_hasSelection || _busy) return;
    final spec = await showBulkPriceUpdateDialog(context, selectedCount: _selectedIds.length);
    if (spec == null || !mounted) return;

    final confirmed = await showBulkConfirmDialog(
      context,
      title: 'Update prices?',
      message: 'Apply "${spec.mode.label}" (${spec.value}) to ${_selectedIds.length} item(s)?',
      confirmLabel: 'Update',
      icon: Icons.currency_rupee_rounded,
    );
    if (!confirmed || !mounted) return;

    final performedBy = _performedBy; // captured before any await gap
    setState(() => _busy = true);
    final selected = _selectedItems;
    final progress = showBulkProgressDialog(context, title: 'Updating prices…');
    try {
      final prices = await InventoryBulkOperationsService.fetchPrices(
        selected.map((i) => i.id).toList(),
      );
      final result = await InventoryBulkOperationsService.bulkUpdatePrices(
        items: selected,
        mode: spec.mode,
        value: spec.value,
        currentPrices: prices,
        performedBy: performedBy,
        onProgress: (done, total) => progress.update(done, total),
      );
      progress.close();
      if (!mounted) return;
      await showBulkResultDialog(context, title: 'Price update complete', result: result);
      _deselectAll();
      await _load();
    } catch (e) {
      progress.close();
      _showSnack('Price update failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runChangeCategory() async {
    if (!_hasSelection || _busy) return;
    final newCategory = await showBulkCategoryPickerDialog(
      context,
      categories: _categories,
      selectedCount: _selectedIds.length,
    );
    if (newCategory == null || !mounted) return;

    final performedBy = _performedBy; // captured before any await gap
    setState(() => _busy = true);
    final selected = _selectedItems;
    final progress = showBulkProgressDialog(context, title: 'Changing category…');
    try {
      final result = await InventoryBulkOperationsService.bulkChangeCategory(
        items: selected,
        newCategory: newCategory,
        performedBy: performedBy,
        onProgress: (done, total) => progress.update(done, total),
      );
      progress.close();
      if (!mounted) return;
      await showBulkResultDialog(context, title: 'Category change complete', result: result);
      _deselectAll();
      await _load();
    } catch (e) {
      progress.close();
      _showSnack('Category change failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runBranchTransfer() async {
    if (!_hasSelection || _busy) return;
    final newBranch =
    await showBulkBranchPickerDialog(context, selectedCount: _selectedIds.length);
    if (newBranch == null || !mounted) return;

    final performedBy = _performedBy; // captured before any await gap
    setState(() => _busy = true);
    final selected = _selectedItems;
    final progress = showBulkProgressDialog(context, title: 'Transferring branch…');
    try {
      final result = await InventoryBulkOperationsService.bulkTransferBranch(
        items: selected,
        newBranch: newBranch,
        performedBy: performedBy,
        onProgress: (done, total) => progress.update(done, total),
      );
      progress.close();
      if (!mounted) return;
      await showBulkResultDialog(context, title: 'Branch transfer complete', result: result);
      _deselectAll();
      await _load();
    } catch (e) {
      progress.close();
      _showSnack('Branch transfer failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runDelete() async {
    if (!_hasSelection || _busy) return;
    final confirmed = await showBulkConfirmDialog(
      context,
      title: 'Delete ${_selectedIds.length} item(s)?',
      message: 'This permanently removes the selected item(s) from Inventory. '
          'This action cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) return;

    final performedBy = _performedBy; // captured before any await gap
    setState(() => _busy = true);
    final selected = _selectedItems;
    final progress = showBulkProgressDialog(context, title: 'Deleting items…');
    try {
      final result = await InventoryBulkOperationsService.bulkDelete(
        items: selected,
        performedBy: performedBy,
        onProgress: (done, total) => progress.update(done, total),
      );
      progress.close();
      if (!mounted) return;
      await showBulkResultDialog(context, title: 'Delete complete', result: result);
      _deselectAll();
      await _load();
    } catch (e) {
      progress.close();
      _showSnack('Delete failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runExport() async {
    if (!_hasSelection || _busy) return;
    final format = await showBulkExportFormatSheet(context, selectedCount: _selectedIds.length);
    if (format == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await InventoryBulkOperationsService.exportItems(
        items: _selectedItems,
        format: format,
      );
      _showSnack('Export ready — ${_selectedIds.length} item(s).');
    } catch (e) {
      _showSnack('Export failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openImport() async {
    final imported = await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'Bulk Import Inventory'),
        builder: (_) => const BulkImportScreen(target: BulkImportTarget.inventory),
      ),
    );
    if (imported == true && mounted) {
      _showSnack('Import complete — refreshing list.');
      await _load();
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: _hasSelection ? _buildActionBar() : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _navy,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Text(
        _hasSelection ? '${_selectedIds.length} selected' : 'Bulk Operations',
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
      ),
      leading: _hasSelection
          ? IconButton(
        icon: const Icon(Icons.close_rounded),
        tooltip: 'Clear selection',
        onPressed: _deselectAll,
      )
          : null,
      actions: [
        PopupMenuButton<String>(
          icon: Icon(_hasSelection ? Icons.deselect_rounded : Icons.select_all_rounded),
          tooltip: 'Select',
          enabled: !_busy,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (value) {
            switch (value) {
              case 'visible':
                _selectAllVisible();
                break;
              case 'all':
                _selectAllInCollection();
                break;
              case 'none':
                _deselectAll();
                break;
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'visible',
              enabled: _filtered.isNotEmpty,
              child: Row(children: const [
                Icon(Icons.checklist_rounded, size: 18, color: _navy),
                SizedBox(width: 8),
                Text('Select all visible'),
              ]),
            ),
            const PopupMenuItem(
              value: 'all',
              child: Row(children: [
                Icon(Icons.select_all_rounded, size: 18, color: _navy),
                SizedBox(width: 8),
                Text('Select all in Inventory'),
              ]),
            ),
            PopupMenuItem(
              value: 'none',
              enabled: _hasSelection,
              child: Row(children: const [
                Icon(Icons.deselect_rounded, size: 18, color: _coral),
                SizedBox(width: 8),
                Text('Deselect all'),
              ]),
            ),
          ],
        ),
        if (_canEdit)
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: 'Bulk Import',
            onPressed: _busy ? null : _openImport,
          ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh',
          onPressed: _busy ? null : () => _load(),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: _navy,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by name, location or category…',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.55)),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear_rounded, color: Colors.white70),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _search = '';
                    _applyFilters();
                  });
                },
              )
                  : null,
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => setState(() {
              _search = v;
              _applyFilters();
            }),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _branchChip(0, 'All Branches'),
                _branchChip(1, 'CDA Admin'),
                _branchChip(2, 'CDA Ops'),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 1,
                  color: Colors.white24,
                ),
                _categoryChip('ALL'),
                ..._categories.map(_categoryChip),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _branchChip(int branch, String label) {
    final selected = _branchFilter == branch;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 12, color: selected ? _navy : Colors.white)),
        selected: selected,
        onSelected: (_) => setState(() {
          _branchFilter = branch;
          _applyFilters();
        }),
        selectedColor: _teal,
        backgroundColor: Colors.white.withOpacity(0.08),
        side: BorderSide.none,
      ),
    );
  }

  Widget _categoryChip(String category) {
    final selected = _categoryFilter == category;
    final color = category == 'ALL' ? _teal : _categoryColor(category);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(category, style: TextStyle(fontSize: 11.5, color: selected ? Colors.white : Colors.white70)),
        selected: selected,
        onSelected: (_) => setState(() {
          _categoryFilter = category;
          _applyFilters();
        }),
        selectedColor: color,
        backgroundColor: Colors.white.withOpacity(0.06),
        side: BorderSide.none,
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _teal));
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: _coral),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(_loadError!, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => _load(), child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _search.isNotEmpty ? 'No results for "$_search"' : 'No items match these filters',
              style: TextStyle(color: Colors.grey[500], fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _teal,
      onRefresh: () => _load(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        itemCount: _filtered.length,
        itemBuilder: (context, index) => _buildItemTile(_filtered[index]),
      ),
    );
  }

  Widget _buildItemTile(InventoryItem item) {
    final selected = _selectedIds.contains(item.id);
    final color = _categoryColor(item.category);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: selected ? _teal.withOpacity(0.08) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? _teal : Colors.grey.shade100),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _toggleOne(item.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                activeColor: _teal,
                onChanged: (_) => _toggleOne(item.id),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.inventory_2_rounded, color: color, size: 18),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: _navy),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.branchLabel} • ${item.location.isEmpty ? 'No location' : item.location}',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item.isOutOfStock
                      ? _coral.withOpacity(0.12)
                      : item.isLowStock
                      ? _amber.withOpacity(0.12)
                      : const Color(0xFF00B894).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Qty ${item.quantity}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: item.isOutOfStock
                        ? _coral
                        : item.isLowStock
                        ? _amber
                        : const Color(0xFF00B894),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, -3)),
          ],
        ),
        child: _busy
            ? const SizedBox(
          height: 44,
          child: Center(child: CircularProgressIndicator(color: _teal, strokeWidth: 2.4)),
        )
            : SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (_canEdit) ...[
                _actionButton(
                  icon: Icons.currency_rupee_rounded,
                  label: 'Prices',
                  color: _teal,
                  onTap: _runUpdatePrices,
                ),
                _actionButton(
                  icon: Icons.category_rounded,
                  label: 'Category',
                  color: _purple,
                  onTap: _runChangeCategory,
                ),
                _actionButton(
                  icon: Icons.compare_arrows_rounded,
                  label: 'Branch',
                  color: _amber,
                  onTap: _runBranchTransfer,
                ),
              ],
              _actionButton(
                icon: Icons.file_download_rounded,
                label: 'Export',
                color: _navy,
                onTap: _runExport,
              ),
              if (_canEdit)
                _actionButton(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
                  color: _coral,
                  onTap: _runDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            width: 84,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}