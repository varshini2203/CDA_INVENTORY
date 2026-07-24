// lib/theme/theme_controller.dart
//
// App-wide light/dark mode controller. Wire this into your MaterialApp so
// toggling "Dark Mode" on the Profile screen actually changes the app theme,
// not just a stored preference.
//
// ── How to wire it into main.dart ───────────────────────────────────────────
//
//   void main() async {
//     WidgetsFlutterBinding.ensureInitialized();
//     await ThemeController.instance.load();   // restore saved preference
//     runApp(const MyApp());
//   }
//
//   class MyApp extends StatelessWidget {
//     const MyApp({super.key});
//     @override
//     Widget build(BuildContext context) {
//       return ValueListenableBuilder<ThemeMode>(
//         valueListenable: ThemeController.instance.mode,
//         builder: (context, mode, _) {
//           return MaterialApp(
//             themeMode: mode,
//             theme: ThemeData.light(),   // your light ThemeData
//             darkTheme: ThemeData.dark(),// your dark ThemeData
//             home: const DashboardScreen(),
//           );
//         },
//       );
//     }
//   }
//
// If you don't wire it into MaterialApp yet, the Profile screen will still
// switch its own colors correctly (it listens to the same controller), you
// just won't get the rest of the app following along until main.dart uses it.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeModeKey = 'app_theme_mode'; // 'dark' | 'light'

class ThemeController {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  /// Defaults to dark until [load] restores the saved preference.
  final ValueNotifier<ThemeMode> mode = ValueNotifier<ThemeMode>(ThemeMode.dark);

  bool _loaded = false;

  bool get isDark => mode.value == ThemeMode.dark;

  /// Restores the persisted preference. Safe to call multiple times —
  /// subsequent calls are no-ops once loaded.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kThemeModeKey);
    if (saved == 'light') {
      mode.value = ThemeMode.light;
    } else if (saved == 'dark') {
      mode.value = ThemeMode.dark;
    }
    // else: leave default (dark) — first run, nothing saved yet.
  }

  Future<void> setDark(bool isDark) async {
    mode.value = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, isDark ? 'dark' : 'light');
  }

  Future<void> toggle() => setDark(!isDark);
}