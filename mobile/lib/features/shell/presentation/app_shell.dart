/// The bottom-navigation frame, in the two shapes this product has.
///
/// A patient gets five destinations; a doctor gets three, because the doctor
/// surfaces are an inbox and a calendar and nothing else. Which one you see is
/// decided by the router, not by hiding tabs at runtime — see `app_router.dart`.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.shell,
    required this.destinations,
  });

  final StatefulNavigationShell shell;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        destinations: destinations,
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
const patientDestinations = <NavigationDestination>[
  NavigationDestination(
    icon: Icon(Icons.home_outlined),
    selectedIcon: Icon(Icons.home),
    label: 'Home',
  ),
  NavigationDestination(
    icon: Icon(Icons.medication_outlined),
    selectedIcon: Icon(Icons.medication),
    label: 'Medicines',
  ),
  NavigationDestination(
    icon: Icon(Icons.monitor_heart_outlined),
    selectedIcon: Icon(Icons.monitor_heart),
    label: 'Vitals',
  ),
  NavigationDestination(
    icon: Icon(Icons.description_outlined),
    selectedIcon: Icon(Icons.description),
    label: 'Reports',
  ),
  NavigationDestination(
    icon: Icon(Icons.person_outline),
    selectedIcon: Icon(Icons.person),
    label: 'Account',
  ),
];

const doctorDestinations = <NavigationDestination>[
  NavigationDestination(
    icon: Icon(Icons.inbox_outlined),
    selectedIcon: Icon(Icons.inbox),
    label: 'Appointments',
  ),
  NavigationDestination(
    icon: Icon(Icons.event_available_outlined),
    selectedIcon: Icon(Icons.event_available),
    label: 'Availability',
  ),
  NavigationDestination(
    icon: Icon(Icons.person_outline),
    selectedIcon: Icon(Icons.person),
    label: 'Account',
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
