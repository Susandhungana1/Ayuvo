/// The account tab: who you are signed in as, everything that is not a
/// bottom-bar tab, and the way out.
///
/// Two versions of the same screen, because the two roles own different
/// things. A doctor has no medicines, no reports and no emergency card — the
/// router keeps them out of `/more/*` entirely — so showing them a Documents
/// tile that redirects home would be worse than not showing it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/range_bar.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  static const _patientDestinations = <_Destination>[
    _Destination(
      route: Routes.appointments,
      icon: Icons.event_outlined,
      title: 'Appointments',
      subtitle: 'Book a doctor, or keep a reminder of one you booked yourself',
    ),
    _Destination(
      route: Routes.documents,
      icon: Icons.folder_outlined,
      title: 'Documents',
      subtitle: 'Visits, and the files each one produced',
    ),
    _Destination(
      route: Routes.share,
      icon: Icons.ios_share,
      title: 'Sharing',
      subtitle: 'Links that let a doctor read your record without an account',
    ),
    _Destination(
      route: Routes.emergency,
      icon: Icons.emergency_outlined,
      title: 'Emergency ID',
      subtitle: 'Blood type, allergies and who to call, behind a QR',
    ),
  ];

  static const _doctorDestinations = <_Destination>[
    _Destination(
      route: Routes.doctorProfile,
      icon: Icons.badge_outlined,
      title: 'Doctor profile',
      subtitle: 'Your NMC registration and verification status',
    ),
  ];

  static const _comingLater = <(String, String)>[
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
    final isDoctor = user?.isDoctor ?? false;
    final destinations = isDoctor ? _doctorDestinations : _patientDestinations;

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
                      label: isDoctor ? 'Doctor account' : 'Patient',
                      status: RangeStatus.ok,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          Card(
            child: Column(
              children: [
                for (final destination in destinations)
                  ListTile(
                    key: ValueKey(destination.route),
                    leading: Icon(destination.icon),
                    title: Text(destination.title),
                    subtitle: Text(destination.subtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go(destination.route),
                  ),
              ],
            ),
          ),
          if (!isDoctor) ...[
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
          ],
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

class _Destination {
  const _Destination({
    required this.route,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final String route;
  final IconData icon;
  final String title;

  /// What is behind the tile, in one line. A list of nouns makes people tap
  /// each one to find out; a sentence does not.
  final String subtitle;
}
