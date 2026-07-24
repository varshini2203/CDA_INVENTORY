import 'package:flutter/material.dart';
import 'package:cda_inventory/models/stock.dart';
import 'package:cda_inventory/services/stock_service.dart';

class StockHistoryScreen extends StatefulWidget {
  const StockHistoryScreen({super.key});

  @override
  State<StockHistoryScreen> createState() => _StockHistoryScreenState();
}

class _StockHistoryScreenState extends State<StockHistoryScreen> {
  List<StockTransaction> _allHistory = [];
  List<StockTransaction> _filtered   = [];
  bool    _loading = true;
  String? _error;

  final _searchController = TextEditingController();

  String _filterType   = 'All';
  String _filterBranch = 'All';

  static const List<String> _typeOptions   = ['All', 'IN', 'OUT'];
  static const List<String> _branchOptions = ['All', 'CDA ADMIN', 'CDA OPS'];

  static const Color kNavy  = Color(0xFF0A1628);
  static const Color kTeal  = Color(0xFF00D4AA);
  static const Color kCoral = Color(0xFFFF6B6B);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyLocalFilter);
    _load();
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyLocalFilter);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await StockService.fetchHistory(
        branch: _filterBranch == 'All' ? null : _filterBranch,
        type:   _filterType   == 'All' ? null : _filterType,
        forceRefresh: forceRefresh,
      );
      setState(() {
        _allHistory = data;
        _loading    = false;
      });
      _applyLocalFilter();
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _applyLocalFilter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = _allHistory.where((t) {
        if (q.isEmpty) return true;
        return t.productName.toLowerCase().contains(q)
            || t.person.toLowerCase().contains(q)
            || t.branch.toLowerCase().contains(q)
            || t.departmentOrPurpose.toLowerCase().contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        title: const Text('Stock History',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _load(forceRefresh: true),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search + Filters ─────────────────────────────────────────
          Container(
            color: kNavy,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Column(children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  style:
                  const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search products, persons, branches…',
                    hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: Colors.white.withOpacity(0.6), size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                        icon: Icon(Icons.clear_rounded,
                            color: Colors.white.withOpacity(0.6),
                            size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _applyLocalFilter();
                        })
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _filterChipGroup(
                  options: _typeOptions,
                  selected: _filterType,
                  onSelect: (v) {
                    setState(() => _filterType = v);
                    _load();
                  },
                )),
                const SizedBox(width: 8),
                Expanded(child: _filterChipGroup(
                  options: _branchOptions,
                  selected: _filterBranch,
                  onSelect: (v) {
                    setState(() => _filterBranch = v);
                    _load();
                  },
                )),
              ]),
            ]),
          ),

          // ── Stats bar ─────────────────────────────────────────────────
          if (!_loading && _error == null) _buildStatsBar(),

          // ── List ──────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                child: CircularProgressIndicator(color: kTeal))
                : _error != null
                ? _buildError()
                : _filtered.isEmpty
                ? _buildEmpty()
                : RefreshIndicator(
              onRefresh: () => _load(forceRefresh: true),
              color: kTeal,
              child: ListView.builder(
                padding:
                const EdgeInsets.fromLTRB(12, 8, 12, 12),
                itemCount: _filtered.length,
                itemBuilder: (_, i) =>
                    _buildCard(_filtered[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChipGroup({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((o) {
          final isSelected = o == selected;
          Color chipColor = kTeal;
          if (o == 'IN') chipColor = const Color(0xFF00B894);
          if (o == 'OUT') chipColor = kCoral;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onSelect(o),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? chipColor
                      : Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(o,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
                    )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatsBar() {
    final inCount  = _filtered.where((t) => t.type == 'IN').length;
    final outCount = _filtered.where((t) => t.type == 'OUT').length;
    final inQty    = _filtered
        .where((t) => t.type == 'IN')
        .fold<int>(0, (s, t) => s + t.quantity);
    final outQty   = _filtered
        .where((t) => t.type == 'OUT')
        .fold<int>(0, (s, t) => s + t.quantity);

    return Container(
      color: Colors.white,
      padding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        _statPill('${_filtered.length} Records',
            Colors.grey.shade600, Colors.grey.shade100),
        const SizedBox(width: 8),
        _statPill('IN $inCount (qty: $inQty)',
            const Color(0xFF00B894),
            const Color(0xFF00B894).withOpacity(0.1)),
        const SizedBox(width: 8),
        _statPill('OUT $outCount (qty: $outQty)', kCoral,
            kCoral.withOpacity(0.1)),
      ]),
    );
  }

  Widget _statPill(String label, Color textColor, Color bgColor) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor)),
    );
  }

  Widget _buildCard(StockTransaction item) {
    final isIn  = item.type == 'IN';
    final color = isIn ? const Color(0xFF00B894) : kCoral;
    final icon  = isIn
        ? Icons.arrow_downward_rounded
        : Icons.arrow_upward_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.productName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: kNavy),
                        overflow: TextOverflow.ellipsis),
                    Text('${item.date}  •  ${item.time}',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(item.type,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Expanded(
                    child: _detail('QTY', '${item.quantity}', color)),
                _divider(),
                Expanded(
                    child: _detail(
                        'BRANCH', item.branch, Colors.grey.shade700)),
                _divider(),
                Expanded(
                    child: _detail(
                        'PERSON', item.person, Colors.grey.shade700)),
              ]),
            ),
            if (item.departmentOrPurpose.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(
                    isIn
                        ? Icons.category_outlined
                        : Icons.work_outline_rounded,
                    size: 13,
                    color: Colors.grey.shade400),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(item.departmentOrPurpose,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ],
            if (item.remarks != null && item.remarks!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.comment_outlined,
                    size: 13, color: Colors.grey.shade400),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(item.remarks!,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontStyle: FontStyle.italic),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detail(String label, String value, Color valueColor) {
    return Column(children: [
      Text(label,
          style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade400,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      Text(value,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center),
    ]);
  }

  Widget _divider() => Container(
    height: 28,
    width: 1,
    color: Colors.grey.shade200,
    margin: const EdgeInsets.symmetric(horizontal: 4),
  );

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                  color: kCoral.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.cloud_off_rounded,
                  size: 36, color: kCoral),
            ),
            const SizedBox(height: 16),
            const Text('Failed to load',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: kNavy)),
            const SizedBox(height: 8),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey.shade500, fontSize: 13)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_toggle_off_rounded,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No records found',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text('Try adjusting filters or adding a transaction.',
              style: TextStyle(
                  color: Colors.grey.shade400, fontSize: 13)),
        ],
      ),
    );
  }
}