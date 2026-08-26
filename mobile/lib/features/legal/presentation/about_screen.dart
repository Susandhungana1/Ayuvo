/// About Ayuvo and Quorlyn — mirrors the web page at /about.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_tokens.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _founders = [
    (name: 'Susan Dhungana', role: 'Co-Founder & Director', initials: 'SD'),
    (name: 'Sandip Bhusal', role: 'Co-Founder & Director', initials: 'SB'),
    (name: 'Anuj Bhusal', role: 'Co-Founder & Director', initials: 'AB'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('About Ayuvo')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          Text(
            'Ayuvo is your personal digital health store — a secure platform to store medical records, track vital signs, manage medications, book appointments, generate reports, and share your health data with doctors — all in one place.',
            style: textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _Section(
            title: 'Our Company',
            child: Text(
              'Ayuvo is built and published by Quorlyn, a technology company focused on products that make everyday life simpler and more secure. Quorlyn brings together a team of founders and directors who care about building software that people can trust with what matters most.',
              style: textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ),
          _Section(
            title: 'Meet the Founders',
            child: Column(
              children: [
                for (final founder in _founders)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        founder.initials,
                        style: textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      founder.name,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(founder.role),
                  ),
              ],
            ),
          ),
          _Section(
            title: 'What We Do',
            child: Text(
              'Ayuvo lets you upload and organize lab results, prescriptions, and medical history, track vital signs like blood pressure, heart rate, blood sugar, and weight, manage your medications with dose reminders, book appointments with doctors, generate AI-powered medical reports, and share records securely via expiring links.',
              style: textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ),
          _Section(
            title: 'Company Website',
            child: TextButton.icon(
              onPressed: () async {
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
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('www.quorlyn.com.np'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(child: Padding(padding: AppSpacing.card, child: child)),
        ],
      ),
    );
  }
}