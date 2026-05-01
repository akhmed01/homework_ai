import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/user_profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _schoolController = TextEditingController();
  final _bioController = TextEditingController();

  bool _initialized = false;
  bool _saving = false;
  String _gradeLevel = '';
  String _responseLanguageCode = 'en';
  int _dailyGoalMinutes = 45;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }

    final profile = context.read<UserProfileService>().profile;
    _displayNameController.text = profile.displayName;
    _emailController.text = profile.email;
    _schoolController.text = profile.schoolName;
    _bioController.text = profile.bio;
    _gradeLevel = profile.gradeLevel;
    _responseLanguageCode = profile.responseLanguageCode;
    _dailyGoalMinutes = profile.dailyGoalMinutes;
    _initialized = true;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _schoolController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);

    await context.read<UserProfileService>().saveProfile(
      displayName: _displayNameController.text,
      email: _emailController.text,
      schoolName: _schoolController.text,
      gradeLevel: _gradeLevel,
      bio: _bioController.text,
      responseLanguageCode: _responseLanguageCode,
      dailyGoalMinutes: _dailyGoalMinutes,
    );

    if (!mounted) {
      return;
    }

    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile saved')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileService = context.watch<UserProfileService>();

    if (!profileService.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving...' : 'Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        child: Text(
                          profileService.initials,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _displayNameController.text.trim().isEmpty
                                  ? 'Student'
                                  : _displayNameController.text.trim(),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              profileService.profileStatusSubtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer
                                    .withValues(alpha: 0.8),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _PillLabel(label: profileService.profileStatusLabel),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profile completion',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: profileService.completionProgress,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${(profileService.completionProgress * 100).round()}% complete',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Basic Info',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _displayNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Display name',
                          hintText: 'How should the app address you?',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter a display name.';
                          }
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'Used later for sign-in or sync',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _schoolController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'School',
                          hintText: 'Optional',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _gradeLevel.isEmpty ? '' : _gradeLevel,
                        items: UserProfileService.supportedGradeLevels
                            .map(
                              (grade) => DropdownMenuItem<String>(
                                value: grade,
                                child: Text(grade.isEmpty ? 'Not set' : grade),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() => _gradeLevel = value ?? '');
                        },
                        decoration: const InputDecoration(
                          labelText: 'Grade level',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _bioController,
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'About your learning goals',
                          hintText:
                              'Example: I want clearer math explanations and faster review before exams.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Tutor Preferences',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _responseLanguageCode,
                        items: UserProfileService.supportedLanguages.entries
                            .map(
                              (entry) => DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _responseLanguageCode = value);
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'AI answer language',
                          border: OutlineInputBorder(),
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
                        children: const [30, 45, 60, 90]
                            .map(
                              (minutes) => _GoalChoice(
                                minutes: minutes,
                                selected: _dailyGoalMinutes == minutes,
                                onSelected: () {
                                  setState(() => _dailyGoalMinutes = minutes);
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Cloud Status',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.cloud_done_outlined,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Cloud project detected',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Firebase project files already exist in this repository, but the Flutter app is still saving profile data locally. The next backend step is wiring Firebase Auth plus a synced profile store such as Firestore.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving...' : 'Save profile'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalChoice extends StatelessWidget {
  final int minutes;
  final bool selected;
  final VoidCallback onSelected;

  const _GoalChoice({
    required this.minutes,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text('$minutes min'),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _PillLabel extends StatelessWidget {
  final String label;

  const _PillLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
