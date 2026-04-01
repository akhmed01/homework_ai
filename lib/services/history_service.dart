import 'package:shared_preferences/shared_preferences.dart';

class HistoryService {
  static const String key = "history";
  static const int maxItems = 50;

  /// 🔹 Save problem (with cleanup)
  static Future<void> saveProblem(String problem) async {
    final prefs = await SharedPreferences.getInstance();

    List<String> history = prefs.getStringList(key) ?? [];

    // ❌ Remove duplicates
    history.remove(problem);

    // ➕ Add to top
    history.insert(0, problem);

    // ✂️ Limit size
    if (history.length > maxItems) {
      history = history.sublist(0, maxItems);
    }

    await prefs.setStringList(key, history);
  }

  /// 📜 Get history
  static Future<List<String>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key) ?? [];
  }

  /// 🧹 Clear history
  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
