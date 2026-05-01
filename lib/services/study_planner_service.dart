import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/study_session.dart';
import '../models/study_task.dart';

class StudyPlannerService extends ChangeNotifier {
  static const String _tasksKey = 'study_tasks_v1';
  static const String _sessionsKey = 'study_sessions_v1';
  static const String _languageKey = 'response_language_v1';
  static const String _studentNameKey = 'student_name_v1';
  static const String _dailyGoalKey = 'daily_goal_minutes_v1';
  static const int _maxSessions = 200;

  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'mn': 'Mongolian',
    'es': 'Spanish',
  };

  List<StudyTask> _tasks = [];
  List<StudySession> _sessions = [];
  String _responseLanguageCode = 'en';
  String _studentName = 'Student';
  int _dailyGoalMinutes = 45;
  bool _isLoaded = false;

  StudyPlannerService() {
    _init();
  }

  bool get isLoaded => _isLoaded;
  String get responseLanguageCode => _responseLanguageCode;
  String get responseLanguageName =>
      supportedLanguages[_responseLanguageCode] ?? 'English';
  String get studentName => _studentName;
  int get dailyGoalMinutes => _dailyGoalMinutes;

  List<StudyTask> get tasks {
    final items = List<StudyTask>.from(_tasks);
    items.sort((a, b) {
      if (a.completed != b.completed) {
        return a.completed ? 1 : -1;
      }
      return a.dueDate.compareTo(b.dueDate);
    });
    return items;
  }

  List<StudyTask> get dueSoonTasks {
    final now = DateTime.now();
    final cutoff = now.add(const Duration(hours: 48));
    final items = _tasks
        .where(
          (task) =>
              !task.completed &&
              task.reminderEnabled &&
              task.dueDate.isBefore(cutoff),
        )
        .toList();
    items.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return items;
  }

  int get studyMinutesToday {
    final now = DateTime.now();
    return _minutesBetween(_startOfDay(now), _endOfDay(now));
  }

  int get studyMinutesThisWeek {
    final now = DateTime.now();
    return _minutesBetween(_startOfWeek(now), _endOfDay(now));
  }

  int get completedTasksThisWeek {
    final now = DateTime.now();
    final start = _startOfWeek(now);
    final end = _endOfDay(now);
    return _tasks.where((task) {
      final completedAt = task.completedAt;
      return completedAt != null &&
          !completedAt.isBefore(start) &&
          !completedAt.isAfter(end);
    }).length;
  }

  int get solvedQuestionsThisWeek {
    final now = DateTime.now();
    final start = _startOfWeek(now);
    final end = _endOfDay(now);
    return _sessions.where((session) {
      return session.source == 'ai' &&
          !session.timestamp.isBefore(start) &&
          !session.timestamp.isAfter(end);
    }).length;
  }

  int get currentStreak {
    final activeDays = _activeDays();
    var streak = 0;
    var cursor = _startOfDay(DateTime.now());

    while (activeDays.contains(cursor)) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return streak;
  }

  double get dailyGoalProgress {
    if (_dailyGoalMinutes <= 0) {
      return 0;
    }
    return (studyMinutesToday / _dailyGoalMinutes).clamp(0.0, 1.0);
  }

  List<MapEntry<DateTime, int>> get lastSevenDays {
    final now = DateTime.now();
    final entries = <MapEntry<DateTime, int>>[];

    for (var offset = 6; offset >= 0; offset--) {
      final day = _startOfDay(now.subtract(Duration(days: offset)));
      entries.add(MapEntry(day, _minutesBetween(day, _endOfDay(day))));
    }

    return entries;
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawTasks = prefs.getString(_tasksKey);
      final rawSessions = prefs.getString(_sessionsKey);

      if (rawTasks != null && rawTasks.isNotEmpty) {
        final decoded = jsonDecode(rawTasks) as List<dynamic>;
        _tasks = decoded
            .map((item) => StudyTask.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      if (rawSessions != null && rawSessions.isNotEmpty) {
        final decoded = jsonDecode(rawSessions) as List<dynamic>;
        _sessions = decoded
            .map((item) => StudySession.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      final savedLanguage = prefs.getString(_languageKey);
      if (savedLanguage != null &&
          supportedLanguages.containsKey(savedLanguage)) {
        _responseLanguageCode = savedLanguage;
      }

      final savedName = prefs.getString(_studentNameKey);
      if (savedName != null && savedName.trim().isNotEmpty) {
        _studentName = savedName.trim();
      }

      _dailyGoalMinutes = prefs.getInt(_dailyGoalKey) ?? 45;
    } catch (_) {
      _tasks = [];
      _sessions = [];
      _responseLanguageCode = 'en';
      _studentName = 'Student';
      _dailyGoalMinutes = 45;
    }

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> addTask({
    required String title,
    required String subject,
    required DateTime dueDate,
    required int estimatedMinutes,
    required String priority,
    String notes = '',
    bool reminderEnabled = true,
  }) async {
    final now = DateTime.now();
    _tasks = [
      ..._tasks,
      StudyTask(
        id: now.microsecondsSinceEpoch.toString(),
        title: title.trim(),
        subject: subject.trim().isEmpty ? 'General' : subject.trim(),
        notes: notes.trim(),
        dueDate: dueDate,
        estimatedMinutes: estimatedMinutes,
        priority: priority,
        completed: false,
        reminderEnabled: reminderEnabled,
        createdAt: now,
        completedAt: null,
      ),
    ];
    await _persistTasks();
    notifyListeners();
  }

  Future<void> toggleTaskCompletion(String id) async {
    _tasks = _tasks.map((task) {
      if (task.id != id) {
        return task;
      }

      final completed = !task.completed;
      return task.copyWith(
        completed: completed,
        completedAt: completed ? DateTime.now() : null,
        clearCompletedAt: !completed,
      );
    }).toList();
    await _persistTasks();
    notifyListeners();
  }

  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((task) => task.id == id);
    await _persistTasks();
    notifyListeners();
  }

  Future<void> updateResponseLanguage(String code) async {
    if (!supportedLanguages.containsKey(code)) {
      return;
    }
    _responseLanguageCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, code);
    notifyListeners();
  }

  Future<void> updateStudentName(String name) async {
    final trimmed = name.trim();
    _studentName = trimmed.isEmpty ? 'Student' : trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_studentNameKey, _studentName);
    notifyListeners();
  }

  Future<void> updateDailyGoalMinutes(int minutes) async {
    _dailyGoalMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dailyGoalKey, minutes);
    notifyListeners();
  }

  Future<void> recordAiSession({
    required String summary,
    int minutes = 10,
  }) async {
    final trimmedSummary = summary.trim();
    if (trimmedSummary.isEmpty) {
      return;
    }

    final next = List<StudySession>.from(_sessions)
      ..insert(
        0,
        StudySession(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          minutes: minutes,
          source: 'ai',
          summary: trimmedSummary,
          timestamp: DateTime.now(),
        ),
      );

    if (next.length > _maxSessions) {
      next.removeRange(_maxSessions, next.length);
    }

    _sessions = next;
    await _persistSessions();
    notifyListeners();
  }

  Future<void> _persistTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _tasksKey,
      jsonEncode(_tasks.map((task) => task.toJson()).toList()),
    );
  }

  Future<void> _persistSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _sessionsKey,
      jsonEncode(_sessions.map((session) => session.toJson()).toList()),
    );
  }

  int _minutesBetween(DateTime start, DateTime end) {
    var total = 0;

    for (final task in _tasks) {
      final completedAt = task.completedAt;
      if (completedAt != null &&
          !completedAt.isBefore(start) &&
          !completedAt.isAfter(end)) {
        total += task.estimatedMinutes;
      }
    }

    for (final session in _sessions) {
      if (!session.timestamp.isBefore(start) &&
          !session.timestamp.isAfter(end)) {
        total += session.minutes;
      }
    }

    return total;
  }

  Set<DateTime> _activeDays() {
    final days = <DateTime>{};

    for (final task in _tasks) {
      if (task.completedAt != null) {
        days.add(_startOfDay(task.completedAt!));
      }
    }

    for (final session in _sessions) {
      days.add(_startOfDay(session.timestamp));
    }

    return days;
  }

  DateTime _startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime _endOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day, 23, 59, 59, 999);

  DateTime _startOfWeek(DateTime value) {
    final dayStart = _startOfDay(value);
    return dayStart.subtract(Duration(days: dayStart.weekday - 1));
  }
}
