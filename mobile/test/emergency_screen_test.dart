/// The emergency ID.
///
/// The assertion that matters most is the one about empty strings: the server
/// reads `null` as "leave this field as it was", so a form that sends null for
/// a cleared box makes a value that no longer applies impossible to remove.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medistore/core/widgets/form_sheet.dart';
import 'package:medistore/features/emergency/presentation/emergency_screen.dart';
import 'package:medistore/features/shell/presentation/more_screen.dart';

import 'support/fake_api.dart';
import 'support/fakes.dart';
import 'support/harness.dart';

FakeApi backend({Map<String, Object?>? profile}) => FakeApi()
  ..json('GET /api/medicines', {'medicines': const []})
  ..json('GET /api/vitals', {'vitals': const []})
  ..json('GET /api/emergency/profile', profile ?? emergencyProfileRow());

Future<void> openEmergency(WidgetTester tester, FakeApi api) async {
  await pumpSignedIn(tester, api);
  await openTab(tester, 'Account');
  // Last of the four tiles, so it starts below the fold on a test viewport.
  await tapAfterScroll(
    tester,
    find.text('Emergency ID'),
    scrollable: scrollableIn(MoreScreen),
  );
}

void main() {
  testWidgets('the card shows blood type', (tester) async {
    await openEmergency(tester, backend());

    expect(find.text('O+'), findsOneWidget);
  });

  testWidgets('an empty profile warns the share QR would show a blank card',
      (tester) async {
    await openEmergency(
      tester,
      backend(
        profile: emergencyProfileRow(bloodType: null),
      ),
    );

    expect(
      find.textContaining('your all-reports share QR would show a stranger an '
          'empty card'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, 'Fill in my details'),
      findsOneWidget,
    );
  });

  testWidgets('a doctor account never reaches this screen', (tester) async {
    await pumpSignedIn(
      tester,
      FakeApi()
        ..json('GET /api/appointments/doctor/my-appointments',
            {'appointments': const []})
        ..json('GET /api/doctors/availability', {'availability': const []}),
      user: testDoctor,
    );
    await openTab(tester, 'Account');

    expect(find.text('Emergency ID'), findsNothing);
  });

  testWidgets('clearing blood type sends an empty string, never null',
      (tester) async {
    final api = backend()
      ..json(
        'PUT /api/emergency/profile',
        emergencyProfileRow(bloodType: ''),
      );
    await openEmergency(tester, api);

    await tapAfterScroll(
      tester,
      find.widgetWithText(OutlinedButton, 'Edit details'),
      scrollable: scrollableIn(EmergencyScreen),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save details'));
    await settle(tester);

    final body = jsonDecode(api.requestFor('PUT /api/emergency/profile')!.body)
        as Map<String, dynamic>;
    expect(body['blood_type'], '');
  });

  testWidgets('tapping the selected blood type clears it', (tester) async {
    final api = backend()
      ..json('PUT /api/emergency/profile', emergencyProfileRow(bloodType: ''));
    await openEmergency(tester, api);

    await tapAfterScroll(
      tester,
      find.widgetWithText(OutlinedButton, 'Edit details'),
      scrollable: scrollableIn(EmergencyScreen),
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'O+'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Save details'));
    await settle(tester);

    final body = jsonDecode(api.requestFor('PUT /api/emergency/profile')!.body)
        as Map<String, dynamic>;
    expect(body['blood_type'], '');
  });

  testWidgets('no contacts prompts for the first one', (tester) async {
    await openEmergency(tester, backend());

    expect(
      find.text('Nobody listed. Add the person you would want phoned first.'),
      findsOneWidget,
    );
  });

  testWidgets('a contact shows name and number, and offers a call',
      (tester) async {
    await openEmergency(
      tester,
      backend(
        profile: emergencyProfileRow(contacts: [emergencyContactRow()]),
      ),
    );

    expect(find.text('Sita Bahadur'), findsOneWidget);
    expect(find.text('+977 98 1234 5678'), findsOneWidget);
    expect(find.byTooltip('Call Sita Bahadur'), findsOneWidget);
  });

  testWidgets('adding a contact sends the required fields', (tester) async {
    final api = backend()
      ..json('POST /api/emergency/contacts', emergencyContactRow());
    await openEmergency(tester, api);

    await tapAfterScroll(
      tester,
      find.widgetWithText(TextButton, 'Add'),
      scrollable: scrollableIn(EmergencyScreen),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Sita Bahadur',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone'),
      '+977 98 1234 5678',
    );
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Add contact'));
    await settle(tester);

    final body =
        jsonDecode(api.requestFor('POST /api/emergency/contacts')!.body)
            as Map<String, dynamic>;
    expect(body['name'], 'Sita Bahadur');
    expect(body['phone'], '+977 98 1234 5678');
    expect(find.text('Sita Bahadur'), findsOneWidget);
  });

  testWidgets('a contact without a number cannot be saved', (tester) async {
    await openEmergency(tester, backend());

    await tapAfterScroll(
      tester,
      find.widgetWithText(TextButton, 'Add'),
      scrollable: scrollableIn(EmergencyScreen),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Sita Bahadur',
    );
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Add contact'));
    await settle(tester);

    expect(
      find.text('A contact without a number cannot be reached.'),
      findsOneWidget,
    );
    expect(find.byType(FormSheet), findsOneWidget);
  });

  testWidgets('removing a contact asks first', (tester) async {
    final api = backend(
      profile: emergencyProfileRow(contacts: [emergencyContactRow()]),
    )..json('DELETE /api/emergency/contacts/con-1', null);
    await openEmergency(tester, api);

    await tapAfterScroll(
      tester,
      find.byTooltip('Remove Sita Bahadur'),
      scrollable: scrollableIn(EmergencyScreen),
    );

    expect(find.text('Remove Sita Bahadur?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await settle(tester);

    expect(api.requestFor('DELETE /api/emergency/contacts/con-1'), isNotNull);
    expect(find.text('Sita Bahadur removed'), findsOneWidget);
    expect(api.unmatched, isEmpty);
  });
}
