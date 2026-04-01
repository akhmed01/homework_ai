import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const _key = "darkMode";

  bool _isDark = false;
  bool _isLoaded = false;

  bool get isDark => _isDark;
  bool get isLoaded => _isLoaded;

  ThemeService() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool(_key) ?? false;
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDark = !_isDark;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _isDark);

    notifyListeners();
  }
}
