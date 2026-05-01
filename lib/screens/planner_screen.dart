import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/study_task.dart';
import '../services/study_planner_service.dart';

class PlannerScreen extends StatelessWidget {
  const PlannerScreen({super.key});

  Future<void> _showAddTaskSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _TaskEditorSheet(),
    );
  }

  Future<void> _editStudentName(BuildContext context) async {
    final service = context.read<StudyPlannerService>();
    final controller = TextEditingController(text: service.studentName);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Student profile'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Display name',
            hintText: 'Enter a name for this device',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await service.updateStudentName(controller.text);
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final planner = context.watch<StudyPlannerService>();

    if (!planner.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final dueSoonTasks = planner.dueSoonTasks;
    final tasks = planner.tasks;
    final weeklyBars = planner.lastSevenDays;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Planner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_task),
            tooltip: 'Add homework task',
            onPressed: () => _showAddTaskSheet(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTaskSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add task'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Keep homework moving, track study time, and see which features are already live.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      child: Text(
                        planner.studentName.substring(0, 1).toUpperCase(),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            planner.studentName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Guest mode is active. Authentication and cloud sync still need a backend pass.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer
                                  .withValues(alpha: 0.8),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _editStudentName(context),
                      child: const Text('Edit'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricCard(
                  width: 168,
                  title: 'Today',
                  value: '${planner.studyMinutesToday} min',
                  subtitle:
                      'Goal ${planner.dailyGoalMinutes} min • ${(planner.dailyGoalProgress * 100).round()}%',
                  icon: Icons.timer_outlined,
                ),
                _MetricCard(
                  width: 168,
                  title: 'This Week',
                  value: '${planner.studyMinutesThisWeek} min',
                  subtitle:
                      '${planner.completedTasksThisWeek} tasks and ${planner.solvedQuestionsThisWeek} AI sessions',
                  icon: Icons.insights_outlined,
                ),
                _MetricCard(
                  width: 168,
                  title: 'Due Soon',
                  value: '${dueSoonTasks.length}',
                  subtitle: dueSoonTasks.isEmpty
                      ? 'Nothing urgent right now'
                      : 'Assignments due in the next 48 hours',
                  icon: Icons.notifications_active_outlined,
                ),
                _MetricCard(
                  width: 168,
                  title: 'Streak',
                  value: '${planner.currentStreak} days',
                  subtitle: planner.currentStreak == 0
                      ? 'Complete a task or solve a problem today'
                      : 'Nice momentum, keep it going',
                  icon: Icons.local_fire_department_outlined,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Deadline Reminders',
              actionLabel: dueSoonTasks.isEmpty ? null : 'Planner ready',
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: dueSoonTasks.isEmpty
                    ? Text(
                        'No deadline reminders yet. Add a task with a due date and it will show up here.',
                        style: theme.textTheme.bodyMedium,
                      )
                    : Column(
                        children: dueSoonTasks
                            .take(4)
                            .map(
                              (task) => _ReminderTile(
                                task: task,
                                onComplete: () => context
                                    .read<StudyPlannerService>()
                                    .toggleTaskCompletion(task.id),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Homework Schedule',
              actionLabel: '${tasks.length} total',
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: tasks.isEmpty
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your planner is empty.',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add homework, attach a deadline, and track how much study time each task should take.',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: () => _showAddTaskSheet(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Create first task'),
                          ),
                        ],
                      )
                    : Column(
                        children: tasks
                            .take(8)
                            .map(
                              (task) => _TaskTile(
                                task: task,
                                onToggle: () => context
                                    .read<StudyPlannerService>()
                                    .toggleTaskCompletion(task.id),
                                onDelete: () => context
                                    .read<StudyPlannerService>()
                                    .deleteTask(task.id),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Daily / Weekly Tracking',
              actionLabel: '${planner.studyMinutesThisWeek} min this week',
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: planner.dailyGoalProgress,
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Today: ${planner.studyMinutesToday} of ${planner.dailyGoalMinutes} minutes',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 140,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: weeklyBars
                            .map(
                              (entry) => Expanded(
                                child: _StudyBar(
                                  label: _weekdayLabel(entry.key),
                                  minutes: entry.value,
                                  maxMinutes: weeklyBars
                                      .map((item) => item.value)
                                      .fold<int>(1, (a, b) => a > b ? a : b),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Tutor Settings',
              actionLabel: planner.responseLanguageName,
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Answer language',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: planner.responseLanguageCode,
                      items: StudyPlannerService.supportedLanguages.entries
                          .map(
                            (entry) => DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          context
                              .read<StudyPlannerService>()
                              .updateResponseLanguage(value);
                        }
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Select how the AI should answer',
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Daily study goal',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const [
                        30,
                        45,
                        60,
                        90,
                      ].map((goal) => _GoalChip(minutes: goal)).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Feature Rollout',
              actionLabel: 'Live vs planned',
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: const [
                    _FeatureRow(
                      title: 'PDF upload support',
                      subtitle: 'Import text-based PDFs into the solving flow.',
                      status: 'Live',
                    ),
                    _FeatureRow(
                      title: 'Improved AI explanations',
                      subtitle:
                          'Stronger teaching prompts and richer response styles.',
                      status: 'Live',
                    ),
                    _FeatureRow(
                      title: 'User authentication',
                      subtitle:
                          'Still planned. The app currently runs in guest mode.',
                      status: 'Planned',
                    ),
                    _FeatureRow(
                      title: 'Cloud sync',
                      subtitle:
                          'Still planned. Tasks and history are local on this device.',
                      status: 'Planned',
                    ),
                    _FeatureRow(
                      title: 'Multi-language support',
                      subtitle:
                          'AI answers can now be requested in multiple languages.',
                      status: 'Beta',
                    ),
                    _FeatureRow(
                      title: 'Voice input',
                      subtitle:
                          'Still planned. Speech capture needs an additional plugin.',
                      status: 'Planned',
                    ),
                    _FeatureRow(
                      title: 'Export answers as PDF',
                      subtitle:
                          'Save AI answers as PDF files from solution screens.',
                      status: 'Live',
                    ),
                    _FeatureRow(
                      title: 'Task planner and scheduling',
                      subtitle:
                          'Create homework tasks with subject, duration, and due date.',
                      status: 'Live',
                    ),
                    _FeatureRow(
                      title: 'Deadline reminders and notifications',
                      subtitle:
                          'In-app reminders are live. System notifications still need a plugin.',
                      status: 'In-app',
                    ),
                    _FeatureRow(
                      title: 'Daily/weekly study tracking',
                      subtitle:
                          'Tracks completed task time and AI study sessions.',
                      status: 'Live',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _weekdayLabel(DateTime day) {
    switch (day.weekday) {
      case DateTime.monday:
        return 'M';
      case DateTime.tuesday:
        return 'T';
      case DateTime.wednesday:
        return 'W';
      case DateTime.thursday:
        return 'T';
      case DateTime.friday:
        return 'F';
      case DateTime.saturday:
        return 'S';
      default:
        return 'S';
    }
  }
}

class _TaskEditorSheet extends StatefulWidget {
  const _TaskEditorSheet();

  @override
  State<_TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<_TaskEditorSheet> {
  final _titleController = TextEditingController();
  final _subjectController = TextEditingController();
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  String _priority = 'medium';
  int _estimatedMinutes = 45;
  bool _reminderEnabled = true;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _dueDate,
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _dueDate = DateTime(picked.year, picked.month, picked.day, 18);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);
    await context.read<StudyPlannerService>().addTask(
      title: _titleController.text,
      subject: _subjectController.text,
      dueDate: _dueDate,
      estimatedMinutes: _estimatedMinutes,
      priority: _priority,
      notes: _notesController.text,
      reminderEnabled: _reminderEnabled,
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New homework task',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Plan the assignment, set a due date, and feed it into your weekly study flow.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Task title',
                  hintText: 'Finish algebra worksheet',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Add a task title.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _subjectController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  hintText: 'Math, Biology, Literature...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notesController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'Anything you need to remember for this task',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_month),
                      label: Text(_formatDate(_dueDate)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _estimatedMinutes,
                      items: const [15, 30, 45, 60, 90]
                          .map(
                            (minutes) => DropdownMenuItem<int>(
                              value: minutes,
                              child: Text('$minutes min'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _estimatedMinutes = value);
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Study time',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Priority',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _PriorityChip(
                    label: 'Low',
                    value: 'low',
                    current: _priority,
                    onSelected: (value) => setState(() => _priority = value),
                  ),
                  _PriorityChip(
                    label: 'Medium',
                    value: 'medium',
                    current: _priority,
                    onSelected: (value) => setState(() => _priority = value),
                  ),
                  _PriorityChip(
                    label: 'High',
                    value: 'high',
                    current: _priority,
                    onSelected: (value) => setState(() => _priority = value),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _reminderEnabled,
                onChanged: (value) => setState(() => _reminderEnabled = value),
                title: const Text('Show in-app reminder'),
                subtitle: const Text(
                  'Due-soon tasks appear on the planner and home screen.',
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(_saving ? 'Saving...' : 'Save task'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final month = _monthLabel(date.month);
    return '$month ${date.day}, ${date.year}';
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

class _GoalChip extends StatelessWidget {
  final int minutes;

  const _GoalChip({required this.minutes});

  @override
  Widget build(BuildContext context) {
    final planner = context.watch<StudyPlannerService>();
    final selected = planner.dailyGoalMinutes == minutes;

    return ChoiceChip(
      label: Text('$minutes min'),
      selected: selected,
      onSelected: (_) {
        context.read<StudyPlannerService>().updateDailyGoalMinutes(minutes);
      },
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onSelected;

  const _PriorityChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: current == value,
      onSelected: (_) => onSelected(value),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _MetricCard({
    required this.width,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  final StudyTask task;
  final VoidCallback onComplete;

  const _ReminderTile({required this.task, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _priorityColor(theme, task.priority),
            foregroundColor: theme.colorScheme.onPrimary,
            child: const Icon(Icons.alarm, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${task.subject} • ${_relativeDue(task.dueDate)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(onPressed: onComplete, child: const Text('Done')),
        ],
      ),
    );
  }

  Color _priorityColor(ThemeData theme, String priority) {
    switch (priority) {
      case 'high':
        return theme.colorScheme.error;
      case 'low':
        return Colors.green.shade600;
      default:
        return theme.colorScheme.primary;
    }
  }

  String _relativeDue(DateTime dueDate) {
    final now = DateTime.now();
    final diff = dueDate.difference(now);
    if (diff.inHours < 0) {
      return 'Overdue';
    }
    if (diff.inHours < 24) {
      return 'Due in ${diff.inHours}h';
    }
    return 'Due in ${diff.inDays}d';
  }
}

class _TaskTile extends StatelessWidget {
  final StudyTask task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _TaskTile({
    required this.task,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Checkbox(value: task.completed, onChanged: (_) => onToggle()),
        title: Text(
          task.title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            decoration: task.completed ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniChip(label: task.subject),
              _MiniChip(label: '${task.estimatedMinutes} min'),
              _MiniChip(label: _priorityLabel(task.priority)),
              _MiniChip(label: _formatDueDate(task.dueDate)),
            ],
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Delete task',
          onPressed: onDelete,
        ),
      ),
    );
  }

  String _priorityLabel(String priority) {
    switch (priority) {
      case 'high':
        return 'High priority';
      case 'low':
        return 'Low priority';
      default:
        return 'Medium priority';
    }
  }

  String _formatDueDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _StudyBar extends StatelessWidget {
  final String label;
  final int minutes;
  final int maxMinutes;

  const _StudyBar({
    required this.label,
    required this.minutes,
    required this.maxMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = maxMinutes <= 0 ? 0.0 : minutes / maxMinutes;
    final height = 26 + (ratio * 84);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('$minutes', style: theme.textTheme.labelSmall),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 26,
            height: height,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String status;

  const _FeatureRow({
    required this.title,
    required this.subtitle,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _StatusChip(status: status),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _statusColors(theme, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: theme.textTheme.labelMedium?.copyWith(
          color: colors.$2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  (Color, Color) _statusColors(ThemeData theme, String value) {
    switch (value) {
      case 'Live':
        return (Colors.green.shade100, Colors.green.shade900);
      case 'Beta':
        return (Colors.orange.shade100, Colors.orange.shade900);
      case 'In-app':
        return (
          theme.colorScheme.secondaryContainer,
          theme.colorScheme.onSecondaryContainer,
        );
      default:
        return (
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.onSurface,
        );
    }
  }
}

class _MiniChip extends StatelessWidget {
  final String label;

  const _MiniChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: theme.textTheme.labelMedium),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;

  const _SectionHeader({required this.title, this.actionLabel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (actionLabel != null)
          Text(
            actionLabel!,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}
