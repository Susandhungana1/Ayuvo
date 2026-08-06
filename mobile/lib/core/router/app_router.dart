/// Routing, and the one rule that governs it: the router asks the session who
/// you are, and never the other way round.
///
/// Every screen is reachable only through here, so there is a single answer to
/// "can this person see this?" — a signed-out user cannot land inside the app
/// by deep link, and a doctor cannot land in the patient shell.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../../features/shell/presentation/more_screen.dart';
import '../../features/shell/presentation/not_built_yet_screen.dart';
import '../session/session_controller.dart';
import '../session/session_state.dart';
import 'routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionRefresh(ref);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => _redirect(ref, state.matchedLocation),
    routes: _routes,
  );
  ref.onDispose(router.dispose);
  return router;
});

/// Re-runs the redirect whenever the session changes — a sign-in, a sign-out,
/// or a 401 that ended the session from under a screen.
class _SessionRefresh extends ChangeNotifier {
  _SessionRefresh(Ref ref) {
    ref.listen(sessionControllerProvider, (_, _) => notifyListeners());
  }
}

String? _redirect(Ref ref, String location) {
  final asyncSession = ref.read(sessionControllerProvider);
  final atSplash = location == Routes.splash;

  // Still reading the keystore. One frame, usually.
  if (asyncSession.isLoading) return atSplash ? null : Routes.splash;

  final state = asyncSession.valueOrNull;
  final user = state is SignedIn ? state.user : null;
  final isSignedOutRoute = Routes.signedOut.contains(location);

  // An error reading storage lands here too, and signing in fixes it.
  if (user == null) return isSignedOutRoute ? null : Routes.signIn;

  final home = user.isDoctor ? Routes.doctorAppointments : Routes.home;
  if (atSplash || isSignedOutRoute) return home;

  // Doctors live in /doctor/*, everyone else outside it. `front/` gates on
  // `role === 'DOCTOR'` exactly, and this matches so the two apps agree.
  final inDoctorArea = location.startsWith(Routes.doctorPrefix);
  if (user.isDoctor != inDoctorArea) return home;

  return null;
}

final _routes = <RouteBase>[
  GoRoute(
    path: Routes.splash,
    builder: (context, state) => const SplashScreen(),
  ),
  GoRoute(
    path: Routes.signIn,
    builder: (context, state) => const SignInScreen(),
  ),
  GoRoute(
    path: Routes.register,
    builder: (context, state) => const RegisterScreen(),
  ),
  GoRoute(
    path: Routes.forgotPassword,
    builder: (context, state) => const ForgotPasswordScreen(),
  ),
  GoRoute(
    path: Routes.resetPassword,
    builder: (context, state) => const ResetPasswordScreen(),
  ),
  StatefulShellRoute.indexedStack(
    builder: (context, state, shell) =>
        AppShell(shell: shell, destinations: patientDestinations),
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: Routes.home,
            builder: (context, state) => const HomeScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: Routes.medicines,
            builder: (context, state) => const NotBuiltYetScreen(
              title: 'Medicines',
              icon: Icons.medication_outlined,
              phase: 'phase 4',
              summary: 'Your schedule, intake logging, interaction warnings '
                  'and anything you have retired.',
            ),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: Routes.vitals,
            builder: (context, state) => const NotBuiltYetScreen(
              title: 'Vitals',
              icon: Icons.monitor_heart_outlined,
              phase: 'phase 4',
              summary: 'Readings against their normal range, and how they '
                  'have moved over time.',
            ),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: Routes.reports,
            builder: (context, state) => const NotBuiltYetScreen(
              title: 'Reports',
              icon: Icons.description_outlined,
              phase: 'phase 4',
              summary: 'Uploads, lab analysis, and a plain-language read of '
                  'what a report says.',
            ),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: Routes.more,
            builder: (context, state) => const MoreScreen(),
          ),
        ],
      ),
    ],
  ),
  StatefulShellRoute.indexedStack(
    builder: (context, state, shell) =>
        AppShell(shell: shell, destinations: doctorDestinations),
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: Routes.doctorAppointments,
            builder: (context, state) => const NotBuiltYetScreen(
              title: 'Appointments',
              icon: Icons.inbox_outlined,
              phase: 'phase 5',
              summary: 'The requests your patients have sent, and the status '
                  'changes you can make to them.',
            ),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: Routes.doctorAvailability,
            builder: (context, state) => const NotBuiltYetScreen(
              title: 'Availability',
              icon: Icons.event_available_outlined,
              phase: 'phase 5',
              summary: 'The hours you offer, per weekday, that patients can '
                  'book against.',
            ),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: Routes.doctorMore,
            builder: (context, state) => const MoreScreen(),
          ),
        ],
      ),
    ],
  ),
];
