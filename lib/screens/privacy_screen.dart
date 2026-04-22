import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  Future<void> _copy(BuildContext context, String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Data')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Homework AI processes homework text and images to generate study help. '
                'Use this screen as the in-app privacy notice, and add the same policy '
                'to a public URL in Play Console before publishing.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'What the app uses',
            body:
                'Camera access is used only when you choose to scan homework. '
                'Gallery access is used only when you select an image to upload. '
                'OCR is performed on-device before the app asks the AI service for an answer.',
          ),
          _SectionCard(
            title: 'What is sent off the device',
            body:
                'When you ask for an answer or continue a chat, the text you entered and any image you attached are sent over HTTPS to the configured AI provider so it can generate a response.',
          ),
          _SectionCard(
            title: 'What stays on the device',
            body:
                'Your recent problem history is stored locally on the device so you can revisit past questions. Temporary image files may be stored in the app cache while a scan is being processed.',
          ),
          _SectionCard(
            title: 'How to delete data',
            body:
                'You can remove saved history from the History tab. Uninstalling the app removes app storage and cached files.',
          ),
          _SectionCard(
            title: 'Ads, accounts, and payments',
            body:
                'This build does not include ads, user accounts, or in-app purchases.',
          ),
          const SizedBox(height: 12),
          _ValueCard(
            title: 'Support email',
            value: AppConfig.hasSupportEmail
                ? AppConfig.supportEmail
                : 'Not configured. Set --dart-define=SUPPORT_EMAIL=you@example.com before publishing.',
            onCopy: AppConfig.hasSupportEmail
                ? () => _copy(context, 'Support email', AppConfig.supportEmail)
                : null,
          ),
          _ValueCard(
            title: 'Public privacy policy URL',
            value: AppConfig.hasPrivacyPolicyUrl
                ? AppConfig.privacyPolicyUrl
                : 'Not configured. Set --dart-define=PRIVACY_POLICY_URL=https://your-domain/privacy before publishing.',
            onCopy: AppConfig.hasPrivacyPolicyUrl
                ? () => _copy(
                    context,
                    'Privacy policy URL',
                    AppConfig.privacyPolicyUrl,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String body;

  const _SectionCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(body),
          ],
        ),
      ),
    );
  }
}

class _ValueCard extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback? onCopy;

  const _ValueCard({required this.title, required this.value, this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(title),
        subtitle: Text(value),
        trailing: onCopy == null
            ? null
            : IconButton(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_outlined),
                tooltip: 'Copy',
              ),
      ),
    );
  }
}
