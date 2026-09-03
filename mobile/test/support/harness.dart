/// Pumping the real app with a scripted backend behind it.
///
/// Widget tests here drive `AyuvoApp` itself — the real router, the real
/// shell, the real controllers — with only the socket replaced. That is what
/// makes an assertion about a screen worth something: the row it shows came
/// out of JSON the server would really send.
///
/// **No `pumpAndSettle` anywhere.** A loading card pulses forever and a
/// submitting button spins forever, so "no frames scheduled" never arrives.
/// [settle] pumps a fixed number of frames instead, which also leaves the
/// intermediate states assertable.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ayuvo/app.dart';
import 'package:ayuvo/core/health/health_providers.dart';
import 'package:ayuvo/core/health/health_status.dart';
import 'package:ayuvo/core/network/network_providers.dart';
import 'package:ayuvo/core/notifications/reminders.dart';
import 'package:ayuvo/core/security/biometric_service.dart';
import 'package:ayuvo/core/session/session_controller.dart';
import 'package:ayuvo/core/storage/local_store.dart';
import 'package:ayuvo/core/storage/session_store.dart';
import 'package:ayuvo/features/auth/data/auth_repository.dart';
import 'package:ayuvo/features/auth/domain/auth_user.dart';

import 'fake_api.dart';
import 'fakes.dart';

/// What most deployments look like: caretakers off.
///
/// Deliberately the default, because it is what production runs today and
/// because the caretaker surfaces are supposed to be *completely* absent when
/// the flag is off — a test that never sees them is the assertion.
const testHealth = HealthStatus(
  status: 'ok',
  database: true,
  email: 'brevo',
  caretaker: false,
);

/// A server with `CARETAKER_ENABLED=true`. Pass to [pumpSignedIn] for the care
/// screens; anything that uses it must script `GET /api/care/links`.
const caretakerHealth = HealthStatus(
  status: 'ok',
  database: true,
  email: 'brevo',
  caretaker: true,
);

/// Frames enough for a request to resolve, a rebuild to land, and go_router's
/// transition to finish — until it does, the incoming route sits inside an
/// `IgnorePointer` and every tap silently misses.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
  // Two long frames, not one 500ms frame. A FAB leaving at the same moment a
  // snackbar arrives runs its exit animation and then its move animation, and
  // the second only starts once the first has reported finished — until both
  // are done the departing FAB sits over the snackbar's action and eats the
  // tap. The trailing pump is for the rebuild that removes it.
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

/// Boots the app already signed in, with [api] answering every request.
///
/// Three things are replaced besides the socket, and all of them would
/// otherwise hang rather than fail: [localStoreProvider], because
/// `path_provider` is a method channel with nobody on the other end in a
/// `flutter test`; [remindersProvider], because scheduling one would need three
/// more; and [biometricServiceProvider], because `local_auth` is a fourth and
/// its prompt would never return.
///
/// The medical disclaimer is pre-accepted, because it is a modal layer over
/// every route and a test about the medicine list is not a test about the
/// disclaimer. Pass `disclaimerAccepted: false` to get it, or a [biometrics]
/// that reports an enrolled sensor to get the offer and the lock screen —
/// `security_test.dart` does both.
 Future<void> pumpSignedIn(
  WidgetTester tester,
  FakeApi api, {
  AuthUser user = testUser,
  HealthStatus health = testHealth,
  LocalStore? store,
  Reminders? reminders,
  FakeAuthRepository? auth,
  bool disclaimerAccepted = true,
  BiometricService? biometrics,
}) async {
  // Home reads the calendar and the report shelf too. Fallbacks only: a test
  // that scripts these routes itself keeps its own bodies.
  api.onIfAbsent('GET /api/appointments', (_) => {'appointments': const []});
  api.onIfAbsent(
    'GET /api/reports',
    (_) => {'reports': const [], 'total': 0},
  );
  api.onIfAbsent(
    'GET /api/medicines/intake/log',
    (_) => {'intakes': const []},
  );

  final localStore = store ?? InMemoryLocalStore();
  // Only when the caller has not written its own: a test that seeds
  // `security.v1` to turn biometrics on is describing a returning user, and
  // stamping a bare "disclaimer accepted" over it would erase that.
  if (disclaimerAccepted && await localStore.read('security.v1') == null) {
    await localStore.write(
      'security.v1',
      jsonEncode({'disclaimer_accepted': true}),
    );
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionStoreProvider
            .overrideWithValue(InMemorySessionStore(storedSession(user: user))),
        authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository(user: user)),
        healthProvider.overrideWith((ref) async => health),
        localStoreProvider.overrideWithValue(localStore),
        remindersProvider.overrideWithValue(reminders ?? NoReminders()),
        biometricServiceProvider.overrideWithValue(
          biometrics ?? const UnavailableBiometricService(),
        ),
        apiClientProvider.overrideWith((ref) {
          final client = api.client();
          ref.onDispose(client.close);
          return client;
        }),
      ],
      child: const AyuvoApp(),
    ),
  );
  await settle(tester);
}

/// Lays a whole screen out in one pass.
///
/// The default 800x600 test viewport cuts the home screen off partway down its
/// list, and a widget below the fold is never built — `find.text` reads the
/// element tree, so an assertion about the share card fails because it is
/// off-screen rather than because it is wrong. A tall viewport is how
/// `design_review_test.dart` solves the same problem; the width stays phone-
/// sized so layout is still the one a phone gets.
void useTallViewport(WidgetTester tester, {double width = 400}) {
  tester.view.physicalSize = Size(width, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Taps a bottom-bar destination and waits for the tab to arrive.
Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  ));
  await settle(tester);
}

/// Scrolls [finder] into view without tapping it. See [tapAfterScroll] for why
/// [scrollable] has to be named explicitly.
Future<void> scrollTo(
  WidgetTester tester,
  Finder finder, {
  required Finder scrollable,
}) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: scrollable);
  await tester.pump();
}

/// Taps a widget that may be below the fold.
///
/// [scrollable] matters: the shell keeps every branch alive in an IndexedStack,
/// so `find.byType(Scrollable).first` is as likely to be the Home list as the
/// one on screen. Anchor it to something the target screen definitely shows.
Future<void> tapAfterScroll(
  WidgetTester tester,
  Finder finder, {
  required Finder scrollable,
}) async {
  await tester.scrollUntilVisible(finder, 120, scrollable: scrollable);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

/// `find.text`, tolerant of the space ICU puts before AM/PM.
///
/// `DateFormat.jm()` emits `9:00 AM` — a **narrow no-break space**, not the
/// ordinary one anybody types into a test literal. The two render identically
/// and compare unequal, which turns every assertion on a formatted time into a
/// "found 0 widgets" with two strings that look the same in the failure output.
Finder findText(String expected) => find.byWidgetPredicate(
      (widget) => widget is Text && _spaces(widget.data) == _spaces(expected),
      description: 'text "$expected"',
    );

/// U+202F narrow no-break space and U+00A0 no-break space, both flattened
/// to an ordinary space. Written as escapes because all three are
/// indistinguishable in a source file.
String? _spaces(String? value) =>
    value?.replaceAll('\u202F', ' ').replaceAll('\u00A0', ' ');

/// The outermost scroll view inside [screen].
///
/// Anchoring to a widget that happens to be visible does not survive the first
/// scroll — it goes off screen, the finder stops matching, and the next
/// `scrollUntilVisible` throws "No element". The screen type is always there.
Finder scrollableIn(Type screen) => find
    .descendant(of: find.byType(screen), matching: find.byType(Scrollable))
    .first;
