import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';

import 'package:cda_inventory/screens/inventory/inventory_dashboard.dart';

import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/waiting_approval_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/bills/bills_screen.dart';
import 'screens/admin/admin_notifications_screen.dart';
import 'screens/admin/employee_access_screen.dart';
import 'screens/admin/activity_feed_screen.dart';

import 'providers/bills_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';

import 'core/access/access_scope.dart';
import 'core/access/access_route_observer.dart';
import 'services/drone_reminder_service.dart';

// Flutter's default scroll behavior only lets touch/stylus drag a
// scrollable — a mouse click-and-drag is deliberately excluded, which is
// why every list in the app (including the Live Activity Feed) looked
// scrollable but didn't respond to a mouse drag when running on web or
// desktop Chrome. Only the mouse wheel worked. Adding PointerDeviceKind
// .mouse to dragDevices here fixes drag-to-scroll app-wide in one place,
// instead of patching every individual screen.
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Local notifications used for the "did you forget to bring the drone
  // back?" 1-hour reminder — see lib/services/drone_reminder_service.dart.
  await DroneReminderService.instance.init();

  runApp(const ChennaiDroneInventoryApp());
}

class ChennaiDroneInventoryApp extends StatelessWidget {
  const ChennaiDroneInventoryApp({super.key});

  // Created ONCE per app lifetime, not once per rebuild. MaterialApp is
  // rebuilt every time ThemeProvider notifies its Consumer below (e.g. a
  // dark-mode toggle) — if AccessRouteObserver() were instantiated inline
  // in that build() method, every one of those rebuilds silently swapped
  // in a brand-new observer with empty `_lastLabel` / `_lastLoggedAt`
  // state, which defeated its own duplicate-visit throttle and let the
  // same screen get logged repeatedly in quick succession.
  static final AccessRouteObserver _accessRouteObserver = AccessRouteObserver();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BillsProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        // Live "who am I / what can I edit" state, populated right after
        // login and read by EditGuard / ViewOnlyBanner / admin screens
        // anywhere in the widget tree.
        ChangeNotifierProvider(create: (_) => CurrentAccess()),
        // If you already have other ChangeNotifierProviders declared
        // elsewhere (e.g. wrapping DashboardScreen), move them into this
        // list too so there's a single MultiProvider at the app root.
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Chennai Drone Academy Inventory',
            theme: themeProvider.themeData,
            scrollBehavior: AppScrollBehavior(),
            // Logs every screen push app-wide so the admin's Live Activity
            // Feed sees "whatever happens in the app" without needing to
            // instrument each of the 100+ individual screens by hand.
            navigatorObservers: [_accessRouteObserver],
            initialRoute: '/',
            routes: {
              '/': (context) => const SplashScreen(),
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/dashboard': (context) {
                // Role is passed as a route argument by login_screen.dart /
                // waiting_approval_screen.dart / splash_screen.dart after
                // they've resolved it from Firestore via AuthService /
                // AccessControlService.
                // Defaulting to 'employee' (not 'admin') is the safe
                // fallback if anything ever navigates here without an
                // argument.
                final role =
                ModalRoute.of(context)?.settings.arguments as String?;
                return DashboardScreen(userRole: role ?? 'employee');
              },
              '/inventory': (context) => const InventoryDashboard(),
              '/bills': (context) => const BillsScreen(),
              '/waiting-approval': (context) => const WaitingApprovalScreen(),
              '/admin/notifications': (context) =>
              const AdminGuard(child: AdminNotificationsScreen()),
              '/admin/employees': (context) =>
              const AdminGuard(child: EmployeeAccessScreen()),
              '/admin/activity': (context) =>
              const AdminGuard(child: ActivityFeedScreen()),
            },
            // Several screens (Employee Access / "Manage Employees",
            // Admin Notifications / "Pending Requests", Waiting Approval,
            // Add Invoice, Stock In/Out, etc.) are opened with
            // Navigator.push(MaterialPageRoute(settings: RouteSettings(name: '...')))
            // purely so the Activity Feed can log a human-readable screen
            // name. Those names ('Employee Access', 'Admin Notifications', ...)
            // are NOT entries in the `routes` table above.
            //
            // On mobile that's harmless — the route name is never used to
            // reload anything. On Flutter Web it becomes the browser's URL
            // fragment (e.g. #Employee%20Access), and hitting refresh makes
            // Flutter try to look that name up in `routes` directly. Since
            // it isn't there, and there was previously no fallback, the app
            // got stuck on a blank/loading screen forever.
            //
            // onUnknownRoute is the fallback for exactly this case: any
            // route name that doesn't match `routes` and isn't handled by
            // onGenerateRoute lands here. We send the user back through
            // SplashScreen, which already knows how to check auth state and
            // redirect to the correct place (dashboard / waiting-approval /
            // login), so a refresh on any of these screens now recovers
            // instead of hanging.
            onUnknownRoute: (settings) {
              return MaterialPageRoute(
                settings: settings,
                builder: (context) => const SplashScreen(),
              );
            },
          );
        },
      ),
    );
  }
}