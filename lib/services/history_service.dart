import 'package:shared_preferences/shared_preferences.dart';

class HistoryService {
  static const String key = "history";

  static Future<void> saveProblem(String problem) async {
    final prefs = await SharedPreferences.getInstance();

    List<String> history = prefs.getStringList(key) ?? [];

    history.insert(0, problem);

    await prefs.setStringList(key, history);
  }

  static Future<List<String>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getStringList(key) ?? [];
  }
}
