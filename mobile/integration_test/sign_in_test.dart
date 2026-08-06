/// The phase 3 checkpoint, driven on a real device.
///
/// This runs the **real** app — real secure storage, real dio, real HTTP to the
/// dev backend — and does what a person would do: create an account, land on
/// the home screen, sign out, sign back in. Nothing is faked, so a pass means
/// the emulator genuinely reached the server and the keystore genuinely held
/// the token between screens.
///
///   cd server && python -m uvicorn main:app --reload --port 3001
///   cd mobile && flutter test integration_test/sign_in_test.dart -d emulator-5554
///
/// The Android emulator reaches the host as 10.0.2.2, which is what `Env`
/// defaults to — so no --dart-define is needed for a local run.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medistore/app.dart';
import 'package:medistore/core/config/env.dart';

/// Pumps until [finder] matches or the clock runs out. `pumpAndSettle` is not
/// an option: the loading skeleton pulses forever by design, so "no frames
/// scheduled" never happens while a request is in flight.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for: ${finder.describeMatch(Plurality.one)}');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('create an account, sign out, sign back in', (tester) async {
    final email = 'phase3+${DateTime.now().millisecondsSinceEpoch}@example.com';
    const password = 'phase3-device-check';

    await tester.pumpWidget(const ProviderScope(child: MediStoreApp()));
    await waitFor(tester, find.widgetWithText(FilledButton, 'Sign in'));

    // — Register ————————————————————————————————————————————————
    await tester.tap(find.text('Create an account'));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.enterText(find.byType(TextFormField).at(0), 'Phase Three');
    await tester.enterText(find.byType(TextFormField).at(1), email);
    await tester.enterText(find.byType(TextFormField).at(2), password);
    await tester.enterText(find.byType(TextFormField).at(3), password);
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));

    await waitFor(tester, find.text('Hello, Phase'));

    // The connection card is answered by the real server, not a stub.
    expect(find.textContaining(Env.apiBaseUrl), findsOneWidget);
    await waitFor(tester, find.text('Answering'));
    expect(find.text('Database up'), findsOneWidget);

    // — Sign out ————————————————————————————————————————————————
    await tester.tap(find.text('Account'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(email), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Sign out'),
      ),
    );
    await waitFor(tester, find.widgetWithText(FilledButton, 'Sign in'));

    // — Sign back in ————————————————————————————————————————————
    await tester.enterText(find.byType(TextFormField).first, email);
    await tester.enterText(find.byType(TextFormField).last, password);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));

    await waitFor(tester, find.text('Hello, Phase'));
  });
}
