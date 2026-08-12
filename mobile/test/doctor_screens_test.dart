/// The doctor shell: inbox, availability, registration.
///
/// The inbox test that matters most is the one asserting which route a status
/// change goes to. `PATCH /{id}/status` authorises against the patient who
/// booked, so a doctor calling it 404s on everything — which is exactly what
/// the web app does today.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medistore/core/widgets/form_sheet.dart';
import 'package:medistore/features/doctors/presentation/availability_screen.dart';

import 'support/fake_api.dart';
import 'support/fakes.dart';
import 'support/harness.dart';

FakeApi backend({
  List<Map<String, Object?>> inbox = const [],
  List<Map<String, Object?>> availability = const [],
}) =>
    FakeApi()
      ..json('GET /api/appointments/doctor/my-appointments',
          {'appointments': inbox})
      ..json('GET /api/doctors/availability', {'availability': availability});

Future<void> pumpDoctor(WidgetTester tester, FakeApi api) =>
    pumpSignedIn(tester, api, user: testDoctor);

void main() {
  testWidgets('a doctor lands in the inbox, not in the patient shell',
      (tester) async {
    await pumpDoctor(tester, backend());

    expect(find.text('Nothing booked yet'), findsOneWidget);
    // The patient tabs are not even in the tree.
    expect(find.text('Medicines'), findsNothing);
    expect(find.text('Vitals'), findsNothing);
    expect(find.text('Availability'), findsOneWidget);
  });

  testWidgets('requests waiting on an answer sort above everything else',
      (tester) async {
    await pumpDoctor(
      tester,
      backend(inbox: [
        appointmentRow(id: 'a1', title: 'Old review', status: 'COMPLETED'),
        appointmentRow(id: 'a2', title: 'New request', status: 'PENDING'),
      ]),
    );

    expect(find.text('Waiting on you'), findsOneWidget);
    expect(find.text('Everything else'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('New request')).dy,
      lessThan(tester.getTopLeft(find.text('Old review')).dy),
    );
  });

  testWidgets('accepting goes to the by-doctor route, with a query status',
      (tester) async {
    final api = backend(inbox: [appointmentRow(status: 'PENDING')])
      ..json('PATCH /api/appointments/apt-1/status/by-doctor',
          appointmentRow(status: 'CONFIRMED'));
    await pumpDoctor(tester, api);

    await tester.tap(find.widgetWithText(FilledButton, 'Accept'));
    await settle(tester);

    final request =
        api.requestFor('PATCH /api/appointments/apt-1/status/by-doctor')!;
    expect(request.options.uri.queryParameters['status'], 'CONFIRMED');
    // Never the patient's route — it would 404 for every doctor alive.
    expect(api.calls, isNot(contains('PATCH /api/appointments/apt-1/status')));
    expect(find.text('Accepted'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
  });

  testWidgets('a confirmed booking offers Mark seen, not Accept',
      (tester) async {
    await pumpDoctor(tester, backend(inbox: [appointmentRow()]));

    expect(find.widgetWithText(FilledButton, 'Mark seen'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Accept'), findsNothing);
  });

  testWidgets('a cancelled booking offers nothing — it is finished',
      (tester) async {
    await pumpDoctor(
      tester,
      backend(inbox: [appointmentRow(status: 'CANCELLED')]),
    );

    expect(find.byType(FilledButton), findsNothing);
    expect(find.text('Cancelled'), findsOneWidget);
  });

  testWidgets('a doctor with no profile is told to register, not shown an error',
      (tester) async {
    final api = FakeApi()
      ..fails('GET /api/appointments/doctor/my-appointments', 404,
          'Doctor profile not found')
      ..json('GET /api/doctors/availability', {'availability': const []});
    await pumpDoctor(tester, api);

    expect(find.text('Finish your registration first'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Try again'), findsNothing);
  });

  testWidgets('availability shows all seven days, working or not',
      (tester) async {
    await pumpDoctor(
      tester,
      backend(availability: [availabilityRow()]),
    );
    await openTab(tester, 'Availability');

    expect(find.text('Monday'), findsOneWidget);
    expect(find.text('Tuesday'), findsOneWidget);
    expect(findText('9:00 AM – 12:00 PM'), findsOneWidget);
    expect(find.text('30-minute slots'), findsOneWidget);
    // A day with nothing posted is still a card, because "add hours here" is
    // the whole point of the empty row.
    expect(find.text('Not working'), findsWidgets);

    // The list is lazy, so the far end of the week has to be scrolled to.
    await scrollTo(
      tester,
      find.text('Sunday'),
      scrollable: scrollableIn(AvailabilityScreen),
    );
    expect(find.text('Sunday'), findsOneWidget);
  });

  testWidgets('no hours at all says nobody can book you', (tester) async {
    await pumpDoctor(tester, backend());
    await openTab(tester, 'Availability');

    expect(
      find.textContaining('You have posted no hours, so nobody can book you'),
      findsOneWidget,
    );
  });

  testWidgets('a paused window is shown as paused, not hidden', (tester) async {
    await pumpDoctor(
      tester,
      backend(availability: [availabilityRow(isAvailable: false)]),
    );
    await openTab(tester, 'Availability');

    expect(find.text('Paused — nobody can book this'), findsOneWidget);
    expect(findText('9:00 AM – 12:00 PM'), findsOneWidget);
  });

  testWidgets('adding hours sends the weekday, the clock times and the slot '
      'length', (tester) async {
    final api = backend()
      ..json('POST /api/doctors/availability',
          availabilityRow(dayOfWeek: 'WEDNESDAY', slotDurationMinutes: 15));
    await pumpDoctor(tester, api);
    await openTab(tester, 'Availability');

    // The Wednesday card's own Add button.
    await tapAfterScroll(
      tester,
      find.descendant(
        of: find.ancestor(
          of: find.text('Wednesday'),
          matching: find.byType(Card),
        ),
        matching: find.widgetWithText(TextButton, 'Add hours'),
      ),
      scrollable: scrollableIn(AvailabilityScreen),
    );

    expect(find.text('Wednesday hours'), findsOneWidget);
    // 09:00–17:00 at 30 minutes is sixteen slots, and the sheet says so before
    // anything is saved.
    expect(find.text('That is 16 slots.'), findsOneWidget);

    await tapAfterScroll(
      tester,
      find.widgetWithText(ChoiceChip, '15 min'),
      scrollable: scrollableIn(FormSheet),
    );
    expect(find.text('That is 32 slots.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Add hours'));
    await settle(tester);

    final request = api.requestFor('POST /api/doctors/availability')!;
    expect(request.body, contains('"day_of_week":"WEDNESDAY"'));
    expect(request.body, contains('"start_time":"09:00"'));
    expect(request.body, contains('"end_time":"17:00"'));
    // The field the web editor never exposed.
    expect(request.body, contains('"slot_duration_minutes":15'));
    expect(api.unmatched, isEmpty);
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
