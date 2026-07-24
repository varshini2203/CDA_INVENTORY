import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _key = 'profile_dark_mode';
  bool _isDark = true;
  bool get isDark => _isDark;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool(_key) ?? true;
    notifyListeners();
  }

  Future<void> toggle(bool value) async {
    _isDark = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }

  ThemeData get themeData => _isDark ? darkTheme : lightTheme;

  static final darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF050A14),
    primaryColor: const Color(0xFF1E5FC8),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF1E5FC8),
      secondary: Color(0xFF00D68F),
      surface: Color(0xFF0A1428),
    ),
  );

  static final lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF2F5FA),
    primaryColor: const Color(0xFF1E5FC8),
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF1E5FC8),
      secondary: Color(0xFF00D68F),
      surface: Colors.white,
    ),
  );
}