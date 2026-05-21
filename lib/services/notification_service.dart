import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/study_task.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    tz.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(settings);
    await _createChannels();
    await _requestPermissions();
    _initialized = true;
  }

  Future<void> _createChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) {
      return;
    }

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'task_reminders_normal',
        'Task reminders',
        description: 'Reminders for upcoming homework tasks',
        importance: Importance.high,
      ),
    );

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'task_reminders_high',
        'High priority task reminders',
        description: 'Urgent reminders for high priority homework tasks',
        importance: Importance.max,
      ),
    );
  }

  Future<void> _requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    await _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> rescheduleAll(Iterable<StudyTask> tasks) async {
    if (!_initialized) {
      return;
    }

    try {
      await _plugin.cancelAll();
      for (final task in tasks) {
        await scheduleTaskReminders(task);
      }
    } catch (e, st) {
      debugPrint('Notification reschedule failed: $e');
      debugPrint('$st');
    }
  }

  Future<void> scheduleTaskReminders(StudyTask task) async {
    if (!_initialized || task.completed || !task.reminderEnabled) {
      return;
    }

    final now = DateTime.now();
    final due = task.dueDate;
    if (!due.isAfter(now)) {
      return;
    }

    final times = <DateTime>[];
    switch (task.priority) {
      case 'high':
        times.addAll([
          due.subtract(const Duration(hours: 2)),
          due.subtract(const Duration(minutes: 15)),
          due,
        ]);
        break;
      case 'low':
        times.add(due.subtract(const Duration(minutes: 30)));
        break;
      default:
        times.addAll([
          due.subtract(const Duration(hours: 1)),
          due,
        ]);
    }

    var index = 0;
    for (final time in times) {
      if (!time.isAfter(now)) {
        index += 1;
        continue;
      }
      try {
        await _plugin.zonedSchedule(
          _notificationId(task.id, index),
          _titleFor(task, index),
          _bodyFor(task, index),
          tz.TZDateTime.from(time, tz.local),
          _detailsFor(task.priority),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e, st) {
        debugPrint('Notification schedule failed for task ${task.id}: $e');
        debugPrint('$st');
      }
      index += 1;
    }
  }

  Future<void> cancelTaskReminders(String taskId) async {
    for (var i = 0; i < 4; i++) {
      try {
        await _plugin.cancel(_notificationId(taskId, i));
      } catch (e, st) {
        debugPrint('Notification cancel failed for task $taskId: $e');
        debugPrint('$st');
      }
    }
  }

  int _notificationId(String taskId, int index) {
    final base = taskId.hashCode & 0x1fffffff;
    return (base + index) & 0x1fffffff;
  }

  String _titleFor(StudyTask task, int index) {
    if (task.priority == 'high' && index >= 1) {
      return 'Urgent: ${task.title}';
    }
    return 'Task reminder: ${task.title}';
  }

  String _bodyFor(StudyTask task, int index) {
    final due = _formatDateTime(task.dueDate);
    if (task.priority == 'high' && index == 2) {
      return 'Deadline now ($due). Open planner and finish it.';
    }
    return '${task.subject} is due at $due.';
  }

  NotificationDetails _detailsFor(String priority) {
    final isHigh = priority == 'high';
    return NotificationDetails(
      android: AndroidNotificationDetails(
        isHigh ? 'task_reminders_high' : 'task_reminders_normal',
        isHigh ? 'High priority task reminders' : 'Task reminders',
        channelDescription: isHigh
            ? 'Urgent reminders for high priority homework tasks'
            : 'Reminders for upcoming homework tasks',
        importance: isHigh ? Importance.max : Importance.high,
        priority: isHigh ? Priority.max : Priority.high,
        ticker: isHigh ? 'Urgent homework reminder' : 'Homework reminder',
        vibrationPattern: isHigh ? Int64List.fromList([0, 500, 350, 500]) : null,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: isHigh
            ? InterruptionLevel.timeSensitive
            : InterruptionLevel.active,
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final month = _monthLabel(dateTime.month);
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$month ${dateTime.day}, ${dateTime.year} $hour:$minute';
  }

  String _monthLabel(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}
