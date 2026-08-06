/// The account tab: who you are signed in as, and the way out.
///
/// Settings proper (profile, two-factor, theme, language, caretakers) is a
/// phase 6 screen; what is here now is the part the foundation actually owns.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/range_bar.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  static const _comingLater = <(String, String)>[
    ('Documents and attachments', 'Phase 4'),
    ('Appointments and doctors', 'Phase 5'),
    ('Share links and emergency ID', 'Phase 5'),
    ('Timeline, search and the assistant', 'Phase 6'),
    ('Caretakers, reminders and Nepali', 'Phase 6'),
  ];

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Your records stay on the server. You will need your password to '
          'get back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay signed in'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      // The router is listening to the session; it moves to sign-in by itself.
      await ref.read(sessionControllerProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          if (user != null)
            Card(
              child: Padding(
                padding: AppSpacing.card,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name, style: context.texts.titleLarge),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(user.email, style: context.texts.bodyMedium),
                    const SizedBox(height: AppSpacing.md),
                    StatusChip(
                      label: user.isDoctor ? 'Doctor account' : 'Patient',
                      status: RangeStatus.ok,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          Text('Coming next', style: context.texts.titleLarge),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Padding(
              padding: AppSpacing.card,
              child: Column(
                children: [
                  for (final (label, phase) in _comingLater)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: context.texts.bodyMedium,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(phase, style: context.texts.bodySmall),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton.icon(
            onPressed: () => _confirmSignOut(context, ref),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
