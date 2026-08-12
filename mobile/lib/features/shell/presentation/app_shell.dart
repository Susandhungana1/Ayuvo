/// The bottom-navigation frame, in the two shapes this product has.
///
/// A patient gets five destinations; a doctor gets three, because the doctor
/// surfaces are an inbox and a calendar and nothing else. Which one you see is
/// decided by the router, not by hiding tabs at runtime — see `app_router.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/notifications/reminder_sync.dart';
import '../../../core/notifications/reminders.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';

/// Which set of tabs to draw. The labels are looked up at build time rather
/// than baked into a const list, so switching to Nepali relabels the bar
/// without a restart.
enum ShellKind { patient, doctor }

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell, required this.kind});

  final StatefulNavigationShell shell;
  final ShellKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mounted here, at the root of the signed-in app, because this is the
    // widest scope that exists exactly while somebody is signed in. Reminders
    // are rescheduled whenever the medicine list or the setting changes, and
    // the seven-day window rolls forward every time the app is opened.
    ref.watch(reminderSyncProvider);

    // Pre-warm the reminders backend before the user can reach the toggle: on
    // web this registers the service worker and fetches the VAPID key, so that
    // creating the push subscription stays the first awaited call of the
    // user's tap (iOS revokes the gesture token at any earlier await).
    ref.read(remindersProvider).initialise();

    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        destinations: switch (kind) {
          ShellKind.patient => patientDestinations(context.l10n),
          ShellKind.doctor => doctorDestinations(context.l10n),
        },
        onDestinationSelected: (index) => shell.goBranch(
          index,
          // Tapping the tab you are already on returns it to its root, which is
          // what every platform's bottom bar does.
          initialLocation: index == shell.currentIndex,
        ),
      ),
    );
  }
}

/// The five patient destinations, in the order DESIGN.md fixes them.
List<NavigationDestination> patientDestinations(AppL10n l10n) => [
      NavigationDestination(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home),
        label: l10n.navHome,
      ),
      NavigationDestination(
        icon: const Icon(Icons.medication_outlined),
        selectedIcon: const Icon(Icons.medication),
        label: l10n.navMedicines,
      ),
      NavigationDestination(
        icon: const Icon(Icons.monitor_heart_outlined),
        selectedIcon: const Icon(Icons.monitor_heart),
        label: l10n.navVitals,
      ),
      NavigationDestination(
        icon: const Icon(Icons.description_outlined),
        selectedIcon: const Icon(Icons.description),
        label: l10n.navReports,
      ),
      NavigationDestination(
        icon: const Icon(Icons.person_outline),
        selectedIcon: const Icon(Icons.person),
        label: l10n.navAccount,
      ),
    ];

List<NavigationDestination> doctorDestinations(AppL10n l10n) => [
      NavigationDestination(
        icon: const Icon(Icons.inbox_outlined),
        selectedIcon: const Icon(Icons.inbox),
        label: l10n.navAppointments,
      ),
      NavigationDestination(
        icon: const Icon(Icons.event_available_outlined),
        selectedIcon: const Icon(Icons.event_available),
        label: l10n.navAvailability,
      ),
      NavigationDestination(
        icon: const Icon(Icons.person_outline),
        selectedIcon: const Icon(Icons.person),
        label: l10n.navAccount,
      ),
    ];

/// Shown for the moment between launch and knowing whether there is a stored
/// session. Deliberately quiet: it is usually on screen for one frame.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}
