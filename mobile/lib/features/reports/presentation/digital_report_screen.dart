/// The formal report, on screen and as a PDF.
///
/// This is the web's *Digital Report* and *Download PDF* as one thing, because
/// on a phone they are: the document you look at is the document you share.
/// `printing` hands the generated PDF to the OS share sheet, so it reaches
/// email, a chat, or a printer without this app needing storage permission.
///
/// Nothing here is fetched — `ai_report_text` already arrived with the list.
library;

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/time/medi_time.dart';
import '../../../core/widgets/states.dart';
import '../../auth/domain/auth_user.dart';
import '../domain/digital_report.dart';
import '../domain/report.dart';

class DigitalReportScreen extends ConsumerWidget {
  const DigitalReportScreen({super.key, required this.report});

  final MedicalReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = DigitalReport.parse(report.aiReportText);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Formal report'),
        actions: [
          IconButton(
            onPressed: sections.isEmpty || user == null
                ? null
                : () => _share(context, sections, user),
            icon: const Icon(Icons.ios_share),
            tooltip: 'Share as PDF',
          ),
        ],
      ),
      body: sections.isEmpty
          ? const EmptyState(
              icon: Icons.article_outlined,
              title: 'Nothing to lay out',
              message: 'This report has no generated text, so there is no '
                  'formal version of it.',
            )
          : ListView(
              padding: AppSpacing.screen,
              children: [
                _Letterhead(report: report, user: user),
                const SizedBox(height: AppSpacing.xl),
                for (final section in sections) ...[
                  _SectionView(section: section),
                  const SizedBox(height: AppSpacing.lg),
                ],
                const Divider(),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Generated from the uploaded report by AI. It is a '
                  'transcription aid — it is not a clinician\'s report and '
                  'carries no authority.',
                  style: context.texts.bodySmall
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
    );
  }

  Future<void> _share(
    BuildContext context,
    List<ReportSection> sections,
    AuthUser user,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await _buildPdf(sections, user);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'medistore-${report.typeLabel.toLowerCase().replaceAll(' ', '-')}.pdf',
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorText.of(error))));
    }
  }

  Future<Uint8List> _buildPdf(
    List<ReportSection> sections,
    AuthUser user,
  ) async {
    final document = pw.Document();
    final dated = report.dated;

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 48, 40, 48),
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox()
            : pw.Container(
                alignment: pw.Alignment.centerRight,
                margin: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Text(
                  'MediStore · ${report.typeLabel}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount} · '
            'Generated ${MediTime.date(DateTime.now())} · Not a clinician\'s report',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  'MEDISTORE',
                  style: pw.TextStyle(
                    fontSize: 10,
                    letterSpacing: 3,
                    color: PdfColors.blueGrey700,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  report.typeLabel,
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  // Short id, matching the web's MS-XXXXXXXX-YYYY.
                  'Report MS-${report.id.substring(0, report.id.length.clamp(0, 8)).toUpperCase()}'
                  '-${DateTime.now().year}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Divider(thickness: 1.5, color: PdfColors.blueGrey700),
          pw.SizedBox(height: 12),
          _pdfFacts([
            ('Name', user.name),
            ('Patient ID', user.id),
            ('Email', user.email),
            ('Report date', dated == null ? 'Not recorded' : MediTime.date(dated)),
            if (report.hospital?.trim().isNotEmpty ?? false)
              ('Hospital', report.hospital!.trim()),
            if (report.doctorName?.trim().isNotEmpty ?? false)
              ('Doctor', report.doctorName!.trim()),
            ('Source file', report.fileName),
          ]),
          pw.SizedBox(height: 20),
          for (final section in sections) ...[
            pw.Header(
              level: 1,
              text: section.title,
              textStyle: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
            if (section.table != null)
              _pdfTable(section.table!)
            else
              pw.Paragraph(
                text: section.content,
                style: const pw.TextStyle(fontSize: 10, lineSpacing: 3),
              ),
            pw.SizedBox(height: 8),
          ],
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
            ),
            child: pw.Text(
              'This document was generated by AI from an uploaded report. It '
              'is a transcription aid, not a clinician\'s report, and carries '
              'no authority.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ),
        ],
      ),
    );

    return document.save();
  }

  static pw.Widget _pdfFacts(List<(String, String)> rows) {
    return pw.Column(
      children: [
        for (final (label, value) in rows)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 90,
                  child: pw.Text(
                    label,
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static pw.Widget _pdfTable(ReportTable table) {
    return pw.TableHelper.fromTextArray(
      headers: table.headers,
      data: [
        for (final row in table.rows) [for (final cell in row) cell.value],
      ],
      headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
      cellAlignment: pw.Alignment.centerLeft,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
    );
  }
}

class _Letterhead extends StatelessWidget {
  const _Letterhead({required this.report, required this.user});

  final MedicalReport report;
  final AuthUser? user;

  @override
  Widget build(BuildContext context) {
    final dated = report.dated;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Column(
            children: [
              Text(
                'MEDISTORE',
                style: context.texts.labelSmall
                    ?.copyWith(color: context.colors.primary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(report.typeLabel, style: context.texts.headlineMedium),
              if (dated != null)
                Text(
                  MediTime.date(dated),
                  style: context.texts.bodySmall
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Divider(thickness: 1.5),
        const SizedBox(height: AppSpacing.md),
        if (user != null)
          Text(
            '${user!.name} · ${user!.id}',
            style: context.texts.bodyMedium,
          ),
      ],
    );
  }
}

class _SectionView extends StatelessWidget {
  const _SectionView({required this.section});

  final ReportSection section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title.toUpperCase(),
          style: context.texts.labelSmall
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (section.table != null)
          _TableView(table: section.table!)
        else
          Text(section.content, style: context.texts.bodyMedium),
      ],
    );
  }
}

class _TableView extends StatelessWidget {
  const _TableView({required this.table});

  final ReportTable table;

  @override
  Widget build(BuildContext context) {
    // Wide tables scroll inside their own box rather than making the page
    // scroll sideways.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: AppSpacing.xl,
        headingRowHeight: 36,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 56,
        columns: [
          for (final header in table.headers)
            DataColumn(
              label: Text(header, style: context.texts.labelSmall),
            ),
        ],
        rows: [
          for (final row in table.rows)
            DataRow(
              cells: [
                for (var i = 0; i < table.headers.length; i++)
                  DataCell(
                    i < row.length
                        ? Text(
                            row[i].value,
                            style: context.texts.bodySmall?.copyWith(
                              // Out-of-range cells are called out by weight as
                              // well as colour.
                              color: row[i].isAbnormal
                                  ? context.status.alert
                                  : null,
                              fontWeight:
                                  row[i].isAbnormal ? FontWeight.w600 : null,
                            ),
                          )
                        : const Text(''),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
