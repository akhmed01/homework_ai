class UserProfile {
  final String displayName;
  final String email;
  final String schoolName;
  final String gradeLevel;
  final String bio;
  final String responseLanguageCode;
  final int dailyGoalMinutes;
  final DateTime updatedAt;

  const UserProfile({
    required this.displayName,
    required this.email,
    required this.schoolName,
    required this.gradeLevel,
    required this.bio,
    required this.responseLanguageCode,
    required this.dailyGoalMinutes,
    required this.updatedAt,
  });

  factory UserProfile.initial() {
    return UserProfile(
      displayName: 'Student',
      email: '',
      schoolName: '',
      gradeLevel: '',
      bio: '',
      responseLanguageCode: 'en',
      dailyGoalMinutes: 45,
      updatedAt: DateTime.now(),
    );
  }

  UserProfile copyWith({
    String? displayName,
    String? email,
    String? schoolName,
    String? gradeLevel,
    String? bio,
    String? responseLanguageCode,
    int? dailyGoalMinutes,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      schoolName: schoolName ?? this.schoolName,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      bio: bio ?? this.bio,
      responseLanguageCode: responseLanguageCode ?? this.responseLanguageCode,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'displayName': displayName,
    'email': email,
    'schoolName': schoolName,
    'gradeLevel': gradeLevel,
    'bio': bio,
    'responseLanguageCode': responseLanguageCode,
    'dailyGoalMinutes': dailyGoalMinutes,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      displayName: json['displayName'] as String? ?? 'Student',
      email: json['email'] as String? ?? '',
      schoolName: json['schoolName'] as String? ?? '',
      gradeLevel: json['gradeLevel'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      responseLanguageCode: json['responseLanguageCode'] as String? ?? 'en',
      dailyGoalMinutes: json['dailyGoalMinutes'] as int? ?? 45,
      updatedAt: json['updatedAt'] == null
          ? DateTime.now()
          : DateTime.parse(json['updatedAt'] as String),
    );
  }
}
