/// The settings screen, driven through the real app: real router, real
/// controllers, only the socket replaced.
///
/// The dose-reminders section is the interesting bit: with reminders on it
/// offers a "send test reminder" button so a person can check their phone
/// actually delivers a notification without waiting for a dose time. The
/// delete-account flow is the other rule worth guarding: two confirmations and
/// the account really is gone.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ayuvo/core/network/api_exception.dart';
import 'package:ayuvo/core/notifications/reminders.dart';
import 'package:ayuvo/core/storage/local_store.dart';
import 'package:ayuvo/features/settings/presentation/settings_screen.dart';
import 'package:ayuvo/features/shell/presentation/more_screen.dart';

import 'support/fake_api.dart';
import 'support/fakes.dart';
import 'support/harness.dart';

FakeApi backend() => FakeApi()
  ..json('GET /api/medicines', {'medicines': const []})
  ..json('GET /api/vitals', {'vitals': const []});

Future<void> openSettings(
  WidgetTester tester,
  FakeApi api, {
  Reminders? reminders,
  Map<String, String>? store,
  FakeAuthRepository? auth,
}) async {
  await pumpSignedIn(
    tester,
    api,
    reminders: reminders,
    store: InMemoryLocalStore(store),
    auth: auth,
  );
  await openTab(tester, 'Account');
  await tapAfterScroll(
    tester,
    find.text('Settings'),
    scrollable: scrollableIn(MoreScreen),
  );
}

void main() {
  testWidgets('with reminders on, Settings can send a test reminder',
      (tester) async {
    final reminders = NoReminders(permission: ReminderPermission.granted);

    await openSettings(
      tester,
      backend(),
      reminders: reminders,
      store: const {'settings.v1': '{"reminders":true}'},
    );

    await tapAfterScroll(
      tester,
      find.text('Send test reminder'),
      scrollable: scrollableIn(SettingsScreen),
    );

    expect(reminders.testRequests, 1);
    // The tap is also the gesture that completes the web subscription.
    expect(reminders.subscribes, 1);
    expect(
      find.text('Test reminder scheduled — check your lock screen in a few '
          'seconds.'),
      findsOneWidget,
    );
  });

  testWidgets('with reminders off, no test reminder is offered',
      (tester) async {
    await openSettings(tester, backend());

    expect(find.text('Send test reminder'), findsNothing);
  });

  testWidgets('deleting the account needs a real confirmation and signs out',
      (tester) async {
    final auth = FakeAuthRepository();
    await openSettings(
      tester,
      backend(),
      // The settings screen reads the repository through the real provider, so
      // the scripted one has to come in through the harness.
      auth: auth,
    );

    // "Delete account" appears twice on the screen — once as the section title
    // and once as the button inside it — so target the button itself.
    final deleteButton = find.widgetWithText(TextButton, 'Delete account');
    await tapAfterScroll(
      tester,
      deleteButton,
      scrollable: scrollableIn(SettingsScreen),
    );

    // First dialog: the blunt warning.
    expect(find.text('Delete account?'), findsOneWidget);
    await tester.tap(find.text('Keep my account'));
    await settle(tester);
    expect(auth.deleteAccountCalls, 0);
    expect(find.byType(SettingsScreen), findsOneWidget);

    // Second time: actually go through with it.
    await tapAfterScroll(
      tester,
      deleteButton,
      scrollable: scrollableIn(SettingsScreen),
    );
    await tester.tap(find.text('Delete my account'));
    await settle(tester);

    expect(auth.deleteAccountCalls, 1);
    // The session is over: the sign-in screen is showing again.
    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('a failed deletion keeps the session and says why',
      (tester) async {
    final auth = FakeAuthRepository()
      ..deleteAccountError = const ApiException(
        ApiErrorKind.network,
        'The network is unreachable',
      );
    await openSettings(tester, backend(), auth: auth);

    await tapAfterScroll(
      tester,
      find.widgetWithText(TextButton, 'Delete account'),
      scrollable: scrollableIn(SettingsScreen),
    );
    await tester.tap(find.text('Delete my account'));
    await settle(tester);

    expect(auth.deleteAccountCalls, 1);
    expect(find.text('The network is unreachable'), findsOneWidget);
    expect(find.byType(SettingsScreen), findsOneWidget);
  });
}
