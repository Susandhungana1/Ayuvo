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

import '../../features/appointments/presentation/appointments_screen.dart';
import '../../features/assistant/presentation/assistant_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/care/presentation/caretakers_screen.dart';
import '../../features/doctors/presentation/availability_screen.dart';
import '../../features/doctors/presentation/doctor_inbox_screen.dart';
import '../../features/doctors/presentation/doctor_profile_screen.dart';
import '../../features/documents/presentation/documents_screen.dart';
import '../../features/emergency/presentation/emergency_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/medicines/presentation/medicines_screen.dart';
import '../../features/nearby/presentation/nearby_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/sharing/presentation/share_screen.dart';
import '../../features/sharing/presentation/shared_record_screen.dart';
import '../../features/sharing/presentation/shared_report_screen.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../../features/shell/presentation/more_screen.dart';
import '../../features/timeline/presentation/timeline_screen.dart';
import '../../features/vitals/presentation/vitals_screen.dart';
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
  // Public share readers first: the token is the credential and there is no
  // session requirement, so nothing below may send a signed-in or signed-out
  // visitor elsewhere before the reader loads.
  //
  // A prefix check, not a pattern-list check: `location` is `matchedLocation`,
  // the *resolved* path (`/share/qr-code/ABC123`), never the route pattern
  // (`/share/qr-code/:token`), so comparing against the pattern list can never
  // match. No authenticated route lives under `/share/` (the owner's sharing
  // screen is `/more/share`), which is what makes the prefix safe.
  if (location.startsWith(Routes.sharePrefix)) return null;

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
  // Public share readers — a recipient has no account, so these live outside
  // the shells and bypass the session redirect entirely.
  GoRoute(
    path: Routes.shareQrCode,
    builder: (context, state) =>
        SharedRecordScreen(token: state.pathParameters['token']!),
  ),
  GoRoute(
    path: Routes.shareSingle,
    builder: (context, state) =>
        SharedReportScreen(token: state.pathParameters['token']!),
  ),
  StatefulShellRoute.indexedStack(
    builder: (context, state, shell) =>
        AppShell(shell: shell, kind: ShellKind.patient),
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
            builder: (context, state) => const MedicinesScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: Routes.vitals,
            builder: (context, state) => const VitalsScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: Routes.reports,
            builder: (context, state) => const ReportsScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: Routes.more,
            builder: (context, state) => const MoreScreen(),
            routes: [
              // Relative, so each resolves under Routes.more.
              GoRoute(
                path: 'documents',
                builder: (context, state) => const DocumentsScreen(),
              ),
              GoRoute(
                path: 'appointments',
                builder: (context, state) => const AppointmentsScreen(),
              ),
              GoRoute(
                path: 'share',
                builder: (context, state) => const ShareScreen(),
              ),
              GoRoute(
                path: 'emergency',
                builder: (context, state) => const EmergencyScreen(),
              ),
              GoRoute(
                path: 'timeline',
                builder: (context, state) => const TimelineScreen(),
              ),
              GoRoute(
                path: 'search',
                builder: (context, state) => const SearchScreen(),
              ),
              GoRoute(
                path: 'assistant',
                builder: (context, state) => const AssistantScreen(),
              ),
              GoRoute(
                path: 'nearby',
                builder: (context, state) => const NearbyScreen(),
              ),
              // Reachable even when `/health` says the feature is off: the
              // screen itself explains that, which is more useful than a tile
              // that silently is not there. The tile on Account *is* hidden.
              GoRoute(
                path: 'caretakers',
                builder: (context, state) => const CaretakersScreen(),
              ),
              GoRoute(
                path: 'settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  ),
  StatefulShellRoute.indexedStack(
    builder: (context, state, shell) =>
        AppShell(shell: shell, kind: ShellKind.doctor),
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: Routes.doctorAppointments,
            builder: (context, state) => const DoctorInboxScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: Routes.doctorAvailability,
            builder: (context, state) => const AvailabilityScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: Routes.doctorMore,
            builder: (context, state) => const MoreScreen(),
            routes: [
              GoRoute(
                path: 'profile',
                builder: (context, state) => const DoctorProfileScreen(),
              ),
              GoRoute(
                path: 'settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  ),
];
