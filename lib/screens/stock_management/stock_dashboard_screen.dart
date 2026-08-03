import 'package:flutter/material.dart';
import 'package:cda_inventory/models/stock.dart';
import 'package:cda_inventory/services/stock_service.dart';
import 'package:cda_inventory/services/stock_seed_service.dart';
import 'stock_in_screen.dart';
import 'stock_out_screen.dart';
import 'stock_history_screen.dart';
import 'stock_items_screen.dart';
import 'package:cda_inventory/screens/bulk_import/bulk_import_screen.dart';

class StockDashboardScreen extends StatefulWidget {
  const StockDashboardScreen({super.key});

  @override
  State<StockDashboardScreen> createState() => _StockDashboardScreenState();
}

class _StockDashboardScreenState extends State<StockDashboardScreen>
    with TickerProviderStateMixin {
  StockDashboardData? _data;
  bool _loading = true;
  String? _error;
  bool _seeding = false;
  double _seedProgress = 0;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // Design tokens
  static const Color kNavy    = Color(0xFF0A1628);
  static const Color kTeal    = Color(0xFF00D4AA);
  static const Color kCoral   = Color(0xFFFF6B6B);
  static const Color kAmber   = Color(0xFFFFB800);
  static const Color kPurple  = Color(0xFF6C63FF);
  static const Color kSurface = Color(0xFFF0F4F8);
  static const Color kCard    = Colors.white;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadDashboard();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard({bool forceRefresh = false}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await StockService.fetchDashboard(forceRefresh: forceRefresh);
      setState(() { _data = data; _loading = false; });
      _animController.forward(from: 0);
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _seedSampleData() async {
    setState(() { _seeding = true; _seedProgress = 0; });
    try {
      await StockSeedService.seedAll(
        onProgress: (p) => setState(() => _seedProgress = p),
      );
      if (!mounted) return;
      setState(() => _seeding = false);
      await _loadDashboard(forceRefresh: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock items loaded successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _seeding = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Seeding failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: RefreshIndicator(
        onRefresh: () => _loadDashboard(forceRefresh: true),
        color: kTeal,
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            if (_loading)
              const SliverFillRemaining(child: Center(child: _LoadingWidget()))
            else if (_error != null)
              SliverFillRemaining(child: _buildError())
            else
              SliverToBoxAdapter(child: _buildBody()),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  // ── Sliver App Bar (matches Invoices pattern) ──────────────────────────
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 190,
      floating: false,
      pinned: true,
      backgroundColor: kNavy,
      foregroundColor: Colors.white,
      // Title lives here on SliverAppBar (not FlexibleSpaceBar) so it only
      // appears in the collapsed/pinned state and never overlaps the KPI
      // chips shown in the expanded background.
      title: const Text(
        'Stock Management',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.inventory_2_outlined),
          tooltip: 'All Items',
          onPressed: () {
            Navigator.push(context,
                MaterialPageRoute(settings: const RouteSettings(name: 'Stock Items'), builder: (_) => const StockItemsScreen()));
          },
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh',
          onPressed: () => _loadDashboard(forceRefresh: true),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        // No title on FlexibleSpaceBar — avoids the duplicate/overlap issue;
        // the heading is owned entirely by SliverAppBar.title above.
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A1628), Color(0xFF162944)],
            ),
          ),
          child: ClipRect(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text(
                      'Stock Management',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'CDA Inventory System',
                      style: TextStyle(
                        color: kTeal,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!_loading && _error == null && _data != null)
                      Row(children: [
                        _kpiChip(Icons.inventory_2_rounded,
                            '${_data!.totalProducts}', 'Products'),
                        const SizedBox(width: 10),
                        _kpiChip(Icons.warning_amber_rounded,
                            '${_data!.lowStockCount}', 'Low Stock'),
                      ]),
                  ],
                ),
              ),
            ),
          ),
        ),
        collapseMode: CollapseMode.parallax,
      ),
    );
  }

  Widget _kpiChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: kTeal, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
              Text(label,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.6), fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: 'out',
          backgroundColor: kCoral,
          foregroundColor: Colors.white,
          tooltip: 'Stock OUT',
          onPressed: () async {
            await Navigator.push(context,
                MaterialPageRoute(settings: const RouteSettings(name: 'Stock Out'), builder: (_) => const StockOutScreen()));
            _loadDashboard();
          },
          child: const Icon(Icons.arrow_upward_rounded),
        ),
        const SizedBox(height: 10),
        FloatingActionButton(
          heroTag: 'in',
          backgroundColor: kTeal,
          foregroundColor: Colors.white,
          tooltip: 'Stock IN',
          onPressed: () async {
            await Navigator.push(context,
                MaterialPageRoute(settings: const RouteSettings(name: 'Stock In'), builder: (_) => const StockInScreen()));
            _loadDashboard();
          },
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: kCoral.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded,
                  size: 40, color: kCoral),
            ),
            const SizedBox(height: 20),
            const Text('Failed to load',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: kNavy)),
            const SizedBox(height: 8),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey.shade500, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadDashboard,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Seed sample data banner (shown while stock_items is empty) ──────────
  Widget _buildSeedBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kTeal.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: kTeal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.cloud_upload_rounded,
                  color: kTeal, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('No products yet',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: kNavy)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            'Load the Branch 1 & Branch 2 fixed assets and consumables '
                '(1,480 items) into Stock Management.',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),
          if (_seeding) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _seedProgress == 0 ? null : _seedProgress,
                backgroundColor: Colors.grey.shade100,
                valueColor: const AlwaysStoppedAnimation(kTeal),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text('Loading products… ${(_seedProgress * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ] else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _seedSampleData,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: const Text('Load Products'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final d = _data!;
    return FadeTransition(
      opacity: _fadeAnim,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (d.totalProducts == 0) ...[
              _buildSeedBanner(),
              const SizedBox(height: 20),
            ],
            // ── KPI Cards ─────────────────────────────────────────────────
            _sectionLabel('OVERVIEW'),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _kpiCard('Total Products', '${d.totalProducts}',
                  Icons.inventory_2_rounded, kTeal, 'Items tracked')),
              const SizedBox(width: 12),
              Expanded(child: _kpiCard('Low Stock', '${d.lowStockCount}',
                  Icons.warning_amber_rounded, kAmber, 'Need attention',
                  urgent: d.lowStockCount > 0)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _kpiCard('Fixed Assets', '${d.fixedAssets}',
                  Icons.business_center_rounded,
                  const Color(0xFF6C63FF), 'Equipment')),
              const SizedBox(width: 12),
              Expanded(child: _kpiCard('Consumables', '${d.consumables}',
                  Icons.category_rounded, kCoral, 'Supplies')),
            ]),

            const SizedBox(height: 28),

            // ── Quick Actions ──────────────────────────────────────────────
            _sectionLabel('QUICK ACTIONS'),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _actionTile(
                label: 'Stock IN',
                sub: 'Add inventory',
                icon: Icons.arrow_downward_rounded,
                color: const Color(0xFF00B894),
                onTap: () async {
                  await Navigator.push(context,
                      MaterialPageRoute(settings: const RouteSettings(name: 'Stock In'),
                          builder: (_) => const StockInScreen()));
                  _loadDashboard();
                },
              )),
              const SizedBox(width: 12),
              Expanded(child: _actionTile(
                label: 'Stock OUT',
                sub: 'Issue items',
                icon: Icons.arrow_upward_rounded,
                color: kCoral,
                onTap: () async {
                  await Navigator.push(context,
                      MaterialPageRoute(settings: const RouteSettings(name: 'Stock Out'),
                          builder: (_) => const StockOutScreen()));
                  _loadDashboard();
                },
              )),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _actionTile(
                label: 'History',
                sub: 'View transactions',
                icon: Icons.history_rounded,
                color: const Color(0xFF6C63FF),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(settings: const RouteSettings(name: 'Stock History'),
                        builder: (_) => const StockHistoryScreen())),
              )),
              const SizedBox(width: 12),
              Expanded(child: _actionTile(
                label: 'All Items',
                sub: 'Browse stock',
                icon: Icons.list_alt_rounded,
                color: kAmber,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(settings: const RouteSettings(name: 'Stock Items'),
                        builder: (_) => const StockItemsScreen())),
              )),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: _actionTile(
                label: 'Bulk Import',
                sub: 'Add 50–100+ products at once from an Excel or PDF file',
                icon: Icons.upload_file_rounded,
                color: kNavy,
                onTap: () async {
                  await Navigator.push(context,
                      MaterialPageRoute(settings: const RouteSettings(name: 'Bulk Import Stock'),
                          builder: (_) => const BulkImportScreen(target: BulkImportTarget.stockManagement)));
                  _loadDashboard();
                },
              ),
            ),

            const SizedBox(height: 28),

            // ── Branch Stocks ──────────────────────────────────────────────
            _sectionLabel('BRANCH WISE STOCK'),
            const SizedBox(height: 10),
            _buildBranchSection(d),

            const SizedBox(height: 28),

            // ── Low Stock Alerts ───────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionLabel('LOW STOCK ALERTS'),
                if (d.lowStockCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: kCoral,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${d.lowStockCount} items',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _buildLowStockSection(d),

            const SizedBox(height: 28),

            // ── Recent Activity ──────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionLabel('RECENT ACTIVITY'),
                if (d.recentActivity.isNotEmpty)
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(settings: const RouteSettings(name: 'Stock History'),
                            builder: (_) => const StockHistoryScreen())),
                    child: Row(children: const [
                      Text('View All',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: kTeal)),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded,
                          size: 16, color: kTeal),
                    ]),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _buildRecentActivitySection(d),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade500,
          letterSpacing: 1.4));

  Widget _kpiCard(String title, String value, IconData icon, Color color,
      String sub, {bool urgent = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
        border: urgent
            ? Border.all(color: kAmber.withOpacity(0.4), width: 1.5)
            : Border.all(color: Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            if (urgent)
              Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: kAmber, shape: BoxShape.circle)),
          ]),
          const SizedBox(height: 14),
          Text(value,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: kNavy,
                  height: 1)),
          const SizedBox(height: 4),
          Text(title,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: kNavy)),
          const SizedBox(height: 2),
          Text(sub,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _actionTile({
    required String label,
    required String sub,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: kNavy)),
                Text(sub,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.grey.shade300),
        ]),
      ),
    );
  }

  Widget _buildBranchSection(StockDashboardData d) {
    if (d.branchStocks.isEmpty) {
      return _emptyState('No branch data', Icons.business_outlined);
    }
    final total =
    d.branchStocks.fold<int>(0, (s, b) => s + b.itemCount);
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < d.branchStocks.length; i++) ...[
            _branchRow(d.branchStocks[i], total, i),
            if (i < d.branchStocks.length - 1)
              Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: Colors.grey.shade100),
          ],
        ],
      ),
    );
  }

  Widget _branchRow(BranchStock b, int total, int index) {
    final colors = [kTeal, const Color(0xFF6C63FF), kAmber, kCoral];
    final color  = colors[index % colors.length];
    final pct    = total > 0 ? b.itemCount / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.store_rounded, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.branch,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: kNavy)),
                  Text(
                      '${b.itemCount} items  •  ${(pct * 100).toStringAsFixed(0)}% of total',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Text('${b.itemCount}',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: color)),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockSection(StockDashboardData d) {
    if (d.lowStockItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF00B894).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: Color(0xFF00B894), size: 22),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('All Good!',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: kNavy)),
              Text('All products are well stocked',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ]),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < d.lowStockItems.length; i++) ...[
            _lowStockRow(d.lowStockItems[i]),
            if (i < d.lowStockItems.length - 1)
              Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: Colors.grey.shade100),
          ],
        ],
      ),
    );
  }

  Widget _lowStockRow(StockItem item) {
    final pct = item.minStock > 0
        ? (item.quantity / item.minStock).clamp(0.0, 1.0)
        : 0.0;
    final color = pct < 0.3
        ? kCoral
        : pct < 0.7
        ? kAmber
        : const Color(0xFF00B894);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: kCoral.withOpacity(0.1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(Icons.warning_amber_rounded,
              color: kCoral, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.productName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: kNavy),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(item.branch,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${item.quantity}/${item.minStock}',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600)),
              ]),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: kCoral.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('${item.quantity} left',
              style: const TextStyle(
                  color: kCoral,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  // ── Recent Activity feed ────────────────────────────────────────────────
  Widget _buildRecentActivitySection(StockDashboardData d) {
    if (d.recentActivity.isEmpty) {
      return _emptyState('No recent activity', Icons.history_toggle_off_rounded);
    }
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < d.recentActivity.length; i++) ...[
            _recentActivityRow(d.recentActivity[i]),
            if (i < d.recentActivity.length - 1)
              Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: Colors.grey.shade100),
          ],
        ],
      ),
    );
  }

  Widget _recentActivityRow(StockTransaction t) {
    Color color;
    IconData icon;
    String label;
    if (t.isInbound) {
      color = const Color(0xFF00B894);
      icon = t.type == 'TRANSFER_IN'
          ? Icons.call_received_rounded
          : Icons.arrow_downward_rounded;
      label = t.type == 'TRANSFER_IN' ? 'Transfer In' : 'Stock In';
    } else if (t.isOutbound) {
      color = kCoral;
      icon = t.type == 'TRANSFER_OUT'
          ? Icons.call_made_rounded
          : Icons.arrow_upward_rounded;
      label = t.type == 'TRANSFER_OUT' ? 'Transfer Out' : 'Stock Out';
    } else {
      color = kAmber;
      icon = Icons.tune_rounded;
      label = 'Adjustment';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(t.productName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: kNavy),
                      overflow: TextOverflow.ellipsis),
                ),
                Text('${t.date}',
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey.shade400)),
              ]),
              const SizedBox(height: 2),
              Text('$label  •  ${t.quantity}  •  ${t.branch}  •  ${t.person}',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _emptyState(String msg, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
          color: kCard, borderRadius: BorderRadius.circular(16)),
      child: Center(
        child: Column(children: [
          Icon(icon, size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Text(msg, style: TextStyle(color: Colors.grey.shade400)),
        ]),
      ),
    );
  }
}

class _LoadingWidget extends StatelessWidget {
  const _LoadingWidget();
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: Color(0xFF00D4AA)),
        const SizedBox(height: 16),
        Text('Loading dashboard…',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
      ],
    );
  }
}