class StudyTask {
  final String id;
  final String title;
  final String subject;
  final String notes;
  final DateTime dueDate;
  final int estimatedMinutes;
  final String priority;
  final bool completed;
  final bool reminderEnabled;
  final DateTime createdAt;
  final DateTime? completedAt;

  const StudyTask({
    required this.id,
    required this.title,
    required this.subject,
    required this.notes,
    required this.dueDate,
    required this.estimatedMinutes,
    required this.priority,
    required this.completed,
    required this.reminderEnabled,
    required this.createdAt,
    required this.completedAt,
  });

  StudyTask copyWith({
    String? id,
    String? title,
    String? subject,
    String? notes,
    DateTime? dueDate,
    int? estimatedMinutes,
    String? priority,
    bool? completed,
    bool? reminderEnabled,
    DateTime? createdAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return StudyTask(
      id: id ?? this.id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      notes: notes ?? this.notes,
      dueDate: dueDate ?? this.dueDate,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      priority: priority ?? this.priority,
      completed: completed ?? this.completed,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      createdAt: createdAt ?? this.createdAt,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subject': subject,
    'notes': notes,
    'dueDate': dueDate.toIso8601String(),
    'estimatedMinutes': estimatedMinutes,
    'priority': priority,
    'completed': completed,
    'reminderEnabled': reminderEnabled,
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
  };

  factory StudyTask.fromJson(Map<String, dynamic> json) {
    return StudyTask(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      subject: json['subject'] as String? ?? 'General',
      notes: json['notes'] as String? ?? '',
      dueDate: DateTime.parse(json['dueDate'] as String),
      estimatedMinutes: json['estimatedMinutes'] as int? ?? 30,
      priority: json['priority'] as String? ?? 'medium',
      completed: json['completed'] as bool? ?? false,
      reminderEnabled: json['reminderEnabled'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
    );
  }
}
