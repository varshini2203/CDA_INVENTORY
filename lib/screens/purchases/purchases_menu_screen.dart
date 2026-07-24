import 'package:flutter/material.dart';
import 'package:cda_inventory/shared/inventory_ui.dart';
import 'package:cda_inventory/services/purchase_service.dart';
import 'package:cda_inventory/services/purchase_order_service.dart';
import 'package:cda_inventory/services/purchase_return_service.dart';
import 'package:cda_inventory/services/payment_out_service.dart';
import 'purchase_list_screen.dart';
import 'purchase_order_list_screen.dart';
import 'payment_out_list_screen.dart';
import 'purchase_return_list_screen.dart';

/// Simple in-memory cache for the Purchases menu summary, shared across
/// screen instances for the lifetime of the app. Reading 4 full
/// collections (purchases, purchase_orders, purchase_returns,
/// payment_outs) just to show 5 numbers is expensive, and the raw numbers
/// rarely change second-to-second — so we cache them for a short window
/// and only hit Firestore again after the TTL expires or the user
/// explicitly pulls to refresh. This turns "every time the Purchases menu
/// opens" (which happens a lot, since it's the hub screen) into "at most
/// once every few minutes."
class _PurchasesSummaryCache {
  static Map<String, dynamic>? data;
  static DateTime? fetchedAt;
  static const ttl = Duration(minutes: 3);

  static bool get isFresh =>
      data != null &&
          fetchedAt != null &&
          DateTime.now().difference(fetchedAt!) < ttl;
}

/// Hub screen shown from the main Dashboard's "Purchases" tile.
/// Routes into the four purchase sub-modules: Purchases, Purchase Orders,
/// Payment Out, and Purchase Returns.
class PurchasesMenuScreen extends StatefulWidget {
  const PurchasesMenuScreen({super.key});

  @override
  State<PurchasesMenuScreen> createState() => _PurchasesMenuScreenState();
}

class _PurchasesMenuScreenState extends State<PurchasesMenuScreen> {
  String _query = '';
  bool _isLoading = true;
  String? _error;

  // Live summary figures, pulled from Firestore.
  int _purchasesThisMonth = 0;
  int _totalPurchases = 0;
  double _payableToVendors = 0;
  int _pendingOrders = 0;
  int _totalPaymentsOut = 0;
  int _returnsThisMonth = 0;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  /// Dates in this app are stored as 'dd-MM-yyyy' strings (see the date
  /// pickers on the add screens). Parses that format, returns null on
  /// anything unexpected instead of throwing.
  DateTime? _parseDate(String raw) {
    final parts = raw.trim().split('-');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  bool _isThisMonth(String raw) {
    final d = _parseDate(raw);
    if (d == null) return false;
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month;
  }

  Future<void> _loadSummary({bool forceRefresh = false}) async {
    // Serve from cache if it's still fresh — skips 4 full-collection reads.
    if (!forceRefresh && _PurchasesSummaryCache.isFresh) {
      final c = _PurchasesSummaryCache.data!;
      setState(() {
        _totalPurchases = c['totalPurchases'];
        _purchasesThisMonth = c['purchasesThisMonth'];
        _pendingOrders = c['pendingOrders'];
        _returnsThisMonth = c['returnsThisMonth'];
        _totalPaymentsOut = c['totalPaymentsOut'];
        _payableToVendors = c['payableToVendors'];
        _isLoading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        PurchaseService.getAllPurchases(forceRefresh: forceRefresh),
        PurchaseOrderService.getAllPurchaseOrders(forceRefresh: forceRefresh),
        PurchaseReturnService.getAllPurchaseReturns(forceRefresh: forceRefresh),
        PaymentOutService.getAllPaymentOuts(forceRefresh: forceRefresh),
      ]);

      final purchases = results[0] as List;
      final orders = results[1] as List;
      final returns = results[2] as List;
      final payments = results[3] as List;

      final purchasesTotal =
      purchases.fold<double>(0.0, (s, p) => s + (p.cost * p.quantity));
      final returnsTotal =
      returns.fold<double>(0.0, (s, r) => s + r.amount);
      final paymentsTotal =
      payments.fold<double>(0.0, (s, pay) => s + pay.amount);

      if (!mounted) return;
      setState(() {
        _totalPurchases = purchases.length;
        _purchasesThisMonth =
            purchases.where((p) => _isThisMonth(p.purchaseDate)).length;
        _pendingOrders = orders.where((o) => o.status == 'Pending').length;
        _returnsThisMonth =
            returns.where((r) => _isThisMonth(r.returnDate)).length;
        _totalPaymentsOut = payments.length;
        // Outstanding payable = value received from vendors, minus what's
        // already been paid out and minus what's since been returned.
        _payableToVendors =
            (purchasesTotal - returnsTotal - paymentsTotal).clamp(0, double.infinity);
        _isLoading = false;
      });

      // Cache the fresh numbers so the next time this menu opens (very
      // common, since it's a hub screen) we don't re-read 4 collections.
      _PurchasesSummaryCache.data = {
        'totalPurchases': _totalPurchases,
        'purchasesThisMonth': _purchasesThisMonth,
        'pendingOrders': _pendingOrders,
        'returnsThisMonth': _returnsThisMonth,
        'totalPaymentsOut': _totalPaymentsOut,
        'payableToVendors': _payableToVendors,
      };
      _PurchasesSummaryCache.fetchedAt = DateTime.now();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load summary: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allTiles = <_MenuTile>[
      _MenuTile(
        title: 'Purchases',
        subtitle: 'Record stock bought in',
        icon: Icons.shopping_bag_rounded,
        color: AppColors.navy,
        badgeCount: _totalPurchases,
        onTap: () => Navigator.push(
            context, MaterialPageRoute(settings: const RouteSettings(name: 'Purchase List'), builder: (_) => const PurchaseListScreen()))
            .then((_) => _loadSummary(forceRefresh: true)),
      ),
      _MenuTile(
        title: 'Purchase Orders',
        subtitle: 'Orders placed with vendors',
        icon: Icons.assignment_rounded,
        color: const Color(0xFF6C63FF),
        badgeCount: _pendingOrders,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(settings: const RouteSettings(name: 'Purchase Order List'), builder: (_) => const PurchaseOrderListScreen()))
            .then((_) => _loadSummary(forceRefresh: true)),
      ),
      _MenuTile(
        title: 'Payment Out',
        subtitle: 'Payments made to vendors',
        icon: Icons.payments_rounded,
        color: const Color(0xFF00B894),
        badgeCount: _totalPaymentsOut,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(settings: const RouteSettings(name: 'Payment Out List'), builder: (_) => const PaymentOutListScreen()))
            .then((_) => _loadSummary(forceRefresh: true)),
      ),
      _MenuTile(
        title: 'Purchase Returns',
        subtitle: 'Goods returned to vendors',
        icon: Icons.assignment_return_rounded,
        color: const Color(0xFFFF6B6B),
        badgeCount: _returnsThisMonth,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(settings: const RouteSettings(name: 'Purchase Return List'), builder: (_) => const PurchaseReturnListScreen()))
            .then((_) => _loadSummary(forceRefresh: true)),
      ),
    ];

    final tiles = _query.isEmpty
        ? allTiles
        : allTiles
        .where((t) =>
    t.title.toLowerCase().contains(_query.toLowerCase()) ||
        t.subtitle.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Purchases',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Purchase'),
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(settings: const RouteSettings(name: 'Purchase List'), builder: (_) => const PurchaseListScreen()))
            .then((_) => _loadSummary(forceRefresh: true)),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadSummary(forceRefresh: true),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const HeroBanner(
              icon: Icons.storefront_rounded,
              title: 'Purchases Hub',
              subtitle: 'Manage everything you buy from vendors',
            ),
            const SizedBox(height: 16),

            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3F3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF6B6B).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFFF6B6B), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_error!,
                            style: const TextStyle(fontSize: 12, color: Color(0xFFFF6B6B)))),
                    TextButton(onPressed: _loadSummary, child: const Text('Retry')),
                  ],
                ),
              ),

            // Quick stats row — real counts pulled from Firestore
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'This Month',
                    value: _isLoading ? '—' : '$_purchasesThisMonth',
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.navy,
                    loading: _isLoading,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Payable',
                    value: _isLoading
                        ? '—'
                        : '\u20b9${_payableToVendors.toStringAsFixed(0)}',
                    icon: Icons.account_balance_wallet_rounded,
                    color: const Color(0xFF00B894),
                    loading: _isLoading,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search / filter
            TextField(
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(
                  color: AppColors.navy, fontWeight: FontWeight.w500, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search purchase modules...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.teal),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (tiles.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text('No modules match "$_query"',
                      style: TextStyle(color: Colors.grey.shade600)),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 210, // caps card width so it never balloons
                  mainAxisExtent: 140, // fixed, compact card height
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                ),
                itemCount: tiles.length,
                itemBuilder: (context, index) => tiles[index],
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool loading;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: loading
                ? Padding(
              padding: const EdgeInsets.all(9),
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
                : Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A2138))),
                Text(label,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int? badgeCount;

  const _MenuTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  if (badgeCount != null && badgeCount! > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('$badgeCount',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A2138))),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}