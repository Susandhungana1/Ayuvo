/// Pumping the real app with a scripted backend behind it.
///
/// Widget tests here drive `MediStoreApp` itself — the real router, the real
/// shell, the real controllers — with only the socket replaced. That is what
/// makes an assertion about a screen worth something: the row it shows came
/// out of JSON the server would really send.
///
/// **No `pumpAndSettle` anywhere.** A loading card pulses forever and a
/// submitting button spins forever, so "no frames scheduled" never arrives.
/// [settle] pumps a fixed number of frames instead, which also leaves the
/// intermediate states assertable.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medistore/app.dart';
import 'package:medistore/core/health/health_providers.dart';
import 'package:medistore/core/health/health_status.dart';
import 'package:medistore/core/network/network_providers.dart';
import 'package:medistore/core/session/session_controller.dart';
import 'package:medistore/core/storage/session_store.dart';
import 'package:medistore/features/auth/data/auth_repository.dart';
import 'package:medistore/features/auth/domain/auth_user.dart';

import 'fake_api.dart';
import 'fakes.dart';

const testHealth = HealthStatus(
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
Future<void> pumpSignedIn(
  WidgetTester tester,
  FakeApi api, {
  AuthUser user = testUser,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionStoreProvider
            .overrideWithValue(InMemorySessionStore(storedSession(user: user))),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(user: user)),
        healthProvider.overrideWith((ref) async => testHealth),
        apiClientProvider.overrideWith((ref) {
          final client = api.client();
          ref.onDispose(client.close);
          return client;
        }),
      ],
      child: const MediStoreApp(),
    ),
  );
  await settle(tester);
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

/// The outermost scroll view inside [screen].
///
/// Anchoring to a widget that happens to be visible does not survive the first
/// scroll — it goes off screen, the finder stops matching, and the next
/// `scrollUntilVisible` throws "No element". The screen type is always there.
Finder scrollableIn(Type screen) => find
    .descendant(of: find.byType(screen), matching: find.byType(Scrollable))
    .first;
