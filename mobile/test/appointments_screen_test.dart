/// Appointments are hidden behind a "coming soon" placeholder until they
/// ship — the entry point still exists, but it must never show the feature.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:medistore/core/widgets/coming_soon.dart';

import 'support/fake_api.dart';
import 'support/harness.dart';

FakeApi backend() => FakeApi()
  ..json('GET /api/medicines', {'medicines': const []})
  ..json('GET /api/vitals', {'vitals': const []});

Future<void> openAppointments(WidgetTester tester, FakeApi api) async {
  await pumpSignedIn(tester, api);
  await openTab(tester, 'Account');
  await tester.tap(find.text('Appointments'));
  await settle(tester);
}

void main() {
  testWidgets('the appointments entry point shows Coming soon, never the list',
      (tester) async {
    await openAppointments(tester, backend());

    expect(find.byType(ComingSoonView), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
  });
}