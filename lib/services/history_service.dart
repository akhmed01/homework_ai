import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A single history entry with id, problem text, and timestamp.
class HistoryEntry {
  final String id;
  final String problem;
  final DateTime timestamp;

  HistoryEntry({
    required this.id,
    required this.problem,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'problem': problem,
    'timestamp': timestamp.toIso8601String(),
  };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    id: json['id'] as String,
    problem: json['problem'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}

class HistoryService {
  static const String _key = 'history_v2';
  static const int _maxItems = 50;

  /// Save a new problem (deduplicates by text, moves to top)
  static Future<void> saveProblem(String problem) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await getHistory();

    // Remove any existing entry with same problem text
    entries.removeWhere((e) => e.problem == problem);

    final newEntry = HistoryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      problem: problem,
      timestamp: DateTime.now(),
    );

    entries.insert(0, newEntry);

    final trimmed = entries.length > _maxItems
        ? entries.sublist(0, _maxItems)
        : entries;

    await prefs.setString(
      _key,
      jsonEncode(trimmed.map((e) => e.toJson()).toList()),
    );
  }

  /// Get all history entries
  static Future<List<HistoryEntry>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();

    // Migrate from old string-list format if needed
    final oldList = prefs.getStringList('history');
    if (oldList != null && oldList.isNotEmpty) {
      final migrated = oldList
          .asMap()
          .entries
          .map(
            (e) => HistoryEntry(
              id: e.key.toString(),
              problem: e.value,
              timestamp: DateTime.now().subtract(Duration(minutes: e.key)),
            ),
          )
          .toList();
      await prefs.setString(
        _key,
        jsonEncode(migrated.map((e) => e.toJson()).toList()),
      );
      await prefs.remove('history');
      return migrated;
    }

    final raw = prefs.getString(_key);
    if (raw == null) return [];

    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Delete a single entry by id
  static Future<void> deleteEntry(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await getHistory();
    entries.removeWhere((e) => e.id == id);
    await prefs.setString(
      _key,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  /// Restore a previously deleted entry (undo support)
  static Future<void> restoreEntry(HistoryEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await getHistory();
    // Re-insert at the position that matches original timestamp order
    final idx = entries.indexWhere(
      (e) => e.timestamp.isBefore(entry.timestamp),
    );
    if (idx == -1) {
      entries.add(entry);
    } else {
      entries.insert(idx, entry);
    }
    await prefs.setString(
      _key,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  /// Clear all history
  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
