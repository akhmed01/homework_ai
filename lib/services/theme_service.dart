import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  bool isDark = false;

  ThemeService() {
    loadTheme();
  }

  void toggleTheme() async {
    isDark = !isDark;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("darkMode", isDark);

    notifyListeners();
  }

  void loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    isDark = prefs.getBool("darkMode") ?? false;
    notifyListeners();
  }
}
