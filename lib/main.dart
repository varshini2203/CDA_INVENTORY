import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'services/drone_service_alert_service.dart';
import 'services/push_notification_service.dart';

import 'widgets/in_app_notification_banner.dart';


// ============================================================
// APP SCROLL BEHAVIOR
// ============================================================
//
// Flutter's default scroll behavior allows touch/stylus dragging,
// but mouse drag scrolling is not enabled by default.
//
// This enables mouse dragging for scrollable widgets across the
// entire application, which is useful when running the application
// on Windows desktop or Flutter Web.
//

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
  };
}


// ============================================================
// MAIN
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ----------------------------------------------------------
  // FIREBASE
  // ----------------------------------------------------------

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ----------------------------------------------------------
  // FIRESTORE
  // ----------------------------------------------------------
  //
  // Some networks, VPNs, proxies and Wi-Fi configurations can
  // interfere with Firestore's preferred WebChannel / QUIC
  // transport.
  //
  // This allows Firestore Web to automatically fall back to
  // long-polling when required.
  //

  FirebaseFirestore.instance.settings = const Settings(
    webExperimentalAutoDetectLongPolling: true,
  );

  // ----------------------------------------------------------
  // PUSH NOTIFICATIONS
  // ----------------------------------------------------------
  //
  // PushNotificationService now contains Windows initialization
  // settings for flutter_local_notifications.
  //
  // On Android/iOS:
  //   Firebase Cloud Messaging is initialized.
  //
  // On Windows:
  //   Windows local notification settings are initialized.
  //   FCM-specific Android/iOS operations are skipped.
  //

  await PushNotificationService.instance.init();

  // ----------------------------------------------------------
  // DRONE REMINDER NOTIFICATIONS
  // ----------------------------------------------------------
  //
  // Initializes the local notification service responsible for
  // the "did you forget to bring the drone back?" reminder.
  //

  await DroneReminderService.instance.init();

  // ----------------------------------------------------------
  // DRONE SERVICE ALERTS
  // ----------------------------------------------------------
  //
  // Initializes alerts for drones whose scheduled service date
  // has passed.
  //

  await DroneServiceAlertService.instance.init();

  // ----------------------------------------------------------
  // START APPLICATION
  // ----------------------------------------------------------

  runApp(
    const ChennaiDroneInventoryApp(),
  );
}


// ============================================================
// MAIN APPLICATION
// ============================================================

class ChennaiDroneInventoryApp extends StatelessWidget {
  const ChennaiDroneInventoryApp({
    super.key,
  });

  // Created ONCE for the entire application lifetime.
  //
  // This prevents the AccessRouteObserver from being recreated
  // every time ThemeProvider causes MaterialApp to rebuild.
  //
  // The observer maintains its own state for preventing duplicate
  // activity-feed entries.
  static final AccessRouteObserver _accessRouteObserver =
  AccessRouteObserver();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ------------------------------------------------------
        // BILLS
        // ------------------------------------------------------

        ChangeNotifierProvider(
          create: (_) => BillsProvider(),
        ),

        // ------------------------------------------------------
        // THEME
        // ------------------------------------------------------

        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),

        // ------------------------------------------------------
        // LANGUAGE
        // ------------------------------------------------------

        ChangeNotifierProvider(
          create: (_) => LanguageProvider(),
        ),

        // ------------------------------------------------------
        // ACCESS CONTROL
        // ------------------------------------------------------
        //
        // Keeps track of the logged-in user's access level.
        //

        ChangeNotifierProvider(
          create: (_) => CurrentAccess(),
        ),
      ],

      child: Consumer<ThemeProvider>(
        builder: (
            context,
            themeProvider,
            _,
            ) {
          return MaterialApp(
            // --------------------------------------------------
            // BASIC APP SETTINGS
            // --------------------------------------------------

            debugShowCheckedModeBanner: false,

            title: 'Chennai Drone Academy Inventory',

            // --------------------------------------------------
            // THEME
            // --------------------------------------------------

            theme: themeProvider.themeData,

            // --------------------------------------------------
            // SCROLL BEHAVIOR
            // --------------------------------------------------

            scrollBehavior: AppScrollBehavior(),

            // --------------------------------------------------
            // NAVIGATION KEY
            // --------------------------------------------------
            //
            // Allows PushNotificationService to navigate to a
            // route when a notification is tapped.
            //

            navigatorKey:
            PushNotificationService.instance.navigatorKey,

            // --------------------------------------------------
            // GLOBAL IN-APP NOTIFICATION BANNER
            // --------------------------------------------------
            //
            // Foreground push notifications are sent to this
            // widget through PushNotificationService.
            //

            builder: (
                context,
                child,
                ) {
              return InAppNotificationBanner(
                child: child!,
              );
            },

            // --------------------------------------------------
            // ROUTE OBSERVER
            // --------------------------------------------------
            //
            // Records screen navigation for the Admin Activity
            // Feed.
            //

            navigatorObservers: [
              _accessRouteObserver,
            ],

            // --------------------------------------------------
            // INITIAL ROUTE
            // --------------------------------------------------

            initialRoute: '/',

            // ==================================================
            // APPLICATION ROUTES
            // ==================================================

            routes: {
              // ------------------------------------------------
              // SPLASH
              // ------------------------------------------------

              '/': (
                  context,
                  ) =>
              const SplashScreen(),

              // ------------------------------------------------
              // AUTH
              // ------------------------------------------------

              '/login': (
                  context,
                  ) =>
              const LoginScreen(),

              '/register': (
                  context,
                  ) =>
              const RegisterScreen(),

              '/waiting-approval': (
                  context,
                  ) =>
              const WaitingApprovalScreen(),

              // ------------------------------------------------
              // DASHBOARD
              // ------------------------------------------------

              '/dashboard': (
                  context,
                  ) {
                final String? role =
                ModalRoute.of(context)
                    ?.settings
                    .arguments as String?;

                return DashboardScreen(
                  userRole: role ?? 'employee',
                );
              },

              // ------------------------------------------------
              // INVENTORY
              // ------------------------------------------------

              '/inventory': (
                  context,
                  ) =>
              const InventoryDashboard(),

              // ------------------------------------------------
              // BILLS
              // ------------------------------------------------

              '/bills': (
                  context,
                  ) =>
              const BillsScreen(),

              // ------------------------------------------------
              // ADMIN - NOTIFICATIONS
              // ------------------------------------------------

              '/admin/notifications': (
                  context,
                  ) =>
              const AdminGuard(
                child: AdminNotificationsScreen(),
              ),

              // ------------------------------------------------
              // ADMIN - EMPLOYEE ACCESS
              // ------------------------------------------------

              '/admin/employees': (
                  context,
                  ) =>
              const AdminGuard(
                child: EmployeeAccessScreen(),
              ),

              // ------------------------------------------------
              // ADMIN - ACTIVITY
              // ------------------------------------------------

              '/admin/activity': (
                  context,
                  ) =>
              const AdminGuard(
                child: ActivityFeedScreen(),
              ),
            },

            // ==================================================
            // UNKNOWN ROUTES
            // ==================================================
            //
            // Some screens are opened using:
            //
            // Navigator.push(
            //   MaterialPageRoute(
            //     settings: RouteSettings(
            //       name: 'Employee Access',
            //     ),
            //   ),
            // );
            //
            // These human-readable names are not necessarily
            // present in the routes map above.
            //
            // On Web/Desktop, refreshing such a route can cause
            // Flutter to look for that name in the routes table.
            //
            // If it cannot find the route, send the user back
            // through SplashScreen.
            //

            onUnknownRoute: (
                RouteSettings settings,
                ) {
              return MaterialPageRoute(
                settings: settings,
                builder: (
                    context,
                    ) =>
                const SplashScreen(),
              );
            },
          );
        },
      ),
    );
  }
}