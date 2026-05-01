class StudySession {
  final String id;
  final int minutes;
  final String source;
  final String summary;
  final DateTime timestamp;

  const StudySession({
    required this.id,
    required this.minutes,
    required this.source,
    required this.summary,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'minutes': minutes,
    'source': source,
    'summary': summary,
    'timestamp': timestamp.toIso8601String(),
  };

  factory StudySession.fromJson(Map<String, dynamic> json) {
    return StudySession(
      id: json['id'] as String,
      minutes: json['minutes'] as int? ?? 10,
      source: json['source'] as String? ?? 'ai',
      summary: json['summary'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
