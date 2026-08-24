/// The Home dashboard, driven through the real app with a scripted backend.
///
/// The clock is the real one here — `_clockProvider` reads `DateTime.now()`
/// and a widget test cannot move it — so every assertion below is written to
/// hold at any hour. Anything that genuinely depends on the time of day is
/// covered by `dose_times_test.dart` against `DoseSchedule` directly.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_api.dart';
import 'support/harness.dart';

FakeApi backend({
  List<Map<String, Object?>> medicines = const [],
  List<Map<String, Object?>> vitals = const [],
}) =>
    FakeApi()
      ..json('GET /api/medicines', {'medicines': medicines})
      ..json('GET /api/vitals', {'vitals': vitals});

void main() {
  testWidgets('an empty account is offered the two things it has none of',
      (tester) async {
    final api = backend();
    await pumpSignedIn(tester, api);

    expect(find.text('Hello, Ram'), findsOneWidget);
    expect(find.text('Nothing scheduled'), findsOneWidget);
    expect(
      find.text('Add a medicine with its dose times and the next one shows '
          'up here.'),
      findsOneWidget,
    );
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Record a reading'), findsOneWidget);
    // Nothing else was fetched. The dashboard costs two requests, which is the
    // whole reason it reuses the tabs' providers instead of having its own.
    expect(api.calls, ['GET /api/medicines', 'GET /api/vitals']);
    expect(api.unmatched, isEmpty);
  });

  testWidgets('a medicine with dose times produces a countdown and a schedule',
      (tester) async {
    final api = backend(medicines: [medicineRow()]);
    await pumpSignedIn(tester, api);

    expect(find.text('Next dose'), findsOneWidget);
    // Once in the countdown card and once per dose row.
    expect(find.text('Amlodipine'), findsNWidgets(3));
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Nothing scheduled'), findsNothing);
  });

  testWidgets('a medicine with no dose times says so instead of counting down',
      (tester) async {
    // A real and common row: the web app's form lets you save a medicine
    // without ever opening the time picker.
    final api = backend(medicines: [medicineRow(takingTimes: null)]);
    await pumpSignedIn(tester, api);

    expect(find.text('Nothing scheduled'), findsOneWidget);
    expect(
      find.text('None of your medicines has a dose time set, so there is no '
          'schedule to count down to.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Set dose times'),
        findsOneWidget);
    // Today's list is empty, so it is absent rather than an empty card.
    expect(find.text('Today'), findsNothing);
  });

  testWidgets('marking a dose taken posts self-only and strikes the row',
      (tester) async {
    final api = backend(medicines: [medicineRow(takingTimes: '["08:00"]')])
      ..json('POST /api/medicines/med-1/intake', {
        'id': 'log-1',
        'medicine_id': 'med-1',
        'scheduled_time': '08:00',
        'status': 'taken',
        'recorded_at': '2026-08-06 08:02:00',
      })
      ..json('GET /api/medicines/intake/log', {'intakes': const []});
    await pumpSignedIn(tester, api);

    await tester.tap(find.widgetWithText(TextButton, 'Taken'));
    await settle(tester);

    final request = api.requestFor('POST /api/medicines/med-1/intake');
    expect(request, isNotNull);
    // The caretaker rule: a patient_id here would be refused, and rightly.
    expect(request!.options.uri.query, isEmpty);
    expect(jsonDecode(request.body),
        {'scheduled_time': '08:00', 'status': 'taken'});

    // The button is gone and the row now reads as done.
    expect(find.widgetWithText(TextButton, 'Taken'), findsNothing);
    expect(find.text('Taken'), findsOneWidget);
    expect(api.unmatched, isEmpty);
  });

  testWidgets('a failed intake says so and leaves the row unmarked',
      (tester) async {
    final api = backend(medicines: [medicineRow(takingTimes: '["08:00"]')])
      ..fails('POST /api/medicines/med-1/intake', 500, 'Database error');
    await pumpSignedIn(tester, api);

    await tester.tap(find.widgetWithText(TextButton, 'Taken'));
    await settle(tester);

    expect(find.byType(SnackBar), findsOneWidget);
    // Still offering the action, because the dose was not in fact recorded.
    expect(find.widgetWithText(TextButton, 'Taken'), findsOneWidget);
  });

  testWidgets('the latest reading becomes one thin strip of chips',
      (tester) async {
    final api = backend(vitals: [
      vitalRow(systolic: 118, diastolic: 76, heartRate: 72),
      vitalRow(id: 'vit-0', systolic: 150, diastolic: 95),
    ]);
    await pumpSignedIn(tester, api);

    expect(find.text('Health'), findsOneWidget);
    expect(find.text('118/76'), findsOneWidget);
    expect(find.text('72'), findsOneWidget);
    // Normal is the quiet default: the value and metric suffice.
    expect(find.text('Normal'), findsNothing);
    // The older, worse reading is not what the dashboard shows.
    expect(find.text('150/95'), findsNothing);
  });

  testWidgets('an out-of-range reading is named, not just coloured',
      (tester) async {
    final api = backend(vitals: [vitalRow(systolic: 182, diastolic: 122)]);
    await pumpSignedIn(tester, api);

    expect(find.text('182/122'), findsOneWidget);
    expect(find.text('BP · Crisis'), findsOneWidget);
  });

  testWidgets('a reading with nothing in it does not draw an empty strip',
      (tester) async {
    // POST /api/vitals accepts a body where every measurement is null, and
    // the web app's form will happily send one.
    final api = backend(vitals: [
      vitalRow(systolic: null, diastolic: null, heartRate: null),
    ]);
    await pumpSignedIn(tester, api);

    expect(find.text('Health'), findsNothing);
    // And the shortcut comes back, because there is still nothing to show.
    expect(find.text('Record a reading'), findsOneWidget);
  });

  testWidgets('a backend that is down offers Retry rather than a blank screen',
      (tester) async {
    final api = FakeApi()
      ..fails('GET /api/medicines', 503, 'Service unavailable')
      ..json('GET /api/vitals', {'vitals': const []});
    await pumpSignedIn(tester, api);

    expect(find.widgetWithText(OutlinedButton, 'Try again'), findsOneWidget);
    // Half a dashboard is not offered as a complete one.
    expect(find.text('Get started'), findsNothing);
  });

  testWidgets('the dashboard survives 2.0x text on a small phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await pumpSignedIn(
      tester,
      backend(
        medicines: [medicineRow()],
        vitals: [vitalRow(weight: 71.4, temperature: 38.4)],
      ),
    );

    // An overflow would already have failed this test.
    expect(find.text('Next dose'), findsOneWidget);
  });
}
