import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const _key = 'profile_language_code';
  String _code = 'en'; // 'en' | 'ta' | 'hi'
  String get code => _code;

  LanguageProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _code = prefs.getString(_key) ?? 'en';
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    _code = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
  }

  String get displayName {
    switch (_code) {
      case 'ta': return 'தமிழ்';
      case 'hi': return 'हिन्दी';
      default: return 'English';
    }
  }
}