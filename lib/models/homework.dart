class Homework {
  final String id;
  final String title;
  final String subject;
  final DateTime dueDate;
  final bool isDone;
  final DateTime? reminderTime;

  Homework({
    required this.id,
    required this.title,
    required this.subject,
    required this.dueDate,
    this.isDone = false,
    this.reminderTime,
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'subject': subject,
    'dueDate': dueDate.toIso8601String(),
    'isDone': isDone,
    'reminderTime': reminderTime?.toIso8601String(),
  };

  factory Homework.fromMap(String id, Map<String, dynamic> map) => Homework(
    id: id,
    title: map['title'] ?? '',
    subject: map['subject'] ?? '',
    dueDate: DateTime.parse(map['dueDate']),
    isDone: map['isDone'] ?? false,
    reminderTime: map['reminderTime'] != null
        ? DateTime.parse(map['reminderTime'])
        : null,
  );
}
