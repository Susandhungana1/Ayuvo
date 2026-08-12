/// Reports: the list, the trends strip, and the detail screen's rule that an
/// action which cannot work is absent with a reason rather than offered and
/// then refused.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medistore/features/reports/presentation/report_detail_screen.dart';
import 'package:medistore/features/reports/presentation/reports_screen.dart';

import 'support/fake_api.dart';
import 'support/harness.dart';

FakeApi backend({
  List<Map<String, Object?>> reports = const [],
  List<Map<String, Object?>> trends = const [],
}) =>
    FakeApi()
      ..json('GET /api/medicines', {'medicines': const []})
      ..json('GET /api/vitals', {'vitals': const []})
      ..json('GET /api/reports', {'reports': reports})
      ..json('GET /api/reports/trends', {'series': trends});

Map<String, Object?> trendSeries({
  String name = 'Haemoglobin',
  String unit = 'g/dL',
  double first = 13.1,
  double last = 11.2,
  String direction = 'down',
  String latestStatus = 'LOW',
}) =>
    {
      'name': name,
      'unit': unit,
      'reference_range': '13.5 - 17.5',
      'points': [
        {'date': '2026-01-10', 'value': first, 'status': 'NORMAL'},
        {'date': '2026-06-14', 'value': last, 'status': latestStatus},
      ],
      'first_value': first,
      'last_value': last,
      'change': last - first,
      'percent_change': ((last - first) / first) * 100,
      'direction': direction,
      'latest_status': latestStatus,
    };

Map<String, Object?> labAnalysis({int abnormal = 1}) => {
      'overall': abnormal == 0 ? 'All values within range' : 'Some values are '
          'outside their reference range',
      'total': 2,
      'abnormal_count': abnormal,
      'findings': [
        {
          'name': 'Haemoglobin',
          'value': 11.2,
          'unit': 'g/dL',
          'status': 'LOW',
          'reference_range': '13.5 - 17.5',
          'category': 'Haematology',
        },
        {
          'name': 'Platelets',
          'value': 250,
          'unit': 'x10⁹/L',
          'status': 'NORMAL',
          'reference_range': '150 - 400',
          'category': 'Haematology',
        },
      ],
    };

Future<void> openReports(WidgetTester tester, FakeApi api) async {
  await pumpSignedIn(tester, api);
  await openTab(tester, 'Reports');
}

void main() {
  testWidgets('an empty list explains what the screen is for', (tester) async {
    await openReports(tester, backend());

    expect(find.text('No reports yet'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add your first report'),
        findsOneWidget);
  });

  testWidgets('a report is listed with its summary and its file',
      (tester) async {
    await openReports(tester, backend(reports: [reportRow()]));

    expect(find.text('Your reports'), findsOneWidget);
    expect(find.text('Blood test'), findsOneWidget);
    expect(find.text('Bir Hospital · Dr Asha Rai'), findsOneWidget);
    expect(
      find.text('Haemoglobin slightly below range; everything else normal.'),
      findsOneWidget,
    );
    expect(find.text('cbc-june.pdf'), findsOneWidget);
  });

  testWidgets('a report OCR read nothing from says which, not nothing',
      (tester) async {
    await openReports(
      tester,
      backend(reports: [reportRow(summary: null, extractedText: null)]),
    );

    expect(
      find.text('No summary — nothing readable was extracted from this file.'),
      findsOneWidget,
    );
  });

  testWidgets('an undated report says Undated rather than guessing a date',
      (tester) async {
    await openReports(tester, backend(reports: [reportRow(reportDate: null)]));

    expect(find.text('Undated'), findsOneWidget);
  });

  testWidgets('a tracked value carries its number, its band and its change',
      (tester) async {
    await openReports(
      tester,
      backend(reports: [reportRow()], trends: [trendSeries()]),
    );

    expect(find.text('Tracked values'), findsOneWidget);
    expect(find.text('Haemoglobin'), findsOneWidget);
    expect(find.text('11.2'), findsOneWidget);
    expect(find.text('Low'), findsOneWidget);
    expect(find.text('-1.9 (15%) since the first'), findsOneWidget);
  });

  testWidgets('no trends means no strip, rather than an empty one',
      (tester) async {
    // A single report cannot have a trend: the server only returns analytes
    // that appear in two or more.
    await openReports(tester, backend(reports: [reportRow()]));

    expect(find.text('Tracked values'), findsNothing);
    expect(find.text('Your reports'), findsOneWidget);
  });

  group('detail', () {
    testWidgets('offers the lab values and the explanation when there is text',
        (tester) async {
      final api = backend(reports: [reportRow()])
        ..json('GET /api/reports/rep-1/lab-analysis', labAnalysis());
      await openReports(tester, api);

      await tester.tap(find.text('Blood test'));
      await settle(tester);

      expect(find.byType(ReportDetailScreen), findsOneWidget);
      expect(find.text('Summary'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'View the file'), findsOneWidget);

      await scrollTo(tester, find.text('Lab values'),
          scrollable: scrollableIn(ReportDetailScreen));
      expect(find.text('Haemoglobin'), findsOneWidget);
      expect(find.text('Platelets'), findsOneWidget);

      // The explanation is a POST that calls an LLM, so it waits to be asked.
      await scrollTo(tester, find.text('In plain language'),
          scrollable: scrollableIn(ReportDetailScreen));
      expect(find.widgetWithText(OutlinedButton, 'Explain simply'),
          findsOneWidget);
      expect(api.calls, isNot(contains('POST /api/reports/rep-1/explain')));
    });

    testWidgets('hides what OCR made impossible and says why', (tester) async {
      // `POST /explain` 400s without extracted text and the lab analyser has
      // nothing to parse, so offering either would be offering a refusal.
      await openReports(
        tester,
        backend(reports: [reportRow(extractedText: null)]),
      );

      await tester.tap(find.text('Blood test'));
      await settle(tester);

      expect(
        find.text('No text could be read from this file, so the lab values, '
            'the plain-language explanation and the formal report are not '
            'available for it. The file itself is stored and viewable.'),
        findsOneWidget,
      );
      expect(find.text('Lab values'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Explain simply'),
          findsNothing);
      // The file is still there, so viewing it is still offered.
      expect(find.widgetWithText(FilledButton, 'View the file'), findsOneWidget);
    });

    testWidgets('offers the formal report only when one was generated',
        (tester) async {
      final withReport = backend(reports: [
        reportRow(aiReportText: 'CONCLUSION\nMild anemia.'),
      ])
        ..json('GET /api/reports/rep-1/lab-analysis', labAnalysis());
      await openReports(tester, withReport);

      await tester.tap(find.text('Blood test'));
      await settle(tester);

      expect(find.widgetWithText(OutlinedButton, 'Formal report'),
          findsOneWidget);
    });

    testWidgets('asking for the explanation posts once and shows the answer',
        (tester) async {
      final api = backend(reports: [reportRow()])
        ..json('GET /api/reports/rep-1/lab-analysis', labAnalysis())
        ..json('POST /api/reports/rep-1/explain',
            {'explanation': 'Your iron is a little low. Eat more greens.'});
      await openReports(tester, api);

      await tester.tap(find.text('Blood test'));
      await settle(tester);

      await tapAfterScroll(
        tester,
        find.widgetWithText(OutlinedButton, 'Explain simply'),
        scrollable: scrollableIn(ReportDetailScreen),
      );

      expect(find.text('Your iron is a little low. Eat more greens.'),
          findsOneWidget);
      expect(
        find.text('Generated by AI. Check anything that matters with your '
            'doctor.'),
        findsOneWidget,
      );
      expect(
        api.calls.where((c) => c == 'POST /api/reports/rep-1/explain'),
        hasLength(1),
      );
    });

    testWidgets('deleting from the detail screen returns to the list',
        (tester) async {
      final api = backend(reports: [reportRow()])
        ..json('GET /api/reports/rep-1/lab-analysis', labAnalysis())
        ..json('DELETE /api/reports/rep-1', null);
      await openReports(tester, api);

      await tester.tap(find.text('Blood test'));
      await settle(tester);

      await tester.tap(find.byTooltip('Delete this report'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);

      expect(api.requestFor('DELETE /api/reports/rep-1'), isNotNull);
      expect(find.byType(ReportsScreen), findsOneWidget);
      expect(find.text('No reports yet'), findsOneWidget);
      expect(api.unmatched, isEmpty);
    });
  });
}
