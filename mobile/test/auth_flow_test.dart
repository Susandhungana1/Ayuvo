/// The auth flow as a user meets it: land, fail, succeed, prove a second
/// factor, and leave — with the router deciding where each of those ends up.
///
/// No `pumpAndSettle` anywhere in here on purpose. A submit button that is
/// waiting shows a progress indicator, and a loading card shows a pulsing
/// skeleton; both schedule frames forever, so settling would hang rather than
/// fail. Explicit pumps also make the intermediate states assertable.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ayuvo/app.dart';
import 'package:ayuvo/core/health/health_providers.dart';
import 'package:ayuvo/core/network/api_exception.dart';
import 'package:ayuvo/core/network/network_providers.dart';
import 'package:ayuvo/core/notifications/reminders.dart';
import 'package:ayuvo/core/security/biometric_service.dart';
import 'package:ayuvo/core/session/session_controller.dart';
import 'package:ayuvo/core/storage/local_store.dart';
import 'package:ayuvo/core/storage/session_store.dart';
import 'package:ayuvo/features/auth/data/auth_repository.dart';
import 'package:ayuvo/features/shell/presentation/more_screen.dart';

import 'support/fake_api.dart';
import 'support/fakes.dart';
import 'support/harness.dart';

Future<FakeAuthRepository> pumpApp(
  WidgetTester tester, {
  String? stored,
  FakeAuthRepository? repository,
}) async {
  final repo = repository ?? FakeAuthRepository();
  // The dashboard behind the sign-in screen fetches as soon as it mounts, so
  // even an auth test needs a backend. An empty one is the honest default: a
  // brand-new account has no medicines and no readings. The doctor shell's two
  // tabs are here too, because which shell you land in is what one of these
  // tests is about.
  final api = FakeApi()
    ..json('GET /api/medicines', {'medicines': const []})
    ..json('GET /api/vitals', {'vitals': const []})
    ..json('GET /api/appointments', {'appointments': const []})
    ..json('GET /api/reports', {'reports': const [], 'total': 0})
    ..json('GET /api/medicines/intake/log', {'intakes': const []})
    ..json('GET /api/appointments/doctor/my-appointments',
        {'appointments': const []})
    ..json('GET /api/doctors/availability', {'availability': const []});

  // The medical disclaimer is a modal layer over every route on first launch,
  // and it would cover the screens these tests are about. Pre-accepted here for
  // the same reason `pumpSignedIn` pre-accepts it; `medical_disclaimer_test`
  // is the one that leaves it unset.
  final localStore = InMemoryLocalStore();
  await localStore.write(
    'security.v1',
    jsonEncode({'disclaimer_accepted': true}),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionStoreProvider.overrideWithValue(InMemorySessionStore(stored)),
        authRepositoryProvider.overrideWithValue(repo),
        healthProvider.overrideWith((ref) async => testHealth),
        // Both are method channels with nobody answering in a `flutter test`,
        // and an unanswered channel hangs rather than throwing — which would
        // wedge the medicine list the dashboard is waiting on.
        localStoreProvider.overrideWithValue(localStore),
        remindersProvider.overrideWithValue(NoReminders()),
        biometricServiceProvider
            .overrideWithValue(const UnavailableBiometricService()),
        apiClientProvider.overrideWith((ref) {
          final client = api.client();
          ref.onDispose(client.close);
          return client;
        }),
      ],
      child: const AyuvoApp(),
    ),
  );
  // Read the keystore, resolve the session, let the router redirect, then let
  // the page transition finish — until it does, go_router wraps the incoming
  // route in an IgnorePointer and every tap silently misses.
  await settle(tester);
  return repo;
}

/// "Good morning/afternoon/evening, Ram" — the hour is the machine's, so the
/// assertion is on the ending.
Finder greeting(String name) => find.byWidgetPredicate(
      (widget) => widget is Text && (widget.data?.endsWith(', $name') ?? false),
      description: 'greeting ending ", $name"',
    );

Future<void> signIn(
  WidgetTester tester, {
  String email = 'ram@example.com',
  String password = 'hunter2hunter2',
}) async {
  await tester.enterText(find.byType(TextFormField).first, email);
  await tester.enterText(find.byType(TextFormField).last, password);
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await tester.pump();
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('a fresh install lands on sign-in', (tester) async {
    await pumpApp(tester);

    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    expect(find.text('Your health record, on your phone.'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('the wrong password is explained, and the user stays put',
      (tester) async {
    await pumpApp(
      tester,
      repository: FakeAuthRepository(
        loginError: const ApiException(
          ApiErrorKind.credentials,
          'Invalid credentials',
          statusCode: 401,
        ),
      ),
    );

    await signIn(tester, password: 'wrong-password');

    expect(find.text('Your email or password is incorrect.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });

  testWidgets('a rate-limited sign-in says how to recover', (tester) async {
    await pumpApp(
      tester,
      repository: FakeAuthRepository(
        loginError: const ApiException(
          ApiErrorKind.rateLimited,
          'Too many attempts.',
          statusCode: 429,
        ),
      ),
    );

    await signIn(tester);

    expect(
      find.text('Too many sign-in attempts. Wait a minute and try again.'),
      findsOneWidget,
    );
  });

  testWidgets('signing in reaches the patient home', (tester) async {
    await pumpApp(tester);

    await signIn(tester);

    expect(greeting('Ram'), findsOneWidget);
    expect(find.text('Medicines'), findsOneWidget, reason: 'the bottom bar');
    // The dashboard loaded from the (empty) backend rather than sitting on a
    // skeleton: "Get started" renders only once both lists have arrived.
    expect(find.text('No medicines yet'), findsOneWidget);
  });

  testWidgets('a 2FA account is asked for a code, then let in', (tester) async {
    final repo = await pumpApp(
      tester,
      repository: FakeAuthRepository(requiresTwoFactor: true),
    );

    await signIn(tester);

    expect(find.text('Two-factor code'), findsOneWidget);
    expect(greeting('Ram'), findsNothing);

    // A wrong code is rejected without losing the credentials.
    await tester.enterText(find.byType(TextFormField).first, '000000');
    await tester.tap(find.widgetWithText(FilledButton, 'Verify'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining("That code didn't work"), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Verify'));
    await settle(tester);

    expect(greeting('Ram'), findsOneWidget);
    // Password sent twice, code only on the second attempt — the server needs
    // both together, which is what the challenge flow is for.
    expect(repo.loginCalls.map((c) => c.code).toList(),
        [null, '000000', '123456']);
  });

  testWidgets('a legacy session with no refresh token explains itself',
      (tester) async {
    await pumpApp(
      tester,
      stored: storedSession(
        token: fakeJwt(expiresIn: -const Duration(days: 1)),
        refreshToken: null,
      ),
    );

    expect(find.textContaining('ran out'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });

  testWidgets('a stored session opens straight into the app', (tester) async {
    await pumpApp(tester, stored: storedSession());

    expect(greeting('Ram'), findsOneWidget);
  });

  testWidgets('a doctor gets the doctor shell, not the patient one',
      (tester) async {
    await pumpApp(
      tester,
      stored: storedSession(user: testDoctor),
      repository: FakeAuthRepository(user: testDoctor),
    );

    expect(find.text('Availability'), findsOneWidget);
    expect(find.text('Medicines'), findsNothing);
    // The doctor's inbox tab, now a coming-soon placeholder.
    expect(find.text('Coming soon'), findsOneWidget);
  });

  testWidgets('signing out returns to sign-in', (tester) async {
    await pumpApp(tester, stored: storedSession());

    await openTab(tester, 'Account');
    expect(find.text('ram@example.com'), findsOneWidget);

    // Sign out sits below the fold now that Documents lives on this screen.
    await tapAfterScroll(
      tester,
      find.widgetWithText(OutlinedButton, 'Sign out'),
      scrollable: scrollableIn(MoreScreen),
    );

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Sign out'),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });

  testWidgets('sign-in survives 2.0x text on a small phone', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await pumpApp(tester);

    // An overflow would already have failed the test by now.
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });
}
