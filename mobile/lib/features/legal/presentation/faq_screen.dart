/// Frequently asked questions — mirrors the web page at /faq.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const _faqs = [
    (
      q: 'Is my medical data safe with MediStore?',
      a: 'Yes. Your data is stored securely in an encrypted database, locked behind your account, and never sold or shared without your consent. You control exactly what you share and for how long.',
    ),
    (
      q: 'Is MediStore a medical service?',
      a: 'No. MediStore is a storage and management tool for your health records. It does not provide medical advice, diagnosis, or treatment. Always consult a qualified healthcare provider for medical decisions.',
    ),
    (
      q: 'Who can see my records?',
      a: 'Only you, unless you deliberately share them. Doctors you book appointments with and caretakers you invite see only what you authorize, and share links expire automatically after the time you choose.',
    ),
    (
      q: 'How does sharing a report work?',
      a: 'You generate a secure link with an expiry time and send it to a doctor or family member. The link opens a read-only view of that single report and stops working once it expires.',
    ),
    (
      q: 'Is MediStore free?',
      a: 'Yes. Creating an account and using all core features — vitals, medicines, reports, appointments, and sharing — is free.',
    ),
    (
      q: 'How do I book an appointment with a doctor?',
      a: 'Browse available doctors, check their availability, pick a free time slot, and confirm. The system validates the slot is still free at the moment you book, so double-booking is prevented.',
    ),
    (
      q: 'Can I use MediStore on my phone?',
      a: 'Yes. MediStore has a mobile app for Android and iOS alongside the website, so your records are available wherever you are.',
    ),
    (
      q: 'How do I delete my account and data?',
      a: 'Contact us at quorlytechnologies@gmail.com and we will delete your account and associated data. You can also delete individual records, documents, and reports from within the app at any time.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('FAQ')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          Text(
            'Answers to the questions people ask before trusting MediStore with their records.',
            style: textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Column(
              children: [
                for (final (index, faq) in _faqs.indexed) ...[
                  if (index > 0) const Divider(height: 1),
                  ExpansionTile(
                    shape: const Border(),
                    title: Text(
                      faq.q,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          faq.a,
                          style: textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Still have questions? Write to us at quorlytechnologies@gmail.com',
            style: textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}