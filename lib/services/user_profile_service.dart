import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

class UserProfileService extends ChangeNotifier {
  static const String _profileKey = 'user_profile_v1';
  static const String _legacyLanguageKey = 'response_language_v1';
  static const String _legacyStudentNameKey = 'student_name_v1';
  static const String _legacyDailyGoalKey = 'daily_goal_minutes_v1';

  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'mn': 'Mongolian',
    'es': 'Spanish',
  };

  static const List<String> supportedGradeLevels = [
    '',
    'Grade 5',
    'Grade 6',
    'Grade 7',
    'Grade 8',
    'Grade 9',
    'Grade 10',
    'Grade 11',
    'Grade 12',
    'University',
  ];

  UserProfile _profile = UserProfile.initial();
  bool _isLoaded = false;

  UserProfileService() {
    _init();
  }

  bool get isLoaded => _isLoaded;
  UserProfile get profile => _profile;

  String get displayName => _profile.displayName;
  String get email => _profile.email;
  String get schoolName => _profile.schoolName;
  String get gradeLevel => _profile.gradeLevel;
  String get bio => _profile.bio;
  String get responseLanguageCode => _profile.responseLanguageCode;
  int get dailyGoalMinutes => _profile.dailyGoalMinutes;

  String get responseLanguageName =>
      supportedLanguages[responseLanguageCode] ?? 'English';

  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'S';
    }

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  bool get hasContactEmail => email.trim().isNotEmpty;

  String get profileStatusLabel =>
      hasContactEmail ? 'Profile ready' : 'Guest profile';

  String get profileStatusSubtitle => hasContactEmail
      ? email
      : 'Saved locally on this device until cloud sync is wired.';

  double get completionProgress {
    var complete = 0;
    const total = 5;

    if (displayName.trim().isNotEmpty && displayName.trim() != 'Student') {
      complete += 1;
    }
    if (email.trim().isNotEmpty) {
      complete += 1;
    }
    if (schoolName.trim().isNotEmpty) {
      complete += 1;
    }
    if (gradeLevel.trim().isNotEmpty) {
      complete += 1;
    }
    if (bio.trim().isNotEmpty) {
      complete += 1;
    }

    return complete / total;
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawProfile = prefs.getString(_profileKey);

      if (rawProfile != null && rawProfile.isNotEmpty) {
        _profile = UserProfile.fromJson(
          jsonDecode(rawProfile) as Map<String, dynamic>,
        );
      } else {
        _profile = UserProfile.initial().copyWith(
          displayName:
              prefs.getString(_legacyStudentNameKey)?.trim().isNotEmpty == true
              ? prefs.getString(_legacyStudentNameKey)!.trim()
              : 'Student',
          responseLanguageCode:
              supportedLanguages.containsKey(
                prefs.getString(_legacyLanguageKey),
              )
              ? prefs.getString(_legacyLanguageKey)!
              : 'en',
          dailyGoalMinutes: prefs.getInt(_legacyDailyGoalKey) ?? 45,
          updatedAt: DateTime.now(),
        );
        await _persist();
      }
    } catch (_) {
      _profile = UserProfile.initial();
    }

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> saveProfile({
    required String displayName,
    required String email,
    required String schoolName,
    required String gradeLevel,
    required String bio,
    required String responseLanguageCode,
    required int dailyGoalMinutes,
  }) async {
    _profile = _profile.copyWith(
      displayName: displayName.trim().isEmpty ? 'Student' : displayName.trim(),
      email: email.trim(),
      schoolName: schoolName.trim(),
      gradeLevel: gradeLevel.trim(),
      bio: bio.trim(),
      responseLanguageCode: supportedLanguages.containsKey(responseLanguageCode)
          ? responseLanguageCode
          : 'en',
      dailyGoalMinutes: dailyGoalMinutes,
      updatedAt: DateTime.now(),
    );

    await _persist();
    notifyListeners();
  }

  Future<void> updateResponseLanguage(String code) async {
    if (!supportedLanguages.containsKey(code)) {
      return;
    }

    _profile = _profile.copyWith(
      responseLanguageCode: code,
      updatedAt: DateTime.now(),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> updateDailyGoalMinutes(int minutes) async {
    _profile = _profile.copyWith(
      dailyGoalMinutes: minutes,
      updatedAt: DateTime.now(),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(_profile.toJson()));
  }
}
