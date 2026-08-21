/// Contact MediStore — mirrors the web page at /contact.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_tokens.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Contact Us')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          Text(
            'Have questions about MediStore? Need help setting up your account? Reach out and we will get back to you as soon as possible.',
            style: textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.mail_outline,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              title: const Text('Email'),
              subtitle: const Text(
                'quorlytechnologies@gmail.com',
                style: TextStyle(fontSize: 13),
              ),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                final opened = await launchUrl(
                  Uri.parse(
                    'mailto:quorlytechnologies@gmail.com'
                    '?subject=MediStore support',
                  ),
                  mode: LaunchMode.externalApplication,
                );
                if (!opened && context.mounted) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Could not open the email app')),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.language,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              title: const Text('Company Website'),
              subtitle: const Text(
                'www.quorlyn.com.np',
                style: TextStyle(fontSize: 13),
              ),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                final opened = await launchUrl(
                  Uri.parse('https://www.quorlyn.com.np'),
                  mode: LaunchMode.externalApplication,
                );
                if (!opened && context.mounted) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Could not open the website')),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Card(
            child: Padding(
              padding: AppSpacing.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Help us help you faster',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'A message with a few details gets answered in one pass instead of three:',
                    style: textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final tip in const [
                    'Your user ID (the one beginning with #hos)',
                    'The page or report the problem is about',
                    'What you expected, and what happened instead',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Icon(
                              Icons.circle,
                              size: 6,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              tip,
                              style: textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}