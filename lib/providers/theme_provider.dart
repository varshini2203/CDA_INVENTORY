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

  // Most screens in this app are hand-built with hardcoded white/light
  // cards regardless of the dark-mode toggle above. ThemeData(brightness:
  // dark) otherwise generates a light/white default TextTheme, which makes
  // any TextField/TextFormField that doesn't set its own `style` render
  // invisible (light text on a white card). Forcing a dark, readable text
  // color + cursor color here fixes every such field app-wide without
  // having to edit each screen individually.
  static const _defaultTextColor = Color(0xFF1F2937);

  static const _sharedTextTheme = TextTheme(
    bodyLarge: TextStyle(color: _defaultTextColor),
    bodyMedium: TextStyle(color: _defaultTextColor),
    bodySmall: TextStyle(color: _defaultTextColor),
    titleLarge: TextStyle(color: _defaultTextColor),
    titleMedium: TextStyle(color: _defaultTextColor),
    titleSmall: TextStyle(color: _defaultTextColor),
    labelLarge: TextStyle(color: _defaultTextColor),
    labelMedium: TextStyle(color: _defaultTextColor),
    labelSmall: TextStyle(color: _defaultTextColor),
  );

  static const _sharedInputDecorationTheme = InputDecorationTheme(
    hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
    labelStyle: TextStyle(color: _defaultTextColor),
  );

  static const _sharedTextSelectionTheme = TextSelectionThemeData(
    cursorColor: _defaultTextColor,
  );

  static final darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF050A14),
    primaryColor: const Color(0xFF1E5FC8),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF1E5FC8),
      secondary: Color(0xFF00D68F),
      surface: Color(0xFF0A1428),
    ),
    textTheme: _sharedTextTheme,
    inputDecorationTheme: _sharedInputDecorationTheme,
    textSelectionTheme: _sharedTextSelectionTheme,
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
    textTheme: _sharedTextTheme,
    inputDecorationTheme: _sharedInputDecorationTheme,
    textSelectionTheme: _sharedTextSelectionTheme,
  );
}