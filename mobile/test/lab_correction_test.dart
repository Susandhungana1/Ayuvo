/// The lab-value corrections and the range gauge behind them.
///
/// Covers the pure parser (`parseRangeLabel`) and the widget flow: the pencil
/// on a finding opens the correction dialog, the PUT is sent with the new
/// value, and the analysis on screen is replaced by the server's response.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ayuvo/features/reports/presentation/widgets/lab_findings_view.dart';

import 'support/fake_api.dart';
import 'support/harness.dart';

Map<String, Object?> _originalAnalysis() => {
  'overall': 'ABNORMAL',
  'total': 1,
  'abnormal_count': 1,
  'findings': [
    {
      'name': 'Haemoglobin',
      'value': 11.2,
      'unit': 'g/dL',
      'status': 'LOW',
      'reference_range': '13.5 - 17.5',
      'category': 'Haematology',
    },
  ],
};

Map<String, Object?> _correctedAnalysis() => {
  'overall': 'NORMAL',
  'total': 1,
  'abnormal_count': 0,
  'findings': [
    {
      'name': 'Haemoglobin',
      'value': 13.5,
      'unit': 'g/dL',
      'status': 'NORMAL',
      'reference_range': '13.5 - 17.5',
      'category': 'Haematology',
    },
  ],
};

Future<void> _openDetail(WidgetTester tester, FakeApi api) async {
  await pumpSignedIn(
    tester,
    api
      ..json('GET /api/medicines', {'medicines': const []})
      ..json('GET /api/vitals', {'vitals': const []})
      ..json('GET /api/reports', {
        'reports': [reportRow()],
      })
      ..json('GET /api/reports/trends', {'series': const []}),
  );
  await openTab(tester, 'Reports');
  await tester.tap(find.text('Blood test'));
  await settle(tester);
}

void main() {
  group('parseRangeLabel', () {
    test('both bounds', () {
      expect(parseRangeLabel('13.5 - 17.5'), (low: 13.5, high: 17.5));
      expect(parseRangeLabel('12–17.5'), (low: 12.0, high: 17.5));
    });

    test('one-sided', () {
      expect(parseRangeLabel('< 200'), (low: null, high: 200.0));
      expect(parseRangeLabel('> 40'), (low: 40.0, high: null));
    });

    test('nothing to parse', () {
      expect(parseRangeLabel('-'), (low: null, high: null));
      expect(parseRangeLabel(''), (low: null, high: null));
    });
  });

  testWidgets('a finding renders its range as a gauge', (tester) async {
    final api = FakeApi()
      ..json('GET /api/reports/rep-1/lab-analysis', _originalAnalysis());
    await _openDetail(tester, api);

    expect(find.text('Haemoglobin'), findsOneWidget);
    expect(find.text('Range 13.5 - 17.5 g/dL'), findsOneWidget);
    // The band's own bounds are drawn as text under the track.
    expect(find.text('13.5'), findsWidgets);
    expect(find.text('17.5'), findsOneWidget);
    expect(find.text('Low'), findsOneWidget);
  });

  testWidgets('the pencil corrects a misread value through the API', (
    tester,
  ) async {
    var corrected = false;
    final api = FakeApi()
      ..on(
        'GET /api/reports/rep-1/lab-analysis',
        (_) => corrected ? _correctedAnalysis() : _originalAnalysis(),
      )
      ..on('PUT /api/reports/rep-1/lab-values', (request) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['overrides'], {
          'Haemoglobin': {'value': 13.5, 'unit': 'g/dL'},
        });
        corrected = true;
        return _correctedAnalysis();
      });
    await _openDetail(tester, api);

    await tester.tap(find.byTooltip('Correct this value'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, '11.2'), '13.5');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);

    expect(api.calls, contains('PUT /api/reports/rep-1/lab-values'));
    // The response replaced the analysis: the banner flipped to all-clear.
    expect(find.text('All 1 values are within range.'), findsOneWidget);
    expect(find.text('Low'), findsNothing);
  });

  testWidgets('a report still being OCR-read shows the waiting notice '
      'instead of "no values"', (tester) async {
    final api = FakeApi()
      ..json('GET /api/reports', {
        'reports': [reportRow(extractedText: null, ocrStatus: 'PENDING')],
      });
    await pumpSignedIn(
      tester,
      api
        ..json('GET /api/medicines', {'medicines': const []})
        ..json('GET /api/vitals', {'vitals': const []})
        ..json('GET /api/reports/trends', {'series': const []}),
    );
    await openTab(tester, 'Reports');
    await settle(tester);

    // The list card says the read is still running…
    expect(find.text('Reading the file…'), findsOneWidget);
    // …and opening it shows the waiting notice, not a "no values" card.
    await tester.tap(find.text('Blood test'));
    await settle(tester);
    expect(find.textContaining('Still reading this file'), findsOneWidget);
    expect(find.textContaining('No recognisable lab values'), findsNothing);
  });
}
