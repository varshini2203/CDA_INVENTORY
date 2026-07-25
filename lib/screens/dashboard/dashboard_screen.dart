import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cda_inventory/screens/branches/branch_list_screen.dart';
import 'package:cda_inventory/screens/fixed_products/fixed_product_list_screen.dart';
import 'package:cda_inventory/screens/new_products/new_product_list_screen.dart';
import 'package:cda_inventory/screens/consumables/consumable_list_screen.dart';
import 'package:cda_inventory/screens/drone_tracking/drone_in_out_screen.dart';
import 'package:cda_inventory/screens/stock_management/stock_dashboard_screen.dart';
import 'package:cda_inventory/screens/purchases/purchases_menu_screen.dart';
import 'package:cda_inventory/screens/invoices/invoice_list_screen.dart';
import 'package:cda_inventory/screens/estimates/estimate_list_screen.dart';
import 'package:cda_inventory/screens/search/search_screen.dart';
import 'package:cda_inventory/screens/stock_management/stock_out_screen.dart';
import 'package:cda_inventory/screens/stock_management/stock_history_screen.dart';
import 'package:cda_inventory/screens/profile/profile_screen.dart';
import 'package:cda_inventory/screens/reports/reports_dashboard_screen.dart';
import 'package:cda_inventory/screens/bills/bills_screen.dart';
import 'package:cda_inventory/services/auth_service.dart';
import 'package:cda_inventory/services/access_control_service.dart';
import 'package:cda_inventory/models/app_access_models.dart';
import 'package:cda_inventory/core/access/access_scope.dart';
import 'package:cda_inventory/screens/admin/admin_notifications_screen.dart';
import 'package:cda_inventory/screens/admin/employee_access_screen.dart';
import 'package:cda_inventory/screens/admin/activity_feed_screen.dart';
import 'package:provider/provider.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// 🎨 CDA NAVY DESIGN TOKENS
// ═══════════════════════════════════════════════════════════════════════════════
const _bg          = Color(0xFF050A14);
const _bgDeep      = Color(0xFF030710);
const _surface     = Color(0xFF0A1428);
const _surfaceHigh = Color(0xFF0F1C35);
const _border      = Color(0xFF1A2E50);

const _blue        = Color(0xFF1E5FC8);
const _blueGlow    = Color(0x331E5FC8);
const _blueLight   = Color(0xFF3A7AE8);
const _blueDark    = Color(0xFF0D3A80);

const _silver      = Color(0xFFB8C8DC);
const _white       = Color(0xFFF0F6FF);

const _green       = Color(0xFF00D68F);
const _red         = Color(0xFFE8374A);

const _textPrimary = Color(0xFFF0F6FF);
const _textSub     = Color(0xFFA0B8D0);
const _textMuted   = Color(0xFF4A6080);

// ═══════════════════════════════════════════════════════════════════════════════
// 📦 MODULE DATA
// ═══════════════════════════════════════════════════════════════════════════════
const _modules = [
  {
    'title': 'Fixed Assets',
    'icon': Icons.precision_manufacturing_rounded,
    'emoji': '⚙️',
    'desc': 'Hardware assets',
    'tag': 'ASSETS',
    'color': _blueLight,
    'gradFrom': Color(0xFF0D2348),
    'gradTo': Color(0xFF0A1428),
    'image': 'assets/images/fixed_assets.jpg',
  },
  {
    'title': 'Inventory',
    'icon': Icons.inventory_2_rounded,
    'emoji': '📦',
    'desc': 'Live stock view',
    'tag': 'STOCK',
    'color': _blueLight,
    'gradFrom': Color(0xFF0D2348),
    'gradTo': Color(0xFF0A1428),
    'image': 'assets/images/inventory.jpg',
  },
  {
    'title': 'New Products',
    'icon': Icons.new_releases_rounded,
    'emoji': '🆕',
    'desc': 'Recently added items',
    'tag': 'STOCK',
    'color': _blueLight,
    'gradFrom': Color(0xFF0D2348),
    'gradTo': Color(0xFF0A1428),
    'image': 'assets/images/new_product.png',
  },
  {
    'title': 'Consumables',
    'icon': Icons.category_rounded,
    'emoji': '🔩',
    'desc': 'Supplies & parts',
    'tag': 'STOCK',
    'color': _blueLight,
    'gradFrom': Color(0xFF0D2348),
    'gradTo': Color(0xFF0A1428),
    'image': 'assets/images/consumables.jpg',
  },
  {
    'title': 'Drone In/Out',
    'icon': Icons.flight_takeoff_rounded,
    'emoji': '🚁',
    'desc': 'Flight logs',
    'tag': 'OPS',
    'color': _blueLight,
    'gradFrom': Color(0xFF0D2348),
    'gradTo': Color(0xFF0A1428),
    'image': 'assets/images/drone_in_and_out.jpg',
  },
  {
    'title': 'Drone Services',
    'icon': Icons.miscellaneous_services_rounded,
    'emoji': '🛠️',
    'desc': 'Service & maintenance',
    'tag': 'OPS',
    'color': _blueLight,
    'gradFrom': Color(0xFF0D2348),
    'gradTo': Color(0xFF0A1428),
    'image': 'assets/images/drone services.png',
  },
  {
    'title': 'Stock Management',
    'icon': Icons.analytics_rounded,
    'emoji': '📊',
    'desc': 'Analytics hub',
    'tag': 'MGMT',
    'color': _blueLight,
    'gradFrom': Color(0xFF0D2348),
    'gradTo': Color(0xFF0A1428),
    'image': 'assets/images/stock_management.jpg',
  },
  {
    'title': 'Branch Inventory',
    'icon': Icons.business_rounded,
    'emoji': '🏢',
    'desc': 'Multi-branch',
    'tag': 'MGMT',
    'color': _blueLight,
    'gradFrom': Color(0xFF0D2348),
    'gradTo': Color(0xFF0A1428),
    'image': 'assets/images/branch_inventory.jpg',
  },
  {
    'title': 'Purchases',
    'icon': Icons.shopping_cart_rounded,
    'emoji': '🛒',
    'desc': 'Orders, POs & payments',
    'tag': 'FINANCE',
    'color': _blueLight,
    'gradFrom': Color(0xFF0D2348),
    'gradTo': Color(0xFF0A1428),
    'image': 'assets/images/purchase_list.jpg',
  },
  {
    'title': 'Invoice List',
    'icon': Icons.receipt_long_rounded,
    'emoji': '🧾',
    'desc': 'Billing records',
    'tag': 'FINANCE',
    'color': _blueLight,
    'gradFrom': Color(0xFF0D2348),
    'gradTo': Color(0xFF0A1428),
    'image': 'assets/images/invoice_list.jpg',
  },
  {
    'title': 'Bills',
    'icon': Icons.document_scanner_rounded,
    'emoji': '🧾',
    'desc': 'Scan & store bills',
    'tag': 'FINANCE',
    'color': _blueLight,
    'gradFrom': Color(0xFF0D2348),
    'gradTo': Color(0xFF0A1428),
    'image': 'assets/images/bills.png',
  },
  {
    'title': 'Search Products',
    'icon': Icons.manage_search_rounded,
    'emoji': '🔍',
    'desc': 'Quick lookup',
    'tag': 'TOOLS',
    'color': _blueLight,
    'gradFrom': Color(0xFF0D2348),
    'gradTo': Color(0xFF0A1428),
    'image': 'assets/images/search_products.jpg',
  },
  {
    'title': 'Stock Out',
    'icon': Icons.outbox_rounded,
    'emoji': '📤',
    'desc': 'Issue items',
    'tag': 'OPS',
    'color': _blueLight,
    'gradFrom': Color(0xFF0D2348),
    'gradTo': Color(0xFF0A1428),
    'image': 'assets/images/stock out.jpg',
  },
  {
    'title': 'Stock History',
    'icon': Icons.history_rounded,
    'emoji': '📋',
    'desc': 'Audit trail',
    'tag': 'LOGS',
    'color': _blueLight,
    'gradFrom': Color(0xFF0D2348),
    'gradTo': Color(0xFF0A1428),
    'image': 'assets/images/stock history.jpg',
  },
  {
    'title': 'Reports',
    'icon': Icons.insert_chart_rounded,
    'emoji': '📈',
    'desc': 'Monthly exports',
    'tag': 'REPORTS',
    'color': _blueLight,
    'gradFrom': Color(0xFF0D2348),
    'gradTo': Color(0xFF0A1428),
    'image': 'assets/images/report.png',
  },
];

const _drawerItems = [
  {'icon': Icons.dashboard_rounded,               'label': 'Dashboard',        'key': 'home'},
  {'icon': Icons.precision_manufacturing_rounded, 'label': 'Fixed Assets',     'key': 'Fixed Assets'},
  {'icon': Icons.inventory_2_rounded,             'label': 'Inventory',        'key': 'Inventory'},
  {'icon': Icons.new_releases_rounded,            'label': 'New Products',     'key': 'New Products'},
  {'icon': Icons.category_rounded,                'label': 'Consumables',      'key': 'Consumables'},
  {'icon': Icons.flight_takeoff_rounded,          'label': 'Drone In/Out',     'key': 'Drone In/Out'},
  {'icon': Icons.miscellaneous_services_rounded,  'label': 'Drone Services',   'key': 'Drone Services'},
  {'icon': Icons.analytics_rounded,               'label': 'Stock Management', 'key': 'Stock Management'},
  {'icon': Icons.business_rounded,                'label': 'Branch Inventory', 'key': 'Branch Inventory'},
  {'icon': Icons.shopping_cart_rounded,           'label': 'Purchases',        'key': 'Purchases'},
  {
    'icon': Icons.receipt_long_rounded,
    'label': 'Sales',
    'key': 'Sales',
    'children': [
      {'label': 'Sale Invoices',           'key': 'Sale Invoices'},
      {'label': 'Estimate/ Quotation',     'key': 'Estimate/ Quotation'},
      {'label': 'Proforma Invoice',        'key': 'Proforma Invoice'},
      {'label': 'Payment-In',              'key': 'Payment-In'},
      {'label': 'Sale Order',              'key': 'Sale Order'},
      {'label': 'Delivery Challan',        'key': 'Delivery Challan'},
      {'label': 'Sale Return/ Credit Note','key': 'Sale Return/ Credit Note'},
      {'label': 'Vyapar POS',              'key': 'Vyapar POS'},
    ],
  },
  {'icon': Icons.document_scanner_rounded,        'label': 'Bills',            'key': 'Bills'},
  {'icon': Icons.manage_search_rounded,           'label': 'Search Products',  'key': 'Search Products'},
  {'icon': Icons.outbox_rounded,                  'label': 'Stock Out',        'key': 'Stock Out'},
  {'icon': Icons.history_rounded,                 'label': 'Stock History',    'key': 'Stock History'},
  {'icon': Icons.insert_chart_rounded,             'label': 'Reports',          'key': 'Reports'},
];

// ═══════════════════════════════════════════════════════════════════════════════
// DASHBOARD SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
class DashboardScreen extends StatefulWidget {
  final String userRole;
  const DashboardScreen({super.key, required this.userRole});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _bottomIndex = 0;

  @override
  void initState() {
    super.initState();
    // Spec requirement 5: log dashboard access distinctly from login, so
    // the audit trail shows the user actually made it past any approval
    // gate and reached the app, not just that they authenticated.
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      AccessControlService.logDashboardAccess(uid: user.uid, email: user.email ?? '');
    }
  }

  void _navigate(BuildContext context, String title) {
    Widget? screen;
    switch (title) {
      case 'Fixed Assets':     screen = const FixedProductListScreen(); break;
      case 'New Products':     screen = const NewProductListScreen();   break;
      case 'Consumables':      screen = const ConsumableListScreen();   break;
      case 'Drone In/Out':     screen = const DroneInOutScreen();       break;
      case 'Stock Management': screen = const StockDashboardScreen();   break;
      case 'Branch Inventory': screen = const BranchListScreen();       break;
      case 'Purchases':        screen = const PurchasesMenuScreen();    break;
      case 'Sale Invoices':    screen = const InvoiceListScreen();      break;
      case 'Invoice List':     screen = const InvoiceListScreen();      break;
      case 'Estimate/ Quotation': screen = const EstimateListScreen();  break;
      case 'Bills':            screen = const BillsScreen();            break;
      case 'Search Products':  screen = const SearchScreen();           break;
      case 'Stock Out':        screen = const StockOutScreen();         break;
      case 'Stock History':    screen = const StockHistoryScreen();     break;
      case 'Reports':          screen = const ReportsDashboardScreen(); break;
      case 'Inventory':
        Navigator.pushNamed(context, '/inventory');
        return;
    }
    if (screen != null) {
      Navigator.push(context, MaterialPageRoute(settings: RouteSettings(name: title), builder: (_) => screen!));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _surfaceHigh,
          content: Text('$title — Coming Soon',
              style: const TextStyle(color: _textPrimary)),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.userRole == 'admin';
    return Scaffold(
      backgroundColor: _bg,
      extendBodyBehindAppBar: true,
      appBar: _CDAAppBar(isAdmin: isAdmin),
      drawer: _CDADrawer(
        isAdmin: isAdmin,
        onNavigate: (key) {
          if (key == 'home') return;
          _navigate(context, key);
        },
        onLogout: () async {
          await AuthService.logout();
          if (!context.mounted) return;
          context.read<CurrentAccess>().stopListening();
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('token');
          if (!context.mounted) return;
          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        },
      ),
      body: Stack(
        children: [
          const _CDABackground(),
          SafeArea(
            child: Column(
              children: [
                if (!isAdmin) const ViewOnlyBanner(),
                Expanded(
                  child: _DashboardBody(
                    onNavigate: (title) => _navigate(context, title),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _CDABottomNav(
        currentIndex: _bottomIndex,
        onTap: (i) {
          setState(() => _bottomIndex = i);
          switch (i) {
            case 1: _navigate(context, 'Search Products'); break;
            case 2: _navigate(context, 'Stock Management'); break;
            case 3:
              Navigator.push(context,
                  MaterialPageRoute(settings: const RouteSettings(name: 'Profile'), builder: (_) => const ProfileScreen()));
              break;
          }
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BOTTOM NAV
// ═══════════════════════════════════════════════════════════════════════════════
class _CDABottomNav extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;
  const _CDABottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      {'icon': Icons.home_rounded,      'label': 'Home',    'color': _blue},
      {'icon': Icons.search_rounded,    'label': 'Search',  'color': _blueLight},
      {'icon': Icons.analytics_rounded, 'label': 'Stock',   'color': _blue},
      {'icon': Icons.person_rounded,    'label': 'Profile', 'color': _silver},
    ];
    return Container(
      height: 64 + MediaQuery.of(context).padding.bottom,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: _bgDeep,
        border: const Border(top: BorderSide(color: _border, width: 1)),
        boxShadow: [
          BoxShadow(color: _blue.withOpacity(0.12), blurRadius: 18, offset: const Offset(0, -4)),
        ],
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final item = items[i];
          final selected = currentIndex == i;
          final color = item['color'] as Color;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: selected ? 40 : 32,
                    height: selected ? 32 : 28,
                    decoration: BoxDecoration(
                      color: selected ? color.withOpacity(0.18) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item['icon'] as IconData,
                        color: selected ? color : _textMuted,
                        size: selected ? 20 : 18),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item['label'] as String,
                    style: TextStyle(
                      color: selected ? color : _textMuted,
                      fontSize: 9,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// APP BAR
// ═══════════════════════════════════════════════════════════════════════════════
class _CDAAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isAdmin;
  const _CDAAppBar({this.isAdmin = false});

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_bgDeep.withOpacity(0.97), const Color(0xFF071020).withOpacity(0.95)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        border: const Border(bottom: BorderSide(color: _border, width: 1)),
        boxShadow: [
          BoxShadow(color: _blue.withOpacity(0.18), blurRadius: 20, offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Builder(
              builder: (ctx) => GestureDetector(
                onTap: () => Scaffold.of(ctx).openDrawer(),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _blue.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _blue.withOpacity(0.4), width: 1),
                  ),
                  child: const Icon(Icons.menu_rounded, color: _blueLight, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: _white,
                border: Border.all(color: _blue.withOpacity(0.6), width: 1.5),
                boxShadow: [BoxShadow(color: _blue.withOpacity(0.45), blurRadius: 12)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.asset('assets/images/logo.png', fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                    const Icon(Icons.flight_takeoff_rounded, color: _blue, size: 18)),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Chennai Drone Academy',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: _textPrimary, letterSpacing: 0.2)),
                  Text('Inventory Management',
                      style: TextStyle(fontSize: 9, color: _textMuted,
                          letterSpacing: 0.6, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: _green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _green.withOpacity(0.4), width: 1),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PulseDot(color: _green),
                  SizedBox(width: 4),
                  Text('LIVE', style: TextStyle(color: _green, fontSize: 9,
                      fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                ],
              ),
            ),
            if (isAdmin) ...[
              const SizedBox(width: 8),
              _NotificationBell(),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ADMIN NOTIFICATION BELL — live badge count of pending access requests
// ═══════════════════════════════════════════════════════════════════════════════
class _NotificationBell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      // Pending-employee count, not generic "unread" count — this is the
      // exact metric requirement 4 asks the badge to reflect, and it can
      // never disagree with what the Pending Requests page shows.
      stream: AccessControlService.streamPendingCount(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(settings: const RouteSettings(name: 'Admin Notifications'), builder: (_) => const AdminNotificationsScreen()),
          ),
          child: Tooltip(
            message: 'Notifications ($count)',
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _blue.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _blue.withOpacity(0.4), width: 1),
                  ),
                  child: const Icon(Icons.notifications_rounded, color: _blueLight, size: 18),
                ),
                if (count > 0)
                  Positioned(
                    right: -3,
                    top: -3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: _red,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _bgDeep, width: 1.5),
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ANIMATED BACKGROUND
// ═══════════════════════════════════════════════════════════════════════════════
class _CDABackground extends StatefulWidget {
  const _CDABackground();
  @override
  State<_CDABackground> createState() => _CDABackgroundState();
}

class _CDABackgroundState extends State<_CDABackground> with TickerProviderStateMixin {
  late AnimationController _blob1, _blob2, _particles, _radar, _drone1, _drone2, _drone3;
  final _rng = math.Random(42);
  late final List<_FloatParticle> _sparks;

  @override
  void initState() {
    super.initState();
    _blob1 = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(reverse: true);
    _blob2 = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat(reverse: true);
    _particles = AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat();
    _radar = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _drone1 = AnimationController(vsync: this, duration: const Duration(seconds: 16))..repeat();
    _drone2 = AnimationController(vsync: this, duration: const Duration(seconds: 22))
      ..forward(from: 0.35)
      ..addListener(() { if (_drone2.isCompleted) _drone2.forward(from: 0); });
    _drone3 = AnimationController(vsync: this, duration: const Duration(seconds: 28))
      ..forward(from: 0.65)
      ..addListener(() { if (_drone3.isCompleted) _drone3.forward(from: 0); });
    _sparks = List.generate(20, (i) => _FloatParticle(
      x: _rng.nextDouble(), y: _rng.nextDouble(),
      size: 0.6 + _rng.nextDouble() * 1.4,
      speed: 0.006 + _rng.nextDouble() * 0.012,
      phase: _rng.nextDouble(),
      color: [_blue, _blueLight, _silver, _blueDark, _green][_rng.nextInt(5)],
    ));
  }

  @override
  void dispose() {
    _blob1.dispose(); _blob2.dispose(); _particles.dispose();
    _radar.dispose(); _drone1.dispose(); _drone2.dispose(); _drone3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_blob1, _blob2, _particles, _radar, _drone1, _drone2, _drone3]),
      builder: (_, __) => SizedBox.expand(
        child: CustomPaint(
          painter: _CDABgPainter(
            blob1: _blob1.value, blob2: _blob2.value,
            particles: _particles.value, radar: _radar.value,
            drone1: _drone1.value, drone2: _drone2.value, drone3: _drone3.value,
            sparks: _sparks,
          ),
        ),
      ),
    );
  }
}

class _FloatParticle {
  final double x, y, size, speed, phase;
  final Color color;
  const _FloatParticle({required this.x, required this.y, required this.size,
    required this.speed, required this.phase, required this.color});
}

class _CDABgPainter extends CustomPainter {
  final double blob1, blob2, particles, radar, drone1, drone2, drone3;
  final List<_FloatParticle> sparks;
  _CDABgPainter({required this.blob1, required this.blob2, required this.particles,
    required this.radar, required this.drone1, required this.drone2,
    required this.drone3, required this.sparks});

  @override
  void paint(Canvas canvas, Size sz) {
    canvas.drawRect(Rect.fromLTWH(0, 0, sz.width, sz.height),
        Paint()..shader = const LinearGradient(
          colors: [Color(0xFF030710), Color(0xFF050A14), Color(0xFF040810)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(0, 0, sz.width, sz.height)));

    final grid = Paint()..color = const Color(0xFF0D2040).withOpacity(0.7)..strokeWidth = 0.5;
    for (double x = 0; x < sz.width; x += 32) canvas.drawLine(Offset(x, 0), Offset(x, sz.height), grid);
    for (double y = 0; y < sz.height; y += 32) canvas.drawLine(Offset(0, y), Offset(sz.width, y), grid);

    _drawGlow(canvas, sz, x: sz.width * (0.78 + blob1 * 0.06), y: sz.height * (0.12 + blob1 * 0.06),
        radius: sz.width * 0.40, color: const Color(0xFF1E5FC8), opacity: 0.13);
    _drawGlow(canvas, sz, x: sz.width * (0.10 + blob2 * 0.05), y: sz.height * (0.80 + blob2 * 0.06),
        radius: sz.width * 0.30, color: const Color(0xFF3A7AE8), opacity: 0.08);
    _drawGlow(canvas, sz, x: sz.width * 0.50, y: sz.height * (0.92 + blob1 * 0.03),
        radius: sz.width * 0.25, color: const Color(0xFFB8C8DC), opacity: 0.05);

    _drawRadar(canvas, sz);

    for (final p in sparks) {
      final ay = (p.y + particles * p.speed + p.phase) % 1.0;
      final pulse = 0.25 + math.sin(particles * math.pi * 2 + p.phase * math.pi) * 0.18;
      canvas.drawCircle(Offset(sz.width * p.x, sz.height * ay), p.size * 0.6,
          Paint()..color = p.color.withOpacity(pulse * 0.55));
    }

    _drawBgDrone(canvas, sz, t: drone1, yFrac: 0.20, scale: 0.44, color: const Color(0xFF1E5FC8), rtl: false);
    _drawBgDrone(canvas, sz, t: drone2, yFrac: 0.52, scale: 0.29, color: const Color(0xFF3A7AE8), rtl: true);
    _drawBgDrone(canvas, sz, t: drone3, yFrac: 0.36, scale: 0.21, color: const Color(0xFFB8C8DC), rtl: false);
  }

  void _drawRadar(Canvas canvas, Size sz) {
    final cx = sz.width * 0.88, cy = sz.height * 0.78;
    const maxR = 90.0;
    for (int r = 1; r <= 3; r++) {
      canvas.drawCircle(Offset(cx, cy), maxR * r / 3,
          Paint()..color = const Color(0xFF1E5FC8).withOpacity(0.10)
            ..style = PaintingStyle.stroke..strokeWidth = 0.8);
    }
    final ch = Paint()..color = const Color(0xFF1E5FC8).withOpacity(0.12)..strokeWidth = 0.6;
    canvas.drawLine(Offset(cx - maxR, cy), Offset(cx + maxR, cy), ch);
    canvas.drawLine(Offset(cx, cy - maxR), Offset(cx, cy + maxR), ch);
    final sweepAngle = radar * math.pi * 2;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: maxR),
        sweepAngle - 0.9, 0.9, true,
        Paint()..shader = SweepGradient(
          center: Alignment.center, startAngle: sweepAngle - 0.9, endAngle: sweepAngle,
          colors: [Colors.transparent, const Color(0xFF3A7AE8).withOpacity(0.35)],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: maxR))
          ..style = PaintingStyle.fill);
    canvas.drawLine(Offset(cx, cy),
        Offset(cx + maxR * math.cos(sweepAngle), cy + maxR * math.sin(sweepAngle)),
        Paint()..color = const Color(0xFF3A7AE8).withOpacity(0.5)..strokeWidth = 1.2);
  }

  void _drawGlow(Canvas canvas, Size sz,
      {required double x, required double y, required double radius,
        required Color color, required double opacity}) {
    canvas.drawCircle(Offset(x, y), radius,
        Paint()..shader = RadialGradient(colors: [color.withOpacity(opacity), Colors.transparent])
            .createShader(Rect.fromCircle(center: Offset(x, y), radius: radius)));
  }

  void _drawBgDrone(Canvas canvas, Size sz,
      {required double t, required double yFrac, required double scale,
        required Color color, required bool rtl}) {
    final progress = rtl ? (1.0 - t) : t;
    final x = -sz.width * 0.15 + progress * (sz.width * 1.3);
    final y = sz.height * yFrac + math.sin(t * math.pi * 6) * 12;
    final opacity = _edgeFade(t);
    if (opacity < 0.02) return;
    canvas.save();
    canvas.translate(x, y);
    if (rtl) canvas.scale(-1, 1);
    final arm = Paint()..color = color.withOpacity(opacity * 0.5)..strokeWidth = 2 * scale..strokeCap = StrokeCap.round;
    const len = 28.0;
    for (final angle in [-135.0, 45.0, 135.0, -45.0]) {
      final rad = angle * math.pi / 180;
      final ex = len * scale * math.cos(rad), ey = len * scale * math.sin(rad);
      canvas.drawLine(Offset.zero, Offset(ex, ey), arm);
      canvas.drawCircle(Offset(ex, ey), 7 * scale, Paint()..color = color.withOpacity(opacity * 0.3));
      canvas.save();
      canvas.translate(ex, ey);
      canvas.rotate(t * math.pi * 24 + rad);
      canvas.drawLine(Offset(-10 * scale, 0), Offset(10 * scale, 0),
          Paint()..color = color.withOpacity(opacity * 0.65)..strokeWidth = 1.5 * scale);
      canvas.restore();
    }
    final bp = Path()
      ..moveTo(-12 * scale, -4 * scale)..lineTo(12 * scale, -4 * scale)
      ..lineTo(14 * scale, 0)..lineTo(12 * scale, 4 * scale)
      ..lineTo(-12 * scale, 4 * scale)..lineTo(-14 * scale, 0)..close();
    canvas.drawPath(bp, Paint()..color = color.withOpacity(opacity * 0.5));
    canvas.drawCircle(Offset.zero, 4 * scale, Paint()..color = color.withOpacity(opacity * 0.85));
    for (int i = 1; i <= 6; i++) {
      final tx = rtl ? i * 14.0 * scale : -i * 14.0 * scale;
      canvas.drawCircle(Offset(tx, 0), 2.5 * scale * (1 - i / 7.0),
          Paint()..color = color.withOpacity(opacity * (1 - i / 7.0) * 0.4));
    }
    canvas.restore();
  }

  double _edgeFade(double t) {
    if (t < 0.08) return t / 0.08;
    if (t > 0.92) return (1.0 - t) / 0.08;
    return 1.0;
  }

  @override
  bool shouldRepaint(_CDABgPainter old) => true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// DASHBOARD BODY
// ═══════════════════════════════════════════════════════════════════════════════
class _DashboardBody extends StatefulWidget {
  final void Function(String) onNavigate;
  const _DashboardBody({required this.onNavigate});
  @override
  State<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<_DashboardBody>
    with SingleTickerProviderStateMixin {
  late AnimationController _stagger;

  @override
  void initState() {
    super.initState();
    _stagger = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();
  }

  @override
  void dispose() { _stagger.dispose(); super.dispose(); }

  Animation<double> _s(double start, double end) =>
      CurvedAnimation(parent: _stagger, curve: Interval(start, end, curve: Curves.easeOutCubic));

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: AnimatedBuilder(
            animation: _s(0.0, 0.35),
            builder: (_, child) => Opacity(
              opacity: _s(0.0, 0.35).value,
              child: Transform.translate(
                  offset: Offset(0, 24 * (1 - _s(0.0, 0.35).value)), child: child),
            ),
            child: const _CDALogoBanner(),
          ),
        ),

        SliverToBoxAdapter(
          child: AnimatedBuilder(
            animation: _s(0.05, 0.4),
            builder: (_, child) => Opacity(
              opacity: _s(0.05, 0.4).value,
              child: Transform.translate(
                  offset: Offset(0, 28 * (1 - _s(0.05, 0.4).value)), child: child),
            ),
            child: const _HeroCard(),
          ),
        ),

        SliverToBoxAdapter(
          child: AnimatedBuilder(
            animation: _s(0.25, 0.55),
            builder: (_, child) => Opacity(opacity: _s(0.25, 0.55).value, child: child),
            child: const Padding(
              padding: EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: Row(
                children: [
                  _GlowDot(color: _blue),
                  SizedBox(width: 7),
                  Text('QUICK ACCESS', style: TextStyle(color: _textMuted, fontSize: 10,
                      fontWeight: FontWeight.w700, letterSpacing: 2.0)),
                  SizedBox(width: 8),
                  Expanded(child: Divider(color: _border, height: 1)),
                ],
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const crossAxisCount = 3;
              const crossAxisSpacing = 6.0;
              const padding = 8.0 * 2;
              const labelHeight = 34.0;
              final cardWidth = (constraints.maxWidth - padding - crossAxisSpacing * (crossAxisCount - 1)) / crossAxisCount;
              final cardHeight = cardWidth + labelHeight;
              final aspectRatio = cardWidth / cardHeight;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: crossAxisSpacing,
                    mainAxisSpacing: 6,
                    childAspectRatio: aspectRatio,
                  ),
                  itemCount: _modules.length,
                  itemBuilder: (context, i) {
                    final anim = _s(0.28 + i * 0.025,
                        (0.28 + i * 0.025 + 0.22).clamp(0.0, 1.0));
                    return AnimatedBuilder(
                      animation: anim,
                      builder: (_, child) => Opacity(
                        opacity: anim.value,
                        child: Transform.translate(
                            offset: Offset(0, 16 * (1 - anim.value)), child: child),
                      ),
                      child: _ModuleCard(
                        title: _modules[i]['title'] as String,
                        icon: _modules[i]['icon'] as IconData,
                        emoji: _modules[i]['emoji'] as String,
                        desc: _modules[i]['desc'] as String,
                        tag: _modules[i]['tag'] as String,
                        color: _modules[i]['color'] as Color,
                        gradFrom: _modules[i]['gradFrom'] as Color,
                        gradTo: _modules[i]['gradTo'] as Color,
                        image: _modules[i]['image'] as String,
                        labelHeight: labelHeight,
                        onTap: () => widget.onNavigate(_modules[i]['title'] as String),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),

        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: _bgDeep.withOpacity(0.8),
              border: const Border(top: BorderSide(color: _border, width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flight_takeoff_rounded, color: _blue.withOpacity(0.5), size: 10),
                const SizedBox(width: 5),
                const Text('Chennai Drone Academy  ·  SkyLNK Unmanned Pvt. Ltd.  ·  v2.0',
                    style: TextStyle(color: _textMuted, fontSize: 9.5, letterSpacing: 0.4)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ✨ FLOWING SHINE SYSTEM
// ═══════════════════════════════════════════════════════════════════════════════
class _BannerShineController extends StatefulWidget {
  final Widget Function(BuildContext context, double progress) builder;
  const _BannerShineController({required this.builder});
  @override
  State<_BannerShineController> createState() => _BannerShineControllerState();
}

class _BannerShineControllerState extends State<_BannerShineController>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) => widget.builder(ctx, _ctrl.value),
    );
  }
}

class _ShineLinePainter extends CustomPainter {
  final String text;
  final TextStyle style;
  final double globalProgress;
  final double lineStart;
  final double lineEnd;

  _ShineLinePainter({required this.text, required this.style,
    required this.globalProgress, required this.lineStart, required this.lineEnd});

  @override
  void paint(Canvas canvas, Size size) {
    final baseGrad = const LinearGradient(
      colors: [Color(0xFF2255B0), Color(0xFFB8D4F8), Color(0xFF3A7AE8),
        Color(0xFFD0E8FF), Color(0xFF2255B0)],
      stops: [0.0, 0.25, 0.5, 0.75, 1.0],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final tp = TextPainter(
      text: TextSpan(text: text, style: style.copyWith(foreground: Paint()..shader = baseGrad)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.width);

    final offset = Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2);
    tp.paint(canvas, offset);

    double localT;
    if (globalProgress < lineStart) {
      localT = -0.30;
    } else if (globalProgress > lineEnd) {
      localT = 1.30;
    } else {
      final raw = (globalProgress - lineStart) / (lineEnd - lineStart);
      localT = raw < 0.5 ? 2 * raw * raw : 1 - math.pow(-2 * raw + 2, 2) / 2;
      localT = -0.20 + localT * 1.40;
    }

    const beamHalf = 0.14;
    final cx = localT * size.width;
    final beamRect = Rect.fromLTRB(
      cx - beamHalf * size.width, 0,
      cx + beamHalf * size.width, size.height,
    );

    final beamGrad = LinearGradient(
      colors: [Colors.transparent, Colors.white.withOpacity(0.15),
        Colors.white.withOpacity(0.95), Colors.white.withOpacity(0.15),
        Colors.transparent],
      stops: const [0.0, 0.30, 0.50, 0.70, 1.0],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ).createShader(beamRect);

    final tp2 = TextPainter(
      text: TextSpan(text: text, style: style.copyWith(foreground: Paint()..shader = beamGrad)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.width);

    tp2.paint(canvas, offset);

    if (localT > -0.05 && localT < 1.05) {
      final sparkX = (offset.dx + tp.width * localT).clamp(offset.dx, offset.dx + tp.width);
      final sparkY = offset.dy + tp.height / 2;
      canvas.drawCircle(Offset(sparkX, sparkY), 2.5,
          Paint()..color = Colors.white.withOpacity(0.85)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }
  }

  @override
  bool shouldRepaint(_ShineLinePainter old) => old.globalProgress != globalProgress;
}

class _ShineLine extends StatelessWidget {
  final String text;
  final TextStyle style;
  final double globalProgress;
  final double lineStart;
  final double lineEnd;

  const _ShineLine({required this.text, required this.style,
    required this.globalProgress, required this.lineStart, required this.lineEnd});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ShineLinePainter(text: text, style: style,
          globalProgress: globalProgress, lineStart: lineStart, lineEnd: lineEnd),
      child: Text(text, style: style.copyWith(color: Colors.transparent),
          textAlign: TextAlign.center),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CDA LOGO BANNER
// ═══════════════════════════════════════════════════════════════════════════════
class _CDALogoBanner extends StatefulWidget {
  const _CDALogoBanner();
  @override
  State<_CDALogoBanner> createState() => _CDALogoBannerState();
}

class _CDALogoBannerState extends State<_CDALogoBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, child) => Container(
        margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          // Fallback fill shown while the image loads, or if it's
          // missing — keeps the card looking intentional either way.
          gradient: LinearGradient(
            colors: [
              const Color(0xFF071630).withOpacity(0.98),
              const Color(0xFF040D1C).withOpacity(0.96),
            ],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          border: Border.all(color: _blue.withOpacity(0.28 * _glow.value), width: 1.2),
          boxShadow: [
            BoxShadow(color: _blue.withOpacity(0.22 * _glow.value),
                blurRadius: 28, offset: const Offset(0, 6)),
          ],
        ),
        child: Stack(
          children: [
            // ── Skyline + drones artwork, full-bleed behind the
            // banner content ─────────────────────────────────────
            Positioned.fill(
              child: Image.asset(
                'assets/images/dashboard_hero_banner.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            // ── Dark scrim so the white logo ring, shine-text and
            // pills stay readable over the busy photo ──────────────
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.55),
                      const Color(0xFF040D1C).withOpacity(0.72),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                child: child,
              ),
            ),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(alignment: Alignment.center, children: [
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_blue.withOpacity(0.25), _blue.withOpacity(0.0)],
                ),
              ),
            ),
            Container(
              width: 82, height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                border: Border.all(color: _blue.withOpacity(0.35), width: 1.5),
              ),
            ),
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _white,
                border: Border.all(color: _blue.withOpacity(0.65), width: 2),
                boxShadow: [
                  BoxShadow(color: _blue.withOpacity(0.45), blurRadius: 18, spreadRadius: 2),
                ],
              ),
              child: ClipOval(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Image.asset('assets/images/logo.png', fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                      const Icon(Icons.flight_takeoff_rounded, color: _blue, size: 32)),
                ),
              ),
            ),
          ]),

          const SizedBox(height: 14),

          _BannerShineController(
            builder: (_, progress) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                _ShineLine(
                  text: 'CHENNAI DRONE ACADEMY',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                    height: 1.1,
                    color: _blueLight,
                  ),
                  globalProgress: progress,
                  lineStart: 0.02,
                  lineEnd: 0.58,
                ),

                const SizedBox(height: 6),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20, height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, _blue.withOpacity(0.6)],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    Flexible(
                      child: _ShineLine(
                        text: 'SKYLNK UNMANNED PVT. LTD.',
                        style: const TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.6,
                          color: _textMuted,
                        ),
                        globalProgress: progress,
                        lineStart: 0.52,
                        lineEnd: 0.98,
                      ),
                    ),

                    const SizedBox(width: 6),
                    Container(
                      width: 20, height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_blue.withOpacity(0.6), Colors.transparent],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: const [
              _Pill(label: 'System Online', color: _green,     icon: Icons.check_circle_rounded),
              _Pill(label: 'Inventory v2.0', color: _blue,     icon: Icons.inventory_2_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HERO CARD
// ═══════════════════════════════════════════════════════════════════════════════
class _HeroCard extends StatefulWidget {
  const _HeroCard();
  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> {
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _tick();
    // NOTE: the user's display name used to be fetched with a dedicated
    // AuthService.getUserProfile() Firestore get() every time this widget
    // was created (i.e. every time the Dashboard opened/rebuilt). The same
    // users/{uid} document is already kept live in CurrentAccess (see
    // core/access/access_scope.dart), populated once right after login, so
    // the name is now read from there in build() instead — zero extra reads.
  }

  void _tick() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _tick();
    });
  }

  String _formattedDate() {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const days   = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    return '${days[_now.weekday - 1]}, ${_now.day} ${months[_now.month - 1]} ${_now.year}';
  }

  String _formattedTime() {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    final s = _now.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    // Sourced from the already-live CurrentAccess stream (populated once
    // at login) instead of a dedicated Firestore read for this widget.
    final access = context.watch<CurrentAccess>().access;
    final rawName = access?.name;
    final nameLoaded = access != null;
    final userName = (rawName != null && rawName.trim().isNotEmpty)
        ? rawName.trim()
        : 'User';
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [const Color(0xFF081830).withOpacity(0.97),
            const Color(0xFF050E1E).withOpacity(0.95)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        border: Border.all(color: _blue.withOpacity(0.30), width: 1),
        boxShadow: [BoxShadow(color: _blue.withOpacity(0.18), blurRadius: 22, offset: const Offset(0, 6))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            flex: 3,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, color: _white,
                    border: Border.all(color: _blue.withOpacity(0.5), width: 1.5),
                    boxShadow: [BoxShadow(color: _blue.withOpacity(0.35), blurRadius: 10)],
                  ),
                  child: ClipOval(
                    child: Image.asset('assets/images/logo.png', fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                            child: Text('A', style: TextStyle(color: _blue,
                                fontSize: 16, fontWeight: FontWeight.w800)))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    nameLoaded
                        ? Text('Welcome back, $userName',
                        style: const TextStyle(color: _textPrimary, fontSize: 14,
                            fontWeight: FontWeight.w700, letterSpacing: 0.1))
                        : const SizedBox(
                        height: 16,
                        width: 120,
                        child: LinearProgressIndicator(
                          minHeight: 2,
                          backgroundColor: Colors.transparent,
                          color: _blueLight,
                        )),
                    Text(_formattedDate(),
                        style: const TextStyle(color: _textMuted, fontSize: 9.5)),
                  ]),
                ),
              ]),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _blue.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _blue.withOpacity(0.25), width: 1),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.access_time_rounded, color: _blueLight, size: 13),
                  const SizedBox(width: 5),
                  Text(_formattedTime(),
                      style: const TextStyle(color: _blueLight, fontSize: 15,
                          fontWeight: FontWeight.w800, letterSpacing: 1.5,
                          fontFeatures: [FontFeature.tabularFigures()])),
                ]),
              ),
              const SizedBox(height: 10),
              const Wrap(
                spacing: 6,
                children: [
                  _Pill(label: 'System Online', color: _green, icon: Icons.check_circle_rounded),
                ],
              ),
            ]),
          ),
          const SizedBox(width: 10),
          const SizedBox(width: 80, height: 90, child: _FgDrone()),
        ]),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _Pill({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 9),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(color: color, fontSize: 9,
            fontWeight: FontWeight.w600, letterSpacing: 0.3)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FOREGROUND ANIMATED DRONE
// ═══════════════════════════════════════════════════════════════════════════════
class _FgDrone extends StatefulWidget {
  const _FgDrone();
  @override
  State<_FgDrone> createState() => _FgDroneState();
}

class _FgDroneState extends State<_FgDrone> with TickerProviderStateMixin {
  late AnimationController _hover, _prop, _drift, _bank;
  late Animation<double> _hoverY, _driftX, _propSpin, _bankAngle;

  @override
  void initState() {
    super.initState();
    _hover = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _hoverY = Tween<double>(begin: -7.0, end: 7.0)
        .animate(CurvedAnimation(parent: _hover, curve: Curves.easeInOut));
    _prop = AnimationController(vsync: this, duration: const Duration(milliseconds: 220))..repeat();
    _propSpin = Tween<double>(begin: 0.0, end: math.pi * 2).animate(_prop);
    _drift = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat(reverse: true);
    _driftX = Tween<double>(begin: -6.0, end: 6.0)
        .animate(CurvedAnimation(parent: _drift, curve: Curves.easeInOut));
    _bank = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _bankAngle = Tween<double>(begin: 0.0, end: 0.16)
        .animate(CurvedAnimation(parent: _bank, curve: Curves.easeInOut));
    _scheduleTilt();
  }

  void _scheduleTilt() {
    Future.delayed(const Duration(seconds: 7), () {
      if (!mounted) return;
      _bank.forward().then((_) => _bank.reverse().then((_) => _scheduleTilt()));
    });
  }

  @override
  void dispose() {
    _hover.dispose(); _prop.dispose(); _drift.dispose(); _bank.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_hover, _prop, _drift, _bank]),
      builder: (_, __) => Transform.translate(
        offset: Offset(_driftX.value, _hoverY.value),
        child: Transform.rotate(angle: _bankAngle.value,
            child: CustomPaint(size: const Size(80, 90),
                painter: _FgDronePainter(propAngle: _propSpin.value))),
      ),
    );
  }
}

class _FgDronePainter extends CustomPainter {
  final double propAngle;
  _FgDronePainter({required this.propAngle});

  @override
  void paint(Canvas canvas, Size sz) {
    final cx = sz.width / 2, cy = sz.height / 2;
    canvas.drawCircle(Offset(cx, cy + 8), 16,
        Paint()..shader = RadialGradient(
          colors: [const Color(0xFF1E5FC8).withOpacity(0.40), Colors.transparent],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy + 8), radius: 16)));

    const armAngles = [-135.0, 45.0, 135.0, -45.0];
    for (final deg in armAngles) {
      final rad = deg * math.pi / 180;
      final ex = cx + 24 * math.cos(rad), ey = cy + 24 * math.sin(rad);
      canvas.drawLine(Offset(cx, cy), Offset(ex, ey),
          Paint()..color = const Color(0xFF0D2A50)..strokeWidth = 2.8..strokeCap = StrokeCap.round);
      canvas.drawCircle(Offset(ex, ey), 7,
          Paint()..color = const Color(0xFF1E5FC8).withOpacity(0.30)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawCircle(Offset(ex, ey), 5.5, Paint()..color = const Color(0xFF0A1E3D));
      canvas.drawCircle(Offset(ex, ey), 5.5,
          Paint()..color = const Color(0xFF1E5FC8).withOpacity(0.6)
            ..style = PaintingStyle.stroke..strokeWidth = 1);
      canvas.save();
      canvas.translate(ex, ey);
      canvas.rotate(propAngle + rad);
      canvas.drawLine(const Offset(-10, 0), const Offset(10, 0),
          Paint()..color = const Color(0xFF1E5FC8).withOpacity(0.80)
            ..strokeWidth = 1.8..strokeCap = StrokeCap.round);
      canvas.drawLine(const Offset(0, -10), const Offset(0, 10),
          Paint()..color = const Color(0xFF3A7AE8).withOpacity(0.60)
            ..strokeWidth = 1.8..strokeCap = StrokeCap.round);
      canvas.restore();
    }

    final bodyPath = Path()
      ..moveTo(cx - 13, cy - 5)..lineTo(cx + 13, cy - 5)
      ..lineTo(cx + 15, cy)..lineTo(cx + 13, cy + 5)
      ..lineTo(cx - 13, cy + 5)..lineTo(cx - 15, cy)..close();
    canvas.drawPath(bodyPath, Paint()..shader = const LinearGradient(
        colors: [Color(0xFF1A3A6A), Color(0xFF0A1E3D)],
        begin: Alignment.topLeft, end: Alignment.bottomRight)
        .createShader(Rect.fromCenter(center: Offset(cx, cy), width: 30, height: 12)));
    canvas.drawPath(bodyPath,
        Paint()..color = const Color(0xFF1E5FC8).withOpacity(0.40)
          ..style = PaintingStyle.stroke..strokeWidth = 1);

    canvas.drawCircle(Offset(cx, cy), 4.5,
        Paint()..color = const Color(0xFF1E5FC8).withOpacity(0.90)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawCircle(Offset(cx, cy), 3, Paint()..color = const Color(0xFF3A7AE8));
    canvas.drawCircle(Offset(cx, cy), 1.5, Paint()..color = Colors.white.withOpacity(0.95));
  }

  @override
  bool shouldRepaint(_FgDronePainter o) => o.propAngle != propAngle;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MODULE CARD
// ═══════════════════════════════════════════════════════════════════════════════
class _ModuleCard extends StatefulWidget {
  final String title, desc, tag, emoji, image;
  final IconData icon;
  final Color color, gradFrom, gradTo;
  final double labelHeight;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.title, required this.icon, required this.emoji,
    required this.desc, required this.tag, required this.color,
    required this.gradFrom, required this.gradTo, required this.image,
    required this.labelHeight, required this.onTap,
  });

  @override
  State<_ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<_ModuleCard> with TickerProviderStateMixin {
  late final AnimationController _press;
  late final AnimationController _sweep;
  late final Animation<double> _scale;
  late final Animation<double> _sweepAnim;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(vsync: this, duration: const Duration(milliseconds: 90));
    _scale = Tween<double>(begin: 1.0, end: 0.93)
        .animate(CurvedAnimation(parent: _press, curve: Curves.easeOut));
    _sweep = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _sweepAnim = Tween<double>(begin: -0.35, end: 1.35)
        .animate(CurvedAnimation(parent: _sweep, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _press.dispose(); _sweep.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) { setState(() => _hovered = true); _sweep.forward(from: 0); },
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => _press.forward(),
        onTapUp: (_) => _press.reverse(),
        onTapCancel: () => _press.reverse(),
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _hovered ? widget.color.withOpacity(0.55) : _border.withOpacity(0.7),
                  width: 1),
              boxShadow: _hovered
                  ? [BoxShadow(color: widget.color.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4))]
                  : [BoxShadow(color: Colors.black.withOpacity(0.30), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  AnimatedBuilder(
                    animation: _sweepAnim,
                    builder: (_, __) {
                      if (!_sweep.isAnimating) return const SizedBox.shrink();
                      return Positioned.fill(
                        child: ShaderMask(
                          shaderCallback: (b) => LinearGradient(
                            begin: Alignment(_sweepAnim.value - 0.5, -1),
                            end: Alignment(_sweepAnim.value + 0.5, 1),
                            colors: [Colors.transparent, widget.color.withOpacity(0.18), Colors.transparent],
                          ).createShader(b),
                          blendMode: BlendMode.srcOver,
                          child: Container(color: _white.withOpacity(0.06)),
                        ),
                      );
                    },
                  ),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Stack(fit: StackFit.expand, children: [
                          Image.asset(widget.image, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [widget.color.withOpacity(0.20), widget.gradFrom],
                                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Center(child: Icon(widget.icon,
                                    color: widget.color.withOpacity(0.5), size: 22)),
                              )),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.black.withOpacity(0.55), Colors.transparent],
                                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                                  stops: const [0.0, 0.55],
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                              child: Container(color: widget.color.withOpacity(_hovered ? 0.15 : 0.04))),
                          Positioned(
                            top: 0, left: 0, right: 0,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200), height: 2,
                              decoration: BoxDecoration(gradient: LinearGradient(
                                colors: _hovered
                                    ? [widget.color, widget.color.withOpacity(0.0)]
                                    : [widget.color.withOpacity(0.50), Colors.transparent],
                              )),
                            ),
                          ),
                          Positioned(
                            top: 4, right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.50),
                                  borderRadius: BorderRadius.circular(4)),
                              child: Text(widget.emoji, style: const TextStyle(fontSize: 10)),
                            ),
                          ),
                          Positioned(
                            top: 4, left: 4,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                color: widget.color.withOpacity(_hovered ? 0.70 : 0.50),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: widget.color.withOpacity(0.6), width: 1),
                              ),
                              child: Icon(widget.icon, color: Colors.white, size: 12),
                            ),
                          ),
                        ]),
                      ),

                      SizedBox(
                        height: widget.labelHeight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          color: widget.gradFrom,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(widget.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _hovered ? _textPrimary : _textSub,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w700,
                                      height: 1.1,
                                    )),
                              ),
                              const SizedBox(width: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                decoration: BoxDecoration(
                                  color: widget.color.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(color: widget.color.withOpacity(0.25), width: 0.5),
                                ),
                                child: Text(widget.tag, style: TextStyle(
                                    color: widget.color, fontSize: 6,
                                    fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                              ),
                              const SizedBox(width: 2),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                transform: Matrix4.translationValues(_hovered ? 2 : 0, 0, 0),
                                child: Icon(Icons.arrow_forward_rounded,
                                    color: widget.color.withOpacity(_hovered ? 0.9 : 0.3), size: 9),
                              ),
                            ],
                          ),
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

// ═══════════════════════════════════════════════════════════════════════════════
// CDA DRAWER
// ═══════════════════════════════════════════════════════════════════════════════
class _CDADrawer extends StatefulWidget {
  final void Function(String) onNavigate;
  final VoidCallback onLogout;
  final bool isAdmin;
  const _CDADrawer({required this.onNavigate, required this.onLogout, this.isAdmin = false});
  @override
  State<_CDADrawer> createState() => _CDADrawerState();
}

class _CDADrawerState extends State<_CDADrawer> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 480))..forward();
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF040810),
      child: Stack(
        children: [
          // ── Drone / sunset skyline artwork, full-bleed behind the
          // entire drawer (header + nav list + logout) ────────────────
          Positioned.fill(
            child: Image.asset(
              'assets/images/side_navigation.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          // ── Dark scrim over the full height so nav labels, pills and
          // icons stay readable over the artwork ───────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF040810).withOpacity(0.55),
                    const Color(0xFF040810).withOpacity(0.72),
                    const Color(0xFF040810).withOpacity(0.85),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 16, 16, 16),
                decoration: BoxDecoration(
                  // Was an opaque navy gradient that fully hid the background
                  // artwork behind the header. Lightened to a faint tint so
                  // the drone/skyline image reads through while the divider
                  // line still separates the header from the nav list below.
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF060E20).withOpacity(0.40),
                      const Color(0xFF0A1830).withOpacity(0.32),
                    ],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  border: const Border(bottom: BorderSide(color: _border, width: 1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle, color: _white,
                          border: Border.all(color: _blue.withOpacity(0.60), width: 2),
                          boxShadow: [BoxShadow(color: _blue.withOpacity(0.45), blurRadius: 14)],
                        ),
                        child: ClipOval(
                          child: Padding(
                            padding: const EdgeInsets.all(5),
                            child: Image.asset('assets/images/logo.png', fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                const Icon(Icons.flight_takeoff_rounded, color: _blue, size: 24)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Chennai Drone Academy',
                              style: TextStyle(color: _textPrimary, fontSize: 13,
                                  fontWeight: FontWeight.w700, letterSpacing: 0.2)),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  colors: [_blue.withOpacity(0.20), _blueLight.withOpacity(0.10)]),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _blue.withOpacity(0.40), width: 1),
                            ),
                            child: const Text('SkyLNK Unmanned Pvt. Ltd.',
                                style: TextStyle(color: _silver, fontSize: 9,
                                    fontWeight: FontWeight.w600, letterSpacing: 0.6)),
                          ),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    const Wrap(spacing: 6, children: [
                      _Pill(label: 'System Online', color: _green, icon: Icons.check_circle_rounded),
                      _Pill(label: 'v2.0', color: _blue, icon: Icons.inventory_2_rounded),
                    ]),
                  ],
                ),
              ),

              Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      ...List.generate(_drawerItems.length, (i) {
                        final item = _drawerItems[i];
                        final start = (i * 0.055).clamp(0.0, 0.85);
                        final end   = (start + 0.32).clamp(0.0, 1.0);
                        final anim  = CurvedAnimation(parent: _c,
                            curve: Interval(start, end, curve: Curves.easeOutCubic));
                        final children = item['children'] as List<Map<String, String>>?;
                        final child = (children != null && children.isNotEmpty)
                            ? _ExpandableDrawerNavItem(
                          icon: item['icon'] as IconData,
                          label: item['label'] as String,
                          children: children,
                          onNavigateChild: (key) {
                            Navigator.pop(context);
                            widget.onNavigate(key);
                          },
                        )
                            : _DrawerNavItem(
                          icon: item['icon'] as IconData,
                          label: item['label'] as String,
                          isHome: item['key'] == 'home',
                          onTap: () {
                            Navigator.pop(context);
                            widget.onNavigate(item['key'] as String);
                          },
                        );
                        return AnimatedBuilder(
                          animation: anim,
                          builder: (_, c) => Opacity(opacity: anim.value,
                              child: Transform.translate(
                                  offset: Offset(-22 * (1 - anim.value), 0), child: c)),
                          child: child,
                        );
                      }),
                      if (widget.isAdmin) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
                          child: Text('ADMIN CONTROLS',
                              style: TextStyle(color: _textMuted, fontSize: 10,
                                  fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                        ),
                        _DrawerNavItem(
                          icon: Icons.notifications_active_rounded,
                          label: 'Access Requests',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context,
                                MaterialPageRoute(settings: const RouteSettings(name: 'Admin Notifications'), builder: (_) => const AdminNotificationsScreen()));
                          },
                        ),
                        _DrawerNavItem(
                          icon: Icons.manage_accounts_rounded,
                          label: 'Manage Employees',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context,
                                MaterialPageRoute(settings: const RouteSettings(name: 'Employee Access'), builder: (_) => const EmployeeAccessScreen()));
                          },
                        ),
                        _DrawerNavItem(
                          icon: Icons.timeline_rounded,
                          label: 'Live Activity Feed',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context,
                                MaterialPageRoute(settings: const RouteSettings(name: 'Activity Feed'), builder: (_) => const ActivityFeedScreen()));
                          },
                        ),
                      ],
                    ],
                  )
              ),

              Container(
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: _border))),
                child: _DrawerNavItem(
                  icon: Icons.logout_rounded, label: 'Logout', isLogout: true,
                  onTap: () { Navigator.pop(context); widget.onLogout(); },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DRAWER NAV ITEM
// ═══════════════════════════════════════════════════════════════════════════════
class _DrawerNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isHome, isLogout;
  final VoidCallback onTap;
  const _DrawerNavItem({required this.icon, required this.label,
    required this.onTap, this.isHome = false, this.isLogout = false});
  @override
  State<_DrawerNavItem> createState() => _DrawerNavItemState();
}

class _DrawerNavItemState extends State<_DrawerNavItem> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final color = widget.isLogout ? _red : _blue;
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: _h ? color.withOpacity(0.14) : (widget.isHome ? color.withOpacity(0.08) : Colors.transparent),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: _h ? color.withOpacity(0.40) : Colors.transparent, width: 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: widget.onTap,
          splashColor: color.withOpacity(0.12),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160), width: 30, height: 30,
                decoration: BoxDecoration(
                  color: _h ? color.withOpacity(0.22) : color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _h ? [BoxShadow(color: color.withOpacity(0.30), blurRadius: 6)] : null,
                ),
                child: Icon(widget.icon, color: color, size: 15),
              ),
              const SizedBox(width: 12),
              Text(widget.label, style: TextStyle(
                  color: _h ? color : _textSub, fontSize: 13,
                  fontWeight: _h ? FontWeight.w600 : FontWeight.w400)),
              const Spacer(),
              if (_h) Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.6), size: 15),
            ]),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EXPANDABLE DRAWER NAV ITEM (parent with sub-items, e.g. "Sales")
// ═══════════════════════════════════════════════════════════════════════════════
class _ExpandableDrawerNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final List<Map<String, String>> children;
  final void Function(String key) onNavigateChild;
  const _ExpandableDrawerNavItem({
    required this.icon,
    required this.label,
    required this.children,
    required this.onNavigateChild,
  });
  @override
  State<_ExpandableDrawerNavItem> createState() => _ExpandableDrawerNavItemState();
}

class _ExpandableDrawerNavItemState extends State<_ExpandableDrawerNavItem> {
  bool _h = false;
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    const color = _blue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _h = true),
          onExit: (_) => setState(() => _h = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: _h || _open ? color.withOpacity(0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: _h || _open ? color.withOpacity(0.40) : Colors.transparent, width: 1),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: () => setState(() => _open = !_open),
              splashColor: color.withOpacity(0.12),
              highlightColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160), width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: _h || _open ? color.withOpacity(0.22) : color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _h || _open ? [BoxShadow(color: color.withOpacity(0.30), blurRadius: 6)] : null,
                    ),
                    child: Icon(widget.icon, color: color, size: 15),
                  ),
                  const SizedBox(width: 12),
                  Text(widget.label, style: TextStyle(
                      color: _h || _open ? color : _textSub, fontSize: 13,
                      fontWeight: _h || _open ? FontWeight.w600 : FontWeight.w400)),
                  const Spacer(),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: _open ? 0.25 : 0.0,
                    child: Icon(Icons.chevron_right_rounded,
                        color: color.withOpacity(_h || _open ? 0.9 : 0.5), size: 15),
                  ),
                ]),
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _open ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Column(
              children: widget.children.map((c) => _DrawerSubNavItem(
                label: c['label']!,
                onTap: () => widget.onNavigateChild(c['key']!),
              )).toList(),
            ),
          ),
          secondChild: const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _DrawerSubNavItem extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _DrawerSubNavItem({required this.label, required this.onTap});
  @override
  State<_DrawerSubNavItem> createState() => _DrawerSubNavItemState();
}

class _DrawerSubNavItemState extends State<_DrawerSubNavItem> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    const color = _blueLight;
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
        decoration: BoxDecoration(
          color: _h ? color.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: widget.onTap,
          splashColor: color.withOpacity(0.10),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              Container(
                width: 5, height: 5,
                decoration: BoxDecoration(
                  color: _h ? color : _textMuted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(widget.label, style: TextStyle(
                    color: _h ? color : _textSub, fontSize: 12.5,
                    fontWeight: _h ? FontWeight.w600 : FontWeight.w400)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED TINY WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
    _a = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _a,
    child: Container(width: 7, height: 7,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: widget.color.withOpacity(0.7), blurRadius: 5)])),
  );
}

class _GlowDot extends StatelessWidget {
  final Color color;
  const _GlowDot({required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: 6, height: 6,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withOpacity(0.7), blurRadius: 5)]),
  );
}