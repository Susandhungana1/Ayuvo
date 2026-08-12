/// The vitals screen: what the latest reading is judged to be, what can be
/// charted, and what recording one actually sends.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medistore/features/vitals/presentation/vitals_screen.dart';

import 'support/fake_api.dart';
import 'support/harness.dart';

FakeApi backend({List<Map<String, Object?>> vitals = const []}) => FakeApi()
  ..json('GET /api/medicines', {'medicines': const []})
  ..json('GET /api/vitals', {'vitals': vitals});

Future<void> openVitals(WidgetTester tester, FakeApi api) async {
  await pumpSignedIn(tester, api);
  await openTab(tester, 'Vitals');
}

/// The vitals list is long — tiles, then a chart, then every reading — so
/// most of what these tests assert on starts below the fold.
Finder get vitalsList => scrollableIn(VitalsScreen);

void main() {
  testWidgets('an empty list explains what the screen is for', (tester) async {
    await openVitals(tester, backend());

    expect(find.text('No readings yet'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Record your first reading'),
        findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('the latest reading is judged, and the rest are listed',
      (tester) async {
    await openVitals(
      tester,
      backend(vitals: [
        vitalRow(systolic: 118, diastolic: 76, heartRate: 72),
        vitalRow(
          id: 'vit-0',
          systolic: 142,
          diastolic: 91,
          heartRate: 88,
          measuredAt: '2026-07-30 03:15:00',
        ),
      ]),
    );

    expect(find.text('Latest'), findsOneWidget);
    expect(find.text('118/76'), findsOneWidget);

    await scrollTo(tester, find.text('Trend'), scrollable: vitalsList);
    expect(find.text('Trend'), findsOneWidget);

    await scrollTo(tester, find.text('All readings'), scrollable: vitalsList);
    // The older reading is in the list below, with its band named because it
    // is not normal.
    await scrollTo(tester, find.text('142/91'), scrollable: vitalsList);
    expect(find.text('Stage 2 High'), findsOneWidget);
  });

  testWidgets('only metrics that have been recorded get a trend chip',
      (tester) async {
    // A chip nobody can fill leads to an empty chart, which is a dead end.
    await openVitals(
      tester,
      backend(vitals: [vitalRow(systolic: 118, diastolic: 76, weight: 71.4)]),
    );

    await scrollTo(tester, find.text('Trend'), scrollable: vitalsList);

    expect(find.widgetWithText(ChoiceChip, 'BP'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Weight'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'SpO₂'), findsNothing);
    expect(find.widgetWithText(ChoiceChip, 'Temp'), findsNothing);
  });

  testWidgets('two readings at the same instant chart without crashing',
      (tester) async {
    // `measured_at` defaults to utcnow() server-side, so two rows saved in the
    // same second share an x. fl_chart asserts on a zero axis interval, and
    // that assertion took the whole screen down.
    await openVitals(
      tester,
      backend(vitals: [
        vitalRow(systolic: 118, diastolic: 76),
        vitalRow(id: 'vit-0', systolic: 120, diastolic: 78),
      ]),
    );

    await scrollTo(tester, find.text('Trend'), scrollable: vitalsList);
    expect(find.textContaining('2 readings.'), findsOneWidget);
  });

  testWidgets('one reading says a trend needs two rather than drawing one',
      (tester) async {
    await openVitals(tester, backend(vitals: [vitalRow()]));

    await scrollTo(tester, find.text('Trend'), scrollable: vitalsList);
    expect(find.text('One reading so far. A trend needs two.'), findsOneWidget);
  });

  testWidgets('weight is recorded, never judged', (tester) async {
    // There is no healthy weight that holds for everyone, so the tile carries
    // a number and no verdict — and no range bar behind it.
    await openVitals(
      tester,
      backend(vitals: [
        vitalRow(systolic: null, diastolic: null, heartRate: null, weight: 71.4)
      ]),
    );

    expect(find.text('71.4'), findsOneWidget);
    expect(find.text('Recorded'), findsOneWidget);
  });

  testWidgets('a reading with nothing measured says so plainly',
      (tester) async {
    await openVitals(
      tester,
      backend(vitals: [
        vitalRow(systolic: null, diastolic: null, heartRate: null),
      ]),
    );

    expect(find.text('Your latest entry has no measurements in it.'),
        findsOneWidget);
  });

  testWidgets('recording a reading sends naive UTC and only what was typed',
      (tester) async {
    final api = backend(vitals: [vitalRow()])
      ..json('POST /api/vitals', vitalRow(id: 'vit-2', systolic: 130,
          diastolic: 85, heartRate: null));
    await openVitals(tester, api);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Record'));
    await settle(tester);
    expect(find.text('Record a reading'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Systolic'), '130');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Diastolic'), '85');
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Save reading'));
    await settle(tester);

    final body = jsonDecode(api.requestFor('POST /api/vitals')!.body)
        as Map<String, dynamic>;
    expect(body['blood_pressure_systolic'], 130);
    expect(body['blood_pressure_diastolic'], 85);
    // Fields left blank are absent, not zero — a zero heart rate is a claim.
    expect(body.containsKey('heart_rate'), isFalse);
    expect(body.containsKey('weight'), isFalse);
    // The column is naive UTC, so the value carries no zone marker.
    expect(body['measured_at'], isA<String>());
    expect(body['measured_at'] as String, isNot(contains('+')));
    expect(body['measured_at'] as String, isNot(endsWith('Z')));
  });

  testWidgets('half a blood pressure blocks the save, and the other half '
      'unblocks it', (tester) async {
    // The unblocking half is the part that broke: the sheet only rebuilt when
    // "is anything filled in" flipped, so typing the second number left the
    // button dead and the warning on screen with no way forward.
    final api = backend(vitals: [vitalRow()])
      ..json('POST /api/vitals', vitalRow(id: 'vit-2'));
    await openVitals(tester, api);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Record'));
    await settle(tester);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Systolic'), '130');
    await settle(tester);
    expect(find.text('A blood pressure needs both numbers.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save reading'))
          .onPressed,
      isNull,
    );

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Diastolic'), '85');
    await settle(tester);
    expect(find.text('A blood pressure needs both numbers.'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save reading'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('deleting a reading warns that this one is permanent',
      (tester) async {
    // Unlike medicines, `DELETE /api/vitals/{id}` is a hard delete with no
    // restore route — so the dialog is the only chance to change your mind.
    final api = backend(vitals: [vitalRow()])
      ..json('DELETE /api/vitals/vit-1', null);
    await openVitals(tester, api);

    await tapAfterScroll(
      tester,
      find.byTooltip('Delete this reading'),
      scrollable: vitalsList,
    );

    expect(find.text('This one cannot be undone.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester);

    expect(api.requestFor('DELETE /api/vitals/vit-1'), isNotNull);
    expect(find.text('Reading deleted'), findsOneWidget);
    expect(api.unmatched, isEmpty);
  });

  testWidgets('the list asks the server for a page, not for everything',
      (tester) async {
    // The server 422s above limit=200, so the cap lives in the repository.
    final api = backend(vitals: [vitalRow()]);
    await openVitals(tester, api);

    final query = api.requestFor('GET /api/vitals')!.options.uri.queryParameters;
    expect(query['limit'], '200');
    expect(query['offset'], '0');
  });
}
