/// The doctor shell: inbox, availability and registration.
///
/// The appointment surfaces (inbox + availability) are behind a "coming soon"
/// placeholder until they ship; the doctor profile (registration) still works.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medistore/core/widgets/coming_soon.dart';

import 'support/fake_api.dart';
import 'support/fakes.dart';
import 'support/harness.dart';

FakeApi backend() => FakeApi()
  ..json('GET /api/medicines', {'medicines': const []})
  ..json('GET /api/vitals', {'vitals': const []});

Future<void> pumpDoctor(WidgetTester tester, FakeApi api) =>
    pumpSignedIn(tester, api, user: testDoctor);

void main() {
  testWidgets('a doctor lands in the doctor shell, not the patient shell',
      (tester) async {
    await pumpDoctor(tester, backend());

    // The patient tabs are not even in the tree.
    expect(find.text('Medicines'), findsNothing);
    expect(find.text('Vitals'), findsNothing);
    expect(find.text('Availability'), findsOneWidget);
  });

  testWidgets('the inbox shows Coming soon instead of the booking list',
      (tester) async {
    await pumpDoctor(tester, backend());

    expect(find.byType(ComingSoonView), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
  });

  testWidgets('availability shows Coming soon instead of the week',
      (tester) async {
    await pumpDoctor(tester, backend());
    await openTab(tester, 'Availability');

    expect(find.byType(ComingSoonView), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
  });

  testWidgets('the doctor Account tab offers the profile, not patient screens',
      (tester) async {
    final api = backend()
      ..json('GET /api/doctors/doctors/me', doctorRow(verified: false));
    await pumpDoctor(tester, api);
    await openTab(tester, 'Account');

    expect(find.text('Doctor account'), findsOneWidget);
    expect(find.text('Doctor profile'), findsOneWidget);
    expect(find.text('Emergency ID'), findsNothing);
    expect(find.text('Sharing'), findsNothing);

    await tester.tap(find.text('Doctor profile'));
    await settle(tester);

    expect(find.text('NMC-12345'), findsOneWidget);
    expect(find.text('Awaiting verification'), findsOneWidget);
    expect(
      find.textContaining('An administrator checks your registration'),
      findsOneWidget,
    );
  });

  testWidgets('a 404 on the profile offers the form rather than a retry',
      (tester) async {
    final api = backend()
      ..fails('GET /api/doctors/doctors/me', 404, 'Doctor profile not found')
      ..json('POST /api/doctors/doctors', doctorRow(verified: false));
    await pumpDoctor(tester, api);
    await openTab(tester, 'Account');
    await tester.tap(find.text('Doctor profile'));
    await settle(tester);

    expect(find.text('No registration on file'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Add my registration'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'NMC number'),
      'NMC-12345',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Qualification'),
      'MBBS',
    );
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Save registration'));
    await settle(tester);

    final request = api.requestFor('POST /api/doctors/doctors')!;
    expect(request.body, contains('"nmid":"NMC-12345"'));
    expect(request.body, contains('"degree":"MBBS"'));
    // Left blank, so absent rather than an empty string.
    expect(request.body, isNot(contains('specialty')));
    expect(find.text('NMC-12345'), findsOneWidget);
  });
}