// lib/screens/inventory/inventory_analytics_screen.dart
//
// "Inventory Analytics" — a read-only insights screen for the dashboard.
// Pulls the same InventoryItem list used by InventoryDashboard (one-shot
// cached read, same pattern as the rest of the app) and derives KPIs,
// category/branch breakdowns, stock-health, low-stock alerts, recently
// added items, a category donut chart and a 7-day additions trend —
// entirely with core Flutter widgets (no chart package).

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cda_inventory/models/inventory_model.dart';
import 'package:cda_inventory/services/inventory_service.dart';

// ── Theme tokens (matches lib/screens/dashboard/dashboard_screen.dart) ──────
// Top-level so every widget in this file can use them directly in const
// expressions — a static field accessed through a Type variable doesn't
// work in Dart, which is what caused the earlier build errors.
const Color _bg          = Color(0xFF050A14);
const Color _surface     = Color(0xFF0A1428);
const Color _surfaceHigh = Color(0xFF0F1C35);
const Color _border      = Color(0xFF1A2E50);
const Color _blue        = Color(0xFF1E5FC8);
const Color _blueLight   = Color(0xFF3A7AE8);
const Color _green       = Color(0xFF00D68F);
const Color _red         = Color(0xFFE8374A);
const Color _gold        = Color(0xFFF2B705);
const Color _textPrimary = Color(0xFFF0F6FF);
const Color _textSub     = Color(0xFFA0B8D0);
const Color _textMuted   = Color(0xFF4A6080);

const List<Color> _categoryPalette = [
  _blueLight, _green, _gold, Color(0xFF9C6BFF), _red,
  Color(0xFF00B8D9), Color(0xFFFF8A3D), Color(0xFF6C8CFF),
];

// One row of lib/screens/inventory/inventory_analytics_screen.dart's
// 'inventory_daily_snapshots' Firestore collection — one doc per calendar
// day, written the first time the analytics screen loads that day.
class _DailySnapshot {
  final String date; // 'yyyy-MM-dd'
  final int lowStockCount;
  final int outOfStockCount;
  final int totalQuantity;
  final int totalProducts;

  _DailySnapshot({
    required this.date,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.totalQuantity,
    required this.totalProducts,
  });

  factory _DailySnapshot.fromMap(Map<String, dynamic> m) => _DailySnapshot(
    date: m['date']?.toString() ?? '',
    lowStockCount: (m['lowStockCount'] as num?)?.toInt() ?? 0,
    outOfStockCount: (m['outOfStockCount'] as num?)?.toInt() ?? 0,
    totalQuantity: (m['totalQuantity'] as num?)?.toInt() ?? 0,
    totalProducts: (m['totalProducts'] as num?)?.toInt() ?? 0,
  );

  /// Short 'D Mon' label for chart axes, parsed from the yyyy-MM-dd key.
  String get shortLabel {
    final parts = date.split('-');
    if (parts.length != 3) return date;
    const months = ['', 'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final m = int.tryParse(parts[1]) ?? 0;
    return '${int.tryParse(parts[2]) ?? ''} ${m >= 1 && m <= 12 ? months[m] : ''}';
  }
}

class InventoryAnalyticsScreen extends StatefulWidget {
  const InventoryAnalyticsScreen({super.key});

  @override
  State<InventoryAnalyticsScreen> createState() => _InventoryAnalyticsScreenState();
}

class _InventoryAnalyticsScreenState extends State<InventoryAnalyticsScreen> {
  bool _isLoading = true;
  String? _error;
  List<InventoryItem> _items = [];
  List<_DailySnapshot> _lowStockHistory = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // Writes today's low/out-of-stock counts to a small daily-snapshot
  // collection (idempotent — same doc id if called again today), then
  // reads back up to the last 30 days. This is how the "Low stock
  // history" trend gets real data over time instead of invented numbers:
  // there's no way to know last month's low-stock count since the app
  // never recorded it, so the chart genuinely starts from today and
  // fills in day by day.
  Future<List<_DailySnapshot>> _saveAndLoadLowStockHistory(_Analytics a) async {
    final col = FirebaseFirestore.instance.collection('inventory_daily_snapshots');
    final todayKey = _dateKey(DateTime.now());

    await col.doc(todayKey).set({
      'date': todayKey,
      'lowStockCount': a.lowStockCount,
      'outOfStockCount': a.outOfStockCount,
      'totalQuantity': a.totalQuantity,
      'totalProducts': a.totalProducts,
      'savedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final cutoffKey = _dateKey(DateTime.now().subtract(const Duration(days: 29)));
    final snap = await col
        .where('date', isGreaterThanOrEqualTo: cutoffKey)
        .get();

    final list = snap.docs.map((d) => _DailySnapshot.fromMap(d.data())).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final items = await InventoryService().getInventory(forceRefresh: forceRefresh);
      final analytics = _Analytics.from(items);

      List<_DailySnapshot> history = [];
      try {
        history = await _saveAndLoadLowStockHistory(analytics);
      } catch (_) {
        // Snapshot tracking is a nice-to-have — the rest of the screen
        // should still render even if this write/read fails.
      }

      if (!mounted) return;
      setState(() {
        _items = items;
        _lowStockHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Failed to load inventory: $e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        foregroundColor: _textPrimary,
        title: const Text('Inventory Analytics',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: _textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _load(forceRefresh: true),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _blueLight))
          : _error != null
          ? _ErrorState(message: _error!, onRetry: () => _load(forceRefresh: true))
          : RefreshIndicator(
        color: _blueLight,
        backgroundColor: _surfaceHigh,
        onRefresh: () => _load(forceRefresh: true),
        child: _AnalyticsBody(items: _items, lowStockHistory: _lowStockHistory),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded, color: _textMuted, size: 40),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center,
              style: const TextStyle(color: _textSub, fontSize: 13)),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ]),
      ),
    );
  }
}

/* ════════════════════════════════════════════════════════════════════════
   ANALYTICS COMPUTATION (pure, no side effects)
   ════════════════════════════════════════════════════════════════════════ */
class _Analytics {
  final int totalProducts;
  final int totalQuantity;
  final int categoryCount;
  final int branchCount;
  final int lowStockCount;
  final int outOfStockCount;
  final int inStockCount;
  final int addedThisWeek;
  final int healthScore;
  final List<MapEntry<String, int>> categoryQty;   // sorted desc
  final Map<String, int> categoryItemCount;
  final List<MapEntry<int, int>> branchQty;        // branch -> qty, sorted desc
  final List<InventoryItem> lowStockItems;         // sorted qty asc
  final List<InventoryItem> outOfStockItems;
  final List<InventoryItem> recentItems;           // sorted createdAt desc
  final List<MapEntry<String, int>> topLocations;  // sorted desc
  final List<MapEntry<String, int>> last7DaysAdded; // day label -> count added

  _Analytics({
    required this.totalProducts,
    required this.totalQuantity,
    required this.categoryCount,
    required this.branchCount,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.inStockCount,
    required this.addedThisWeek,
    required this.healthScore,
    required this.categoryQty,
    required this.categoryItemCount,
    required this.branchQty,
    required this.lowStockItems,
    required this.outOfStockItems,
    required this.recentItems,
    required this.topLocations,
    required this.last7DaysAdded,
  });

  factory _Analytics.from(List<InventoryItem> items) {
    final now = DateTime.now();
    final categoryQtyMap = <String, int>{};
    final categoryItemCount = <String, int>{};
    final branchQtyMap = <int, int>{};
    final locationQtyMap = <String, int>{};
    int totalQuantity = 0;
    int lowStock = 0, outOfStock = 0, inStock = 0, addedThisWeek = 0;
    final lowStockItems = <InventoryItem>[];
    final outOfStockItems = <InventoryItem>[];
    final recentItems = <InventoryItem>[];

    // Bucket for the last 7 calendar days (today inclusive), oldest first —
    // built from each item's real createdAt timestamp, so this reflects
    // actual intake activity rather than mock data.
    final dayBuckets = List<int>.filled(7, 0);
    const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime(now.year, now.month, now.day);

    for (final item in items) {
      totalQuantity += item.quantity;
      categoryQtyMap.update(item.category, (v) => v + item.quantity, ifAbsent: () => item.quantity);
      categoryItemCount.update(item.category, (v) => v + 1, ifAbsent: () => 1);
      branchQtyMap.update(item.branch, (v) => v + item.quantity, ifAbsent: () => item.quantity);
      if (item.location.trim().isNotEmpty) {
        locationQtyMap.update(item.location, (v) => v + item.quantity, ifAbsent: () => item.quantity);
      }
      if (item.isOutOfStock) { outOfStock++; outOfStockItems.add(item); }
      else if (item.isLowStock) { lowStock++; lowStockItems.add(item); }
      else { inStock++; }
      if (item.createdAt != null) {
        final created = item.createdAt!;
        if (now.difference(created).inDays <= 7) {
          addedThisWeek++;
          recentItems.add(item);
        }
        final createdDay = DateTime(created.year, created.month, created.day);
        final offset = today.difference(createdDay).inDays;
        if (offset >= 0 && offset < 7) {
          dayBuckets[6 - offset] += 1;
        }
      }
    }

    lowStockItems.sort((a, b) => a.quantity.compareTo(b.quantity));
    recentItems.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));

    final categoryQty = categoryQtyMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final branchQty = branchQtyMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topLocations = locationQtyMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final last7DaysAdded = List.generate(7, (i) {
      final d = today.subtract(Duration(days: 6 - i));
      return MapEntry(weekdayShort[d.weekday - 1], dayBuckets[i]);
    });

    // Health score: penalise out-of-stock heavily, low-stock moderately.
    final total = items.isEmpty ? 1 : items.length;
    final outRatio = outOfStock / total;
    final lowRatio = lowStock / total;
    final score = (100 - outRatio * 60 - lowRatio * 30).clamp(0, 100).round();

    return _Analytics(
      totalProducts: items.length,
      totalQuantity: totalQuantity,
      categoryCount: categoryQtyMap.length,
      branchCount: branchQtyMap.keys.where((b) => b != 0).length,
      lowStockCount: lowStock,
      outOfStockCount: outOfStock,
      inStockCount: inStock,
      addedThisWeek: addedThisWeek,
      healthScore: score,
      categoryQty: categoryQty,
      categoryItemCount: categoryItemCount,
      branchQty: branchQty,
      lowStockItems: lowStockItems,
      outOfStockItems: outOfStockItems,
      recentItems: recentItems,
      topLocations: topLocations.take(5).toList(),
      last7DaysAdded: last7DaysAdded,
    );
  }
}

/* ════════════════════════════════════════════════════════════════════════
   BODY
   ════════════════════════════════════════════════════════════════════════ */
class _AnalyticsBody extends StatelessWidget {
  final List<InventoryItem> items;
  final List<_DailySnapshot> lowStockHistory;
  const _AnalyticsBody({required this.items, required this.lowStockHistory});

  @override
  Widget build(BuildContext context) {
    final a = _Analytics.from(items);

    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Icon(Icons.inventory_2_outlined, color: _textMuted, size: 48),
          SizedBox(height: 12),
          Center(child: Text('No inventory yet',
              style: TextStyle(color: _textSub, fontSize: 14))),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // ── KPI ROW — compact cards, same box style as the Inventory screen ─
        Row(children: [
          _KpiCard(label: 'Products', value: '${a.totalProducts}', icon: Icons.category_rounded, color: _green),
          const SizedBox(width: 8),
          _KpiCard(label: 'Quantity', value: '${a.totalQuantity}', icon: Icons.layers_rounded, color: const Color(0xFF9C6BFF)),
          const SizedBox(width: 8),
          _KpiCard(label: 'Categories', value: '${a.categoryCount}', icon: Icons.grid_view_rounded, color: _gold),
          const SizedBox(width: 8),
          _KpiCard(label: 'Branches', value: '${a.branchCount}', icon: Icons.business_rounded, color: _blueLight),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _KpiCard(label: 'Low stock', value: '${a.lowStockCount}', icon: Icons.warning_amber_rounded, color: a.lowStockCount > 0 ? _gold : _textMuted),
          const SizedBox(width: 8),
          _KpiCard(label: 'Empty', value: '${a.outOfStockCount}', icon: Icons.remove_circle_outline_rounded, color: a.outOfStockCount > 0 ? _red : _textMuted),
          const SizedBox(width: 8),
          _KpiCard(label: 'New (7d)', value: '${a.addedThisWeek}', icon: Icons.fiber_new_rounded, color: _green),
          const SizedBox(width: 8),
          _KpiCard(label: 'Health', value: '${a.healthScore}', icon: Icons.favorite_rounded, color: _blueLight),
        ]),
        const SizedBox(height: 18),

        // ── HEALTH GAUGE ──────────────────────────────────────────────────
        _SectionCard(
          title: 'Inventory health',
          subtitle: 'Based on low-stock and out-of-stock ratio',
          child: _HealthGauge(score: a.healthScore),
        ),
        const SizedBox(height: 14),

        // ── ADDITIONS TREND (real createdAt data, last 7 days) ──────────────
        _SectionCard(
          title: 'Additions trend',
          subtitle: 'Products added per day, last 7 days',
          child: _TrendBarChart(
            data: a.last7DaysAdded,
            color: _blueLight,
          ),
        ),
        const SizedBox(height: 14),

        // ── LOW STOCK HISTORY (real daily snapshots, builds up over time) ───
        _SectionCard(
          title: 'Low stock history',
          subtitle: lowStockHistory.length < 2
              ? 'Products under threshold — tracking starts today'
              : 'Products under threshold, last ${lowStockHistory.length} days',
          child: _LowStockHistoryChart(history: lowStockHistory, currentCount: a.lowStockCount),
        ),
        const SizedBox(height: 14),

        // ── STOCK STATUS SPLIT ───────────────────────────────────────────
        _SectionCard(
          title: 'Stock status split',
          subtitle: '${a.totalProducts} products in total',
          child: _StockStatusBar(
            inStock: a.inStockCount,
            lowStock: a.lowStockCount,
            outOfStock: a.outOfStockCount,
          ),
        ),
        const SizedBox(height: 14),

        // ── CATEGORY DONUT ────────────────────────────────────────────────
        _SectionCard(
          title: 'Inventory by category',
          subtitle: 'Quantity distribution across categories',
          child: _DonutBreakdown(
            entries: a.categoryQty,
            totalLabel: 'total units',
            colors: _categoryPalette,
          ),
        ),
        const SizedBox(height: 14),

        // ── BRANCH DONUT ──────────────────────────────────────────────────
        if (a.branchQty.length > 1)
          _SectionCard(
            title: 'Inventory by branch',
            subtitle: 'Quantity split across locations',
            child: _DonutBreakdown(
              entries: a.branchQty
                  .map((e) => MapEntry(
                InventoryItem(
                  id: '', name: '', category: '', location: '', quantity: 0,
                  branch: e.key,
                ).branchLabel,
                e.value,
              ))
                  .toList(),
              totalLabel: 'total units',
              colors: _categoryPalette,
            ),
          ),
        if (a.branchQty.length > 1) const SizedBox(height: 14),

        // ── CATEGORY BAR BREAKDOWN (kept alongside donut for exact counts) ──
        _SectionCard(
          title: 'Category detail',
          subtitle: 'Quantity and item count per category',
          child: Column(
            children: [
              for (int i = 0; i < a.categoryQty.length; i++)
                _CategoryBarRow(
                  label: a.categoryQty[i].key,
                  qty: a.categoryQty[i].value,
                  itemCount: a.categoryItemCount[a.categoryQty[i].key] ?? 0,
                  maxQty: a.categoryQty.first.value,
                  color: _categoryPalette[i % _categoryPalette.length],
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── LOW STOCK ALERTS ─────────────────────────────────────────────
        if (a.lowStockItems.isNotEmpty || a.outOfStockItems.isNotEmpty)
          _SectionCard(
            title: 'Reorder alerts',
            subtitle: '${a.outOfStockItems.length} out of stock · ${a.lowStockItems.length} running low',
            child: Column(
              children: [
                for (final item in [...a.outOfStockItems, ...a.lowStockItems].take(8))
                  _AlertRow(item: item),
              ],
            ),
          ),
        if (a.lowStockItems.isNotEmpty || a.outOfStockItems.isNotEmpty) const SizedBox(height: 14),

        // ── TOP LOCATIONS ─────────────────────────────────────────────────
        if (a.topLocations.isNotEmpty)
          _SectionCard(
            title: 'Top storage locations',
            subtitle: 'By quantity stored',
            child: Column(
              children: [
                for (int i = 0; i < a.topLocations.length; i++)
                  _CategoryBarRow(
                    label: a.topLocations[i].key,
                    qty: a.topLocations[i].value,
                    itemCount: null,
                    maxQty: a.topLocations.first.value,
                    color: _blueLight,
                  ),
              ],
            ),
          ),
        if (a.topLocations.isNotEmpty) const SizedBox(height: 14),

        // ── RECENTLY ADDED ───────────────────────────────────────────────
        if (a.recentItems.isNotEmpty)
          _SectionCard(
            title: 'Recently added',
            subtitle: 'Last 7 days',
            child: Column(
              children: [
                for (final item in a.recentItems.take(6)) _RecentRow(item: item),
              ],
            ),
          ),
      ],
    );
  }
}

/* ════════════════════════════════════════════════════════════════════════
   SHARED WIDGETS
   ════════════════════════════════════════════════════════════════════════ */
class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    // Same box proportions as the compact stat cards on the Inventory
    // screen (_statCard in inventory_dashboard.dart) — tight padding,
    // left accent bar, icon above a bold value and small label.
    //
    // NOTE: a BoxDecoration can't combine borderRadius with a Border that
    // has different widths/colors per side (that's what was throwing
    // "borderRadius can only be given for uniform borders" and silently
    // leaving these boxes blank). So the rounded outline is a plain
    // uniform Border.all, and the colored accent is a separate 3px bar
    // drawn on top instead of being part of the border itself.
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: _surface,
            border: Border.all(color: _border),
          ),
          child: Stack(
            children: [
              Positioned(left: 0, top: 0, bottom: 0, child: Container(width: 3, color: color)),
              Padding(
                padding: const EdgeInsets.only(top: 10, right: 10, bottom: 10, left: 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: color, size: 18),
                    const SizedBox(height: 4),
                    Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 9, color: _textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _SectionCard({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: _textMuted, fontSize: 11.5)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _HealthGauge extends StatelessWidget {
  final int score;
  const _HealthGauge({required this.score});

  _StatusInfo get _status {
    if (score >= 85) return _StatusInfo('Excellent', _green);
    if (score >= 65) return _StatusInfo('Good', _blueLight);
    if (score >= 45) return _StatusInfo('Warning', _gold);
    return _StatusInfo('Critical', _red);
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Column(
      children: [
        SizedBox(
          height: 110,
          child: CustomPaint(
            size: const Size(double.infinity, 110),
            painter: _GaugePainter(score: score, color: status.color),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$score', style: const TextStyle(color: _textPrimary, fontSize: 30, fontWeight: FontWeight.w700)),
                    const Text('out of 100', style: TextStyle(color: _textMuted, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(color: status.color.withOpacity(0.14), borderRadius: BorderRadius.circular(20)),
          child: Text(status.label, style: TextStyle(color: status.color, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _StatusInfo {
  final String label;
  final Color color;
  _StatusInfo(this.label, this.color);
}

class _GaugePainter extends CustomPainter {
  final int score;
  final Color color;
  _GaugePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 6);
    final radius = math.min(size.width / 2 - 12, size.height - 12);
    const start = math.pi;
    const sweepTotal = math.pi;

    final track = Paint()
      ..color = const Color(0xFF1A2E50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweepTotal, false, track);

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweepTotal * (score / 100), false, fill);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.score != score || oldDelegate.color != color;
}

/* ────────────────────────────────────────────────────────────────────────
   TREND BAR CHART — simple vertical bars for the last-7-days additions
   trend. Pure CustomPaint, no chart package, sized to fit the card width.
   ──────────────────────────────────────────────────────────────────────── */
class _TrendBarChart extends StatelessWidget {
  final List<MapEntry<String, int>> data; // day label -> count
  final Color color;
  const _TrendBarChart({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    final maxVal = data.map((e) => e.value).fold<int>(0, math.max);
    return SizedBox(
      height: 140,
      child: data.every((e) => e.value == 0)
          ? const Center(
        child: Text('No items added in the last 7 days',
            style: TextStyle(color: _textMuted, fontSize: 12)),
      )
          : Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final entry in data)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (entry.value > 0)
                      Text('${entry.value}',
                          style: const TextStyle(color: _textSub, fontSize: 10.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: maxVal == 0 ? 4 : (entry.value / maxVal) * 88 + 4,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter, end: Alignment.topCenter,
                              colors: [color.withOpacity(0.35), color],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(entry.key, style: const TextStyle(color: _textMuted, fontSize: 10.5)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/* ────────────────────────────────────────────────────────────────────────
   LOW STOCK HISTORY — red-gradient area chart over real daily snapshots
   (see _saveAndLoadLowStockHistory). Renders a friendly placeholder until
   at least 2 days of real data exist, since there's no way to know past
   counts the app never recorded.
   ──────────────────────────────────────────────────────────────────────── */
class _LowStockHistoryChart extends StatelessWidget {
  final List<_DailySnapshot> history;
  final int currentCount;
  const _LowStockHistoryChart({required this.history, required this.currentCount});

  @override
  Widget build(BuildContext context) {
    if (history.length < 2) {
      return SizedBox(
        height: 150,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$currentCount',
                  style: const TextStyle(color: _red, fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('low stock today', style: TextStyle(color: _textMuted, fontSize: 11.5)),
              const SizedBox(height: 10),
              const Text('Come back tomorrow to see the trend build up',
                  style: TextStyle(color: _textMuted, fontSize: 11), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    final values = history.map((h) => h.lowStockCount).toList();
    final highest = values.reduce(math.max);
    final lowest = values.reduce(math.min);
    final avg = values.reduce((a, b) => a + b) / values.length;

    return Column(
      children: [
        SizedBox(
          height: 170,
          child: CustomPaint(
            size: const Size(double.infinity, 170),
            painter: _AreaChartPainter(values: values.map((v) => v.toDouble()).toList(), color: _red),
          ),
        ),
        Row(
          children: [
            Expanded(child: Text(history.first.shortLabel, style: const TextStyle(color: _textMuted, fontSize: 10))),
            Expanded(child: Text(history.last.shortLabel, textAlign: TextAlign.right, style: const TextStyle(color: _textMuted, fontSize: 10))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _MiniStat(label: 'Highest', value: '$highest', color: _red),
            _MiniStat(label: 'Average', value: avg.toStringAsFixed(1), color: _gold),
            _MiniStat(label: 'Lowest', value: '$lowest', color: _green),
          ],
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: _textMuted, fontSize: 10.5)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Generic gradient-filled line chart used by the low-stock history card.
/// Straight-segment polyline (not bezier-smoothed) but visually reads the
/// same way as the smooth area chart it's modelled on: line + soft fill
/// fading to transparent, with light horizontal gridlines.
class _AreaChartPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  _AreaChartPainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = values.reduce(math.max);
    final minV = values.reduce(math.min);
    final range = (maxV - minV) == 0 ? 1 : (maxV - minV);
    const topPad = 10.0, bottomPad = 6.0;
    final chartH = size.height - topPad - bottomPad;
    final stepX = values.length > 1 ? size.width / (values.length - 1) : size.width;

    // gridlines
    final gridPaint = Paint()..color = _border..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = topPad + chartH * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    Offset pointAt(int i) {
      final x = stepX * i;
      final norm = (values[i] - minV) / range;
      final y = topPad + chartH * (1 - norm);
      return Offset(x, y);
    }

    final linePath = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (int i = 1; i < values.length; i++) {
      linePath.lineTo(pointAt(i).dx, pointAt(i).dy);
    }

    final fillPath = Path()
      ..addPath(linePath, Offset.zero)
      ..lineTo(pointAt(values.length - 1).dx, size.height)
      ..lineTo(pointAt(0).dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.32), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    // highlight highest / lowest points
    for (int i = 0; i < values.length; i++) {
      if (values[i] == maxV || values[i] == minV) {
        final p = pointAt(i);
        canvas.drawCircle(p, 3.2, Paint()..color = color);
        canvas.drawCircle(p, 3.2, Paint()..color = _surface..style = PaintingStyle.stroke..strokeWidth = 1.4);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AreaChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

/* ────────────────────────────────────────────────────────────────────────
   DONUT BREAKDOWN — real ring chart (CustomPaint) with a scrollable legend,
   used for category and branch distributions. No chart package needed.
   ──────────────────────────────────────────────────────────────────────── */
class _DonutBreakdown extends StatelessWidget {
  final List<MapEntry<String, int>> entries; // already sorted desc
  final String totalLabel;
  final List<Color> colors;
  const _DonutBreakdown({required this.entries, required this.totalLabel, required this.colors});

  @override
  Widget build(BuildContext context) {
    final total = entries.fold<int>(0, (sum, e) => sum + e.value);
    final slices = <_DonutSlice>[
      for (int i = 0; i < entries.length; i++)
        _DonutSlice(
          value: entries[i].value,
          color: colors[i % colors.length],
        ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 140, height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(140, 140),
                painter: _DonutPainter(slices: slices, total: total),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$total',
                      style: const TextStyle(color: _textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
                  Text(totalLabel, style: const TextStyle(color: _textMuted, fontSize: 9.5)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < entries.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(width: 8, height: 8,
                          decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(entries[i].key, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        total == 0 ? '0%' : '${((entries[i].value / total) * 100).round()}%',
                        style: const TextStyle(color: _textSub, fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutSlice {
  final int value;
  final Color color;
  _DonutSlice({required this.value, required this.color});
}

class _DonutPainter extends CustomPainter {
  final List<_DonutSlice> slices;
  final int total;
  _DonutPainter({required this.slices, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 18.0;

    final track = Paint()
      ..color = const Color(0xFF15233F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius - strokeWidth / 2, track);

    if (total == 0) return;

    double startAngle = -math.pi / 2;
    const gap = 0.03; // small visual gap between slices
    for (final slice in slices) {
      if (slice.value <= 0) continue;
      final sweep = (slice.value / total) * (math.pi * 2) - gap;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle, math.max(sweep, 0), false, paint,
      );
      startAngle += (slice.value / total) * (math.pi * 2);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.slices != slices || oldDelegate.total != total;
}

class _StockStatusBar extends StatelessWidget {
  final int inStock;
  final int lowStock;
  final int outOfStock;
  const _StockStatusBar({required this.inStock, required this.lowStock, required this.outOfStock});

  @override
  Widget build(BuildContext context) {
    final total = (inStock + lowStock + outOfStock).clamp(1, 1 << 30);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                if (inStock > 0) Expanded(flex: inStock, child: Container(color: _green)),
                if (lowStock > 0) Expanded(flex: lowStock, child: Container(color: _gold)),
                if (outOfStock > 0) Expanded(flex: outOfStock, child: Container(color: _red)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 16, runSpacing: 6, children: [
          _LegendDot(color: _green, label: 'In stock · $inStock'),
          _LegendDot(color: _gold, label: 'Low stock · $lowStock'),
          _LegendDot(color: _red, label: 'Out of stock · $outOfStock'),
        ]),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: _textSub, fontSize: 11.5)),
    ]);
  }
}

class _CategoryBarRow extends StatelessWidget {
  final String label;
  final int qty;
  final int? itemCount;
  final int maxQty;
  final Color color;
  const _CategoryBarRow({
    required this.label, required this.qty, required this.itemCount,
    required this.maxQty, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = maxQty == 0 ? 0.0 : qty / maxQty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
              Text(
                itemCount != null ? '$qty · $itemCount items' : '$qty',
                style: const TextStyle(color: _textSub, fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.02, 1.0),
              minHeight: 7,
              backgroundColor: const Color(0xFF15233F),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final InventoryItem item;
  const _AlertRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final isOut = item.isOutOfStock;
    final color = isOut ? _red : _gold;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(9)),
            child: Icon(isOut ? Icons.remove_shopping_cart_rounded : Icons.warning_amber_rounded, size: 15, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                Text('${item.category} · ${item.branchLabel}',
                    style: const TextStyle(color: _textMuted, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(20)),
            child: Text('${item.quantity} left', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  final InventoryItem item;
  const _RecentRow({required this.item});

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: _green.withOpacity(0.14), borderRadius: BorderRadius.circular(9)),
            child: const Icon(Icons.fiber_new_rounded, size: 15, color: _green),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                Text('${item.category} · qty ${item.quantity}',
                    style: const TextStyle(color: _textMuted, fontSize: 11)),
              ],
            ),
          ),
          if (item.createdAt != null)
            Text(_timeAgo(item.createdAt!), style: const TextStyle(color: _textSub, fontSize: 11)),
        ],
      ),
    );
  }
}