/// Turning `ai_report_text` into something printable.
///
/// The server stores the LLM's formal report as one blob of text with a
/// dashed-rule between sections and occasional pipe-tables inside them. There
/// is no structure on the wire — `front/components/DigitizedReport.tsx` invents
/// it at render time, and this is a faithful port of that parser so the phone
/// and the browser show the same document.
///
/// Faithful includes the odd parts. The web drops a line if the header line
/// contains it, which quietly removes short lines that happen to be substrings
/// of the heading; that is reproduced rather than fixed, because a document
/// that differs between the two clients is worse than one that is imperfect in
/// both.
///
/// Three deliberate departures, all cosmetic. Section titles are sentence case
/// to match the rest of the app. A section that parsed to nothing is dropped
/// instead of rendering as a bare heading — a phone has no room for an empty
/// card. And the `=`-rule the generator wraps its banner in is dropped: the web
/// only filters `---`, so eighty equals signs land in the overview paragraph,
/// where a phone would either overflow or wrap them into three lines of noise.
library;

class ReportCell {
  const ReportCell(this.value, {required this.isAbnormal});

  final String value;

  /// Flagged by vocabulary, not by parsing a number: the LLM writes "slightly
  /// elevated" as often as it writes a figure.
  final bool isAbnormal;
}

class ReportTable {
  const ReportTable({required this.headers, required this.rows});

  final List<String> headers;
  final List<List<ReportCell>> rows;
}

class ReportSection {
  const ReportSection({
    required this.title,
    required this.content,
    this.table,
  });

  final String title;
  final String content;
  final ReportTable? table;

  bool get isEmpty => content.isEmpty && table == null;
}

abstract final class DigitalReport {
  /// The rule the generator puts between sections: eighty hyphens.
  static final _rule = RegExp('-{80}');

  /// The banner rule around the title block. Hyphen rules are already caught
  /// by the web's `contains('---')`; this catches the equals-sign ones.
  static final _bannerRule = RegExp(r'^[=_]{3,}$');

  /// Words that mark a cell as out of range.
  static const _abnormalWords = [
    'below',
    'above',
    'outside',
    'high',
    'low',
    'abnormal',
    'elevated',
    'decreased',
  ];

  /// Heading text → the section name shown, in the web's order of testing.
  static const _titles = <String, String>{
    'FORMAL MEDICAL REPORT': 'Report overview',
    'PATIENT INFORMATION': 'Patient information',
    'REPORT CLASSIFICATION': 'Classification',
    'RESULTS': 'Results and findings',
    'INTERPRETATION': 'Interpretation',
    'CLINICAL CORRELATION': 'Clinical correlation',
    'RECOMMENDATIONS': 'Recommendations',
    'CONCLUSION': 'Conclusion',
  };

  static List<ReportSection> parse(String? text) {
    final source = text?.trim();
    if (source == null || source.isEmpty) return const [];

    final sections = <ReportSection>[];
    for (final chunk in _split(source)) {
      final lines = [
        for (final line in chunk.split('\n'))
          if (line.trim().isNotEmpty) line,
      ];
      if (lines.isEmpty) continue;

      String? headerLine;
      var title = 'Section';
      for (final line in lines) {
        for (final entry in _titles.entries) {
          if (line.contains(entry.key)) {
            headerLine = line;
            title = entry.value;
            break;
          }
        }
        if (headerLine != null) break;
      }

      final contentLines = [
        for (final line in lines)
          if (!line.contains('---') &&
              !_bannerRule.hasMatch(line.trim()) &&
              !line.contains('FORMAL MEDICAL REPORT') &&
              !(headerLine?.contains(line) ?? false))
            line,
      ];

      final tableLines = [
        for (final line in contentLines)
          if (line.contains('|')) line,
      ];

      if (tableLines.length >= 2) {
        sections.add(
          ReportSection(
            title: title,
            content: '',
            table: _table(tableLines),
          ),
        );
        continue;
      }

      final content = [
        for (final line in contentLines)
          if (line.replaceFirst(RegExp(r'^-\s*'), '').trim().isNotEmpty)
            line.replaceFirst(RegExp(r'^-\s*'), '').trim(),
      ].join('\n');

      final section = ReportSection(title: title, content: content);
      if (!section.isEmpty) sections.add(section);
    }
    return sections;
  }

  /// Splits before each dashed rule, keeping the rule with the section that
  /// follows it — the same lookahead split the web uses.
  static List<String> _split(String source) {
    final chunks = <String>[];
    var start = 0;
    for (final match in _rule.allMatches(source)) {
      if (match.start > start) {
        final chunk = source.substring(start, match.start);
        if (chunk.trim().isNotEmpty) chunks.add(chunk);
      }
      start = match.start;
    }
    final tail = source.substring(start);
    if (tail.trim().isNotEmpty) chunks.add(tail);
    return chunks.isEmpty ? [source] : chunks;
  }

  static ReportTable _table(List<String> lines) {
    List<String> cells(String line) => [
          for (final cell in line.split('|'))
            if (cell.trim().isNotEmpty) cell.trim(),
        ];

    final headers = cells(lines.first);
    final rows = [
      for (final line in lines.skip(1))
        [
          for (final cell in cells(line))
            ReportCell(cell, isAbnormal: _isAbnormal(cell)),
        ],
    ];
    return ReportTable(headers: headers, rows: rows);
  }

  static bool _isAbnormal(String cell) {
    final lower = cell.toLowerCase();
    return _abnormalWords.any(lower.contains);
  }
}
