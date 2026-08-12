/// Appointments, driven through the real app.
///
/// The booking flow is the part worth this much machinery: it is three
/// requests deep — directory, then diary, then the booking — and the one field
/// it sends must go out as naive local text or the server 500s.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medistore/core/widgets/form_sheet.dart';
import 'package:medistore/features/appointments/presentation/appointments_screen.dart';

import 'support/fake_api.dart';
import 'support/harness.dart';

FakeApi backend({List<Map<String, Object?>> appointments = const []}) =>
    FakeApi()
      ..json('GET /api/medicines', {'medicines': const []})
      ..json('GET /api/vitals', {'vitals': const []})
      ..json('GET /api/appointments', {'appointments': appointments});

Future<void> openAppointments(WidgetTester tester, FakeApi api) async {
  await pumpSignedIn(tester, api);
  await openTab(tester, 'Account');
  await tester.tap(find.text('Appointments'));
  await settle(tester);
}

/// Far enough ahead that these tests keep passing after 2030 arrives is not
/// possible, but a fixed date keeps them deterministic until then — and the
/// clock-dependent behaviour is covered in `appointment_test.dart` where the
/// clock can be injected.
const _future = '2030-08-12T09:00:00';
const _past = '2020-03-04T14:30:00';

void main() {
  testWidgets('an empty list explains both ways to use the screen',
      (tester) async {
    await openAppointments(tester, backend());

    expect(find.text('No appointments'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Book an appointment'),
      findsOneWidget,
    );
  });

  testWidgets('an appointment shows when, how long, and with whom',
      (tester) async {
    await openAppointments(
      tester,
      backend(appointments: [appointmentRow(appointmentDate: _future)]),
    );

    expect(find.text('Cardiology follow-up'), findsOneWidget);
    expect(findText('Aug 12, 2030, 9:00 AM · 30 min'), findsOneWidget);
    expect(find.text('Dr Asha Rai'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
  });

  testWidgets('a 9 am booking is not shifted into the afternoon',
      (tester) async {
    // The whole point of parseWallClock. In Asia/Kathmandu, reading this as
    // UTC would print 2:45 pm.
    await openAppointments(
      tester,
      backend(appointments: [appointmentRow(appointmentDate: _future)]),
    );

    expect(findText('Aug 12, 2030, 9:00 AM · 30 min'), findsOneWidget);
    expect(find.textContaining('2:45'), findsNothing);
  });

  testWidgets('past and future are separated, not interleaved',
      (tester) async {
    await openAppointments(
      tester,
      backend(appointments: [
        appointmentRow(id: 'a1', appointmentDate: _future),
        appointmentRow(
          id: 'a2',
          title: 'Blood test',
          appointmentDate: _past,
          status: 'COMPLETED',
        ),
      ]),
    );

    expect(find.text('Coming up'), findsOneWidget);
    expect(find.text('Earlier'), findsOneWidget);
  });

  testWidgets('a self-booked reminder says nobody was told', (tester) async {
    await openAppointments(
      tester,
      backend(appointments: [
        appointmentRow(
          doctorId: null,
          doctorName: 'Dr Someone Else',
          hospital: 'Patan Hospital',
          status: 'PENDING',
          appointmentDate: _future,
        ),
      ]),
    );

    expect(find.text('Awaiting confirmation'), findsOneWidget);
    expect(
      find.text('Saved as your own reminder — the clinic has not been told.'),
      findsOneWidget,
    );
    expect(find.text('Dr Someone Else · Patan Hospital'), findsOneWidget);
  });

  testWidgets('a finished appointment offers Remove, never Cancel',
      (tester) async {
    await openAppointments(
      tester,
      backend(appointments: [
        appointmentRow(appointmentDate: _past, status: 'COMPLETED'),
      ]),
    );

    expect(find.widgetWithText(TextButton, 'Remove'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Cancel'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Move'), findsNothing);
  });

  testWidgets('cancelling sends the status as a query parameter, not a body',
      (tester) async {
    // AppointmentStatus is a bare enum in the FastAPI signature, so a JSON
    // body 422s before the route is reached.
    final api = backend(appointments: [appointmentRow(appointmentDate: _future)])
      ..json('PATCH /api/appointments/apt-1/status',
          appointmentRow(appointmentDate: _future, status: 'CANCELLED'));
    await openAppointments(tester, api);

    await tapAfterScroll(
      tester,
      find.widgetWithText(TextButton, 'Cancel'),
      scrollable: scrollableIn(AppointmentsScreen),
    );
    expect(find.text('Cancel Cardiology follow-up?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Cancel it'));
    await settle(tester);

    final request = api.requestFor('PATCH /api/appointments/apt-1/status')!;
    expect(request.options.uri.queryParameters['status'], 'CANCELLED');
    expect(find.text('Appointment cancelled'), findsOneWidget);
    expect(api.unmatched, isEmpty);
  });

  testWidgets('booking with a listed doctor reads the diary and sends naive '
      'local time', (tester) async {
    final api = backend(appointments: [appointmentRow(appointmentDate: _future)])
      ..json('GET /api/doctors/doctors', {
        'doctors': [doctorRow()],
      })
      ..json('GET /api/appointments/available-slots/doc-uuid-1', {
        'doctor_id': 'doc-uuid-1',
        'doctor_name': 'Dr Asha Rai',
        'available_slots': [
          {
            'start_time': '2030-08-12T09:00:00',
            'end_time': '2030-08-12T09:30:00',
          },
          {
            'start_time': '2030-08-12T09:30:00',
            'end_time': '2030-08-12T10:00:00',
          },
        ],
      })
      ..json('POST /api/appointments',
          appointmentRow(id: 'apt-2', title: 'Review', appointmentDate: _future))
      ..json('GET /api/doctors/availability/doc-uuid-1',
          {'availability': [availabilityRow()]});
    await openAppointments(tester, api);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Book'));
    await settle(tester);
    expect(find.text('Book an appointment'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'What is it for?'),
      'Review',
    );
    await settle(tester);

    // Nothing is asked of the diary until a doctor is chosen.
    expect(find.text('Pick a doctor to see when they are free.'),
        findsOneWidget);
    expect(
      api.calls,
      isNot(contains('GET /api/appointments/available-slots/doc-uuid-1')),
    );

    await tester.tap(find.text('Doctor'));
    await settle(tester);
    await tester.tap(find.text('Dr Asha Rai — MBBS · Cardiology').last);
    await settle(tester);

    final slots = api.requestFor(
      'GET /api/appointments/available-slots/doc-uuid-1',
    )!;
    expect(slots.options.uri.queryParameters['duration_minutes'], '30');
    // A naive date, so Postgres can compare it against a naive column.
    expect(slots.options.uri.queryParameters['date'], isNot(contains('Z')));

    // The slot chips sit under the footer on a test-sized viewport.
    await tapAfterScroll(
      tester,
      findText('9:30 AM'),
      scrollable: scrollableIn(FormSheet),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Book it'));
    await settle(tester);

    final body = jsonDecode(api.requestFor('POST /api/appointments')!.body)
        as Map<String, dynamic>;
    expect(body['title'], 'Review');
    expect(body['doctor_id'], 'doc-uuid-1');
    expect(body['doctor_name'], 'Dr Asha Rai');
    // No zone marker of any kind — an aware datetime raises inside Pydantic's
    // `v <= datetime.now()` and 500s the server.
    expect(body['appointment_date'], '2030-08-12T09:30:00');
    expect(body['duration_minutes'], 30);
  });

  testWidgets('an empty directory offers the other path rather than a dead end',
      (tester) async {
    final api = backend(appointments: [appointmentRow(appointmentDate: _future)])
      ..json('GET /api/doctors/doctors', {'doctors': const []});
    await openAppointments(tester, api);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Book'));
    await settle(tester);

    expect(
      find.textContaining('No doctors are listed on MediStore yet'),
      findsOneWidget,
    );

    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Book somewhere else instead'),
    );
    await settle(tester);

    expect(
      find.textContaining('This saves a reminder for you'),
      findsOneWidget,
    );
  });

  testWidgets('booking somewhere else sends no doctor_id, so it stays pending',
      (tester) async {
    final api = backend(appointments: [appointmentRow(appointmentDate: _future)])
      ..json('GET /api/doctors/doctors', {'doctors': const []})
      ..json(
        'POST /api/appointments',
        appointmentRow(
          id: 'apt-3',
          title: 'Dentist',
          doctorId: null,
          doctorName: null,
          hospital: 'Norvic',
          status: 'PENDING',
          appointmentDate: _future,
        ),
      );
    await openAppointments(tester, api);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Book'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'What is it for?'),
      'Dentist',
    );
    await settle(tester);
    await tester.tap(find.text('Somewhere else'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Hospital or clinic (optional)'),
      'Norvic',
    );
    await settle(tester);

    // No time chosen yet, so there is nothing to save.
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Book it'),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('a failed load offers Retry and says what went wrong',
      (tester) async {
    final api = FakeApi()
      ..json('GET /api/medicines', {'medicines': const []})
      ..json('GET /api/vitals', {'vitals': const []})
      ..fails('GET /api/appointments', 500, 'Database is down');
    await openAppointments(tester, api);

    expect(
      find.text('MediStore had a problem answering. Try again in a moment.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Try again'), findsOneWidget);
  });
}
