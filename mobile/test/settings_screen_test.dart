/// The settings screen, driven through the real app: real router, real
/// controllers, only the socket replaced.
///
/// The dose-reminders section is the interesting bit: with reminders on it
/// offers a "send test reminder" button so a person can check their phone
/// actually delivers a notification without waiting for a dose time.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:medistore/core/notifications/reminders.dart';
import 'package:medistore/core/storage/local_store.dart';
import 'package:medistore/features/settings/presentation/settings_screen.dart';
import 'package:medistore/features/shell/presentation/more_screen.dart';

import 'support/fake_api.dart';
import 'support/harness.dart';

FakeApi backend() => FakeApi()
  ..json('GET /api/medicines', {'medicines': const []})
  ..json('GET /api/vitals', {'vitals': const []});

Future<void> openSettings(
  WidgetTester tester,
  FakeApi api, {
  Reminders? reminders,
  Map<String, String>? store,
}) async {
  await pumpSignedIn(
    tester,
    api,
    reminders: reminders,
    store: InMemoryLocalStore(store),
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
}
