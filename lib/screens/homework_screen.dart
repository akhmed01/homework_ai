import 'package:flutter/material.dart';
import '../models/homework.dart';
import '../services/homework_service.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';

class HomeworkScreen extends StatelessWidget {
  const HomeworkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Homework"),
        backgroundColor: const Color(0xFF4F46E5),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService.signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Homework>>(
        stream: HomeworkService.getHomework(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final list = snapshot.data ?? [];

          if (list.isEmpty) {
            return Center(
              child: Text("No homework yet!", style: theme.textTheme.bodyLarge),
            );
          }

          // Group by done/not done
          final pending = list.where((h) => !h.isDone).toList();
          final done = list.where((h) => h.isDone).toList();

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (pending.isNotEmpty) ...[
                _sectionHeader("Pending", theme),
                ...pending.map((hw) => _HomeworkCard(hw: hw)),
              ],
              if (done.isNotEmpty) ...[
                _sectionHeader("Done", theme),
                ...done.map((hw) => _HomeworkCard(hw: hw)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final titleController = TextEditingController();
    final subjectController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    DateTime? reminderTime;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Add Homework",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: "Title",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subjectController,
                decoration: const InputDecoration(
                  labelText: "Subject",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(
                  "Due: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setModalState(() => selectedDate = picked);
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications),
                title: Text(
                  reminderTime == null
                      ? "Set reminder (optional)"
                      : "Reminder: ${reminderTime!.hour}:${reminderTime!.minute.toString().padLeft(2, '0')}",
                ),
                onTap: () async {
                  final picked = await showDateTimePicker(context);
                  if (picked != null) {
                    setModalState(() => reminderTime = picked);
                  }
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.isEmpty ||
                        subjectController.text.isEmpty)
                      return;

                    final hw = Homework(
                      id: '',
                      title: titleController.text.trim(),
                      subject: subjectController.text.trim(),
                      dueDate: selectedDate,
                      reminderTime: reminderTime,
                    );

                    await HomeworkService.addHomework(hw);

                    if (reminderTime != null) {
                      await NotificationService.scheduleReminder(
                        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                        title: hw.title,
                        subject: hw.subject,
                        reminderTime: reminderTime!,
                      );
                    }

                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text("Save"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<DateTime?> showDateTimePicker(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}

class _HomeworkCard extends StatelessWidget {
  final Homework hw;
  const _HomeworkCard({required this.hw});

  @override
  Widget build(BuildContext context) {
    final isOverdue = hw.dueDate.isBefore(DateTime.now()) && !hw.isDone;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Checkbox(
          value: hw.isDone,
          onChanged: (_) => HomeworkService.toggleDone(hw.id, hw.isDone),
        ),
        title: Text(
          hw.title,
          style: TextStyle(
            decoration: hw.isDone ? TextDecoration.lineThrough : null,
            color: hw.isDone ? Colors.grey : null,
          ),
        ),
        subtitle: Text(
          "${hw.subject} · Due ${hw.dueDate.day}/${hw.dueDate.month}/${hw.dueDate.year}",
          style: TextStyle(color: isOverdue ? Colors.red : null),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => HomeworkService.deleteHomework(hw.id),
        ),
      ),
    );
  }
}
