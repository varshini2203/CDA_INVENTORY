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

class InventoryAnalyticsScreen extends StatefulWidget {
  const InventoryAnalyticsScreen({super.key});

  @override
  State<InventoryAnalyticsScreen> createState() => _InventoryAnalyticsScreenState();
}

class _InventoryAnalyticsScreenState extends State<InventoryAnalyticsScreen> {
  bool _isLoading = true;
  String? _error;
  List<InventoryItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final items = await InventoryService().getInventory(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() { _items = items; _isLoading = false; });
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
        child: _AnalyticsBody(items: _items),
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
  const _AnalyticsBody({required this.items});

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
        // ── KPI GRID ──────────────────────────────────────────────────────
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.1, // width ÷ height of each KPI box — raise this number to make boxes shorter, lower it to make them taller
          children: [
            _KpiCard(label: 'Total products', value: '${a.totalProducts}', icon: Icons.inventory_2_rounded, color: _green),
            _KpiCard(label: 'Total quantity', value: '${a.totalQuantity}', icon: Icons.widgets_rounded, color: const Color(0xFF9C6BFF)),
            _KpiCard(label: 'Categories', value: '${a.categoryCount}', icon: Icons.category_rounded, color: _gold),
            _KpiCard(label: 'Branches', value: '${a.branchCount}', icon: Icons.business_rounded, color: _blueLight),
            _KpiCard(label: 'Low stock', value: '${a.lowStockCount}', icon: Icons.warning_amber_rounded, color: _gold),
            _KpiCard(label: 'Out of stock', value: '${a.outOfStockCount}', icon: Icons.remove_shopping_cart_rounded, color: _red),
            _KpiCard(label: 'Added this week', value: '${a.addedThisWeek}', icon: Icons.fiber_new_rounded, color: _green),
            _KpiCard(label: 'Health score', value: '${a.healthScore}', icon: Icons.favorite_rounded, color: _blueLight),
          ],
        ),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.45), width: 1.2),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.10), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(color: color, fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 1),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _textSub, fontSize: 11)),
        ],
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