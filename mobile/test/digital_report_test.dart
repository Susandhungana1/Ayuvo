/// The digitised report parser, against the shape the server actually asks
/// the model for (`server/app/api/reports.py:177-227`).
///
/// There is no structure on the wire, so both clients guess it from the text.
/// These tests exist so the phone guesses the same way the browser does —
/// including where the browser's guess is odd.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:medistore/features/reports/domain/digital_report.dart';

/// The generator's rules, at the exact widths it emits.
final rule = '-' * 80;
final banner = '=' * 80;

/// A report in the format the prompt asks for, with the sections a blood test
/// would actually come back with.
final sampleReport = '''
$banner
                        FORMAL MEDICAL REPORT
$banner

REPORT TYPE: Blood Test
REPORT DATE: 2026-08-06

$rule
1.  PATIENT INFORMATION
    - 45-year-old male, routine annual screening.
$rule

$rule
3.  RESULTS & FINDINGS

Test | Result | Reference Range | Status
Hemoglobin | 11.2 g/dL | 13.5 - 17.5 | Below range
Glucose (fasting) | 92 mg/dL | 70 - 100 | Normal
$rule

$rule
7.  CONCLUSION
    Mild anemia is present; all other parameters are unremarkable.
$rule
''';

void main() {
  group('parse', () {
    test('nothing in, nothing out', () {
      // ai_report_text is nullable and is null for every report uploaded
      // before the feature existed, or whenever OPENROUTER_API_KEY is unset.
      expect(DigitalReport.parse(null), isEmpty);
      expect(DigitalReport.parse(''), isEmpty);
      expect(DigitalReport.parse('   \n  \n'), isEmpty);
    });

    test('finds the sections the generator was asked for, in order', () {
      final sections = DigitalReport.parse(sampleReport);
      expect(
        sections.map((section) => section.title),
        [
          'Report overview',
          'Patient information',
          'Results and findings',
          'Conclusion',
        ],
      );
    });

    test('the overview keeps the metadata and drops the banner rule', () {
      // The web filters '---' but not '===', so eighty equals signs land in
      // its overview paragraph. Dropping them is one of three departures.
      final overview = DigitalReport.parse(sampleReport).first;
      expect(overview.content, 'REPORT TYPE: Blood Test\nREPORT DATE: 2026-08-06');
      expect(overview.content, isNot(contains('=')));
      expect(overview.content, isNot(contains('FORMAL MEDICAL REPORT')));
    });

    test('a section that parsed to nothing never becomes an empty card', () {
      // Each section is fenced by a rule top and bottom, so the split leaves
      // rule-only chunks between them. The web renders those as empty blocks.
      final sections = DigitalReport.parse(sampleReport);
      expect(sections.any((section) => section.isEmpty), isFalse);
      expect(sections, hasLength(4));
    });

    test('text with no rules at all is still one readable section', () {
      // Nothing guarantees the model followed the template.
      final sections = DigitalReport.parse('Everything looks fine.');
      expect(sections.single.title, 'Section');
      expect(sections.single.content, 'Everything looks fine.');
    });

    test('the first matching heading wins, in the web\'s order', () {
      // 'RESULTS' is tested before 'INTERPRETATION' in the browser's if/else
      // chain, so a heading naming both is filed under results.
      final sections = DigitalReport.parse('RESULTS AND INTERPRETATION\nStable.');
      expect(sections.single.title, 'Results and findings');
    });

    test('drops a content line the heading happens to contain', () {
      // `!headerLine?.includes(l)` is meant to remove the heading itself and
      // also removes any unindented line that is a substring of it. Faithfully
      // reproduced: a document that differs between clients is worse than one
      // imperfect in both.
      final sections = DigitalReport.parse(
        'PATIENT INFORMATION AND HISTORY\n'
        'HISTORY\n'
        'Hypertension since 2019.',
      );
      expect(sections.single.content, 'Hypertension since 2019.');
    });

    test('strips the leading bullet only when the line is not indented', () {
      // /^-\s*/ runs on the raw line, so an indented bullet keeps its dash.
      // The web does the same and the dash reads fine either way.
      final indented = DigitalReport.parse(sampleReport)[1];
      expect(indented.content, '- 45-year-old male, routine annual screening.');

      final flush = DigitalReport.parse('CONCLUSION\n- All clear.');
      expect(flush.single.content, 'All clear.');
    });
  });

  group('tables', () {
    test('two or more pipe lines become a table, and the prose goes', () {
      final results = DigitalReport.parse(sampleReport)[2];
      expect(results.content, isEmpty);
      expect(results.table!.headers,
          ['Test', 'Result', 'Reference Range', 'Status']);
      expect(results.table!.rows, hasLength(2));
      expect(results.table!.rows.first.first.value, 'Hemoglobin');
    });

    test('one pipe line is a sentence, not a table', () {
      final sections =
          DigitalReport.parse('CONCLUSION\nHemoglobin | 11.2 g/dL');
      expect(sections.single.table, isNull);
      expect(sections.single.content, 'Hemoglobin | 11.2 g/dL');
    });

    test('flags a cell by the words in it, not by comparing numbers', () {
      final rows = DigitalReport.parse(sampleReport)[2].table!.rows;
      final hemoglobin = rows.first;
      final glucose = rows.last;

      expect(hemoglobin.last.value, 'Below range');
      expect(hemoglobin.last.isAbnormal, isTrue);
      // The value itself is not flagged — only the cell that says so.
      expect(hemoglobin[1].isAbnormal, isFalse);

      expect(glucose.every((cell) => !cell.isAbnormal), isTrue);
    });

    test('"Normal" is not flagged, though "abnormal" contains it backwards',
        () {
      final rows = DigitalReport.parse(
        'RESULTS\nTest | Status\nGlucose | Normal\nUrea | Abnormal',
      ).single.table!.rows;
      expect(rows.first.last.isAbnormal, isFalse);
      expect(rows.last.last.isAbnormal, isTrue);
    });

    test('substring matching flags words that only look clinical', () {
      // 'Yellow' contains 'low' and 'Follow-up' contains 'low'. Both come out
      // red in the browser too. Pinned so the quirk is a known cost rather
      // than a surprise the first time a urinalysis is uploaded.
      final rows = DigitalReport.parse(
        'RESULTS\nTest | Result\nColour | Yellow\nAction | Follow-up advised',
      ).single.table!.rows;
      expect(rows.first.last.isAbnormal, isTrue);
      expect(rows.last.last.isAbnormal, isTrue);
    });

    test('empty cells collapse, so a leading pipe does not shift a row', () {
      // Models write both `| A | B |` and `A | B`. The web drops empty cells
      // rather than aligning them, which keeps the two shapes interchangeable.
      final table = DigitalReport.parse(
        'RESULTS\n| Test | Result |\n| Glucose | 92 mg/dL |',
      ).single.table!;
      expect(table.headers, ['Test', 'Result']);
      expect(table.rows.single.map((cell) => cell.value), ['Glucose', '92 mg/dL']);
    });
  });
}
