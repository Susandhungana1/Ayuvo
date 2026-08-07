/// One report, and everything the API can say about it.
///
/// The web offers six actions in a row of buttons: View · Lab Values · Explain
/// Simply · Digital Report · Download PDF · Delete. On a phone that row does
/// not fit and, more importantly, three of the six depend on OCR having found
/// text. So they are grouped, and an action that cannot work is **absent with
/// a reason** rather than present and then refusing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/files/file_viewer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/time/medi_time.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/states.dart';
import '../data/report_repository.dart';
import '../domain/report.dart';
import 'digital_report_screen.dart';
import 'reports_controller.dart';
import 'widgets/lab_findings_view.dart';

class ReportDetailScreen extends ConsumerWidget {
  const ReportDetailScreen({super.key, required this.reportId});

  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read from the list rather than refetching: `GET /api/reports` already
    // carried every field this screen shows, including the full OCR text.
    final report = ref.watch(reportsProvider).valueOrNull?.where(
          (candidate) => candidate.id == reportId,
        );

    if (report == null || report.isEmpty) {
      // Only reachable if the report was deleted from under this screen.
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.description_outlined,
          title: 'This report is gone',
          message: 'It was deleted, so there is nothing left to show.',
        ),
      );
    }

    return _Detail(report: report.first);
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.report});

  final MedicalReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dated = report.dated;

    return Scaffold(
      appBar: AppBar(
        title: Text(report.typeLabel),
        actions: [
          IconButton(
            onPressed: () => _confirmDelete(context, ref),
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete this report',
          ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.screen,
        children: [
          _Facts(report: report, dated: dated),
          const SizedBox(height: AppSpacing.lg),
          if (report.resultSummary?.trim().isNotEmpty ?? false) ...[
            _Section(
              title: 'Summary',
              caption: 'Generated when the report was uploaded.',
              child: Text(
                report.resultSummary!.trim(),
                style: context.texts.bodyMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          _Actions(report: report),
          if (!report.hasText) ...[
            const SizedBox(height: AppSpacing.lg),
            const MessageBanner(
              tone: BannerTone.notice,
              message: 'No text could be read from this file, so the lab '
                  'values, the plain-language explanation and the formal '
                  'report are not available for it. The file itself is '
                  'stored and viewable.',
            ),
          ],
          if (report.hasText) ...[
            const SizedBox(height: AppSpacing.xl),
            Text('Lab values', style: context.texts.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            _LabValues(reportId: report.id),
            const SizedBox(height: AppSpacing.xl),
            _Explanation(reportId: report.id),
          ],
          if (report.notes?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: AppSpacing.xl),
            _Section(
              title: 'Your notes',
              child: Text(report.notes!.trim(),
                  style: context.texts.bodyMedium),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this report?'),
        // All three consequences, because the server does all three and the
        // user can undo none of them.
        content: const Text(
          'The file, the extracted text and any share links for it are '
          'deleted. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(reportsProvider.notifier).remove(report.id);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Report deleted')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorText.of(error))));
    }
  }
}

class _Facts extends StatelessWidget {
  const _Facts({required this.report, required this.dated});

  final MedicalReport report;
  final DateTime? dated;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Date', dated == null ? 'Not recorded' : MediTime.date(dated!)),
      if (report.hospital?.trim().isNotEmpty ?? false)
        ('Hospital', report.hospital!.trim()),
      if (report.doctorName?.trim().isNotEmpty ?? false)
        ('Doctor', report.doctorName!.trim()),
      ('File', report.fileName),
    ];

    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          children: [
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 84,
                      child: Text(
                        label,
                        style: context.texts.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(value, style: context.texts.bodyMedium),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.report});

  final MedicalReport report;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FileViewerScreen(
                title: report.typeLabel,
                fileName: report.fileName,
                path: ReportRepository.filePath(report.id),
              ),
            ),
          ),
          icon: const Icon(Icons.visibility_outlined, size: 18),
          label: const Text('View the file'),
        ),
        if (report.hasAiReport)
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DigitalReportScreen(report: report),
              ),
            ),
            icon: const Icon(Icons.article_outlined, size: 18),
            label: const Text('Formal report'),
          ),
      ],
    );
  }
}

class _LabValues extends ConsumerWidget {
  const _LabValues({required this.reportId});

  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysis = ref.watch(labAnalysisProvider(reportId));

    return switch (analysis) {
      AsyncData(:final value) => LabFindingsView(analysis: value),
      AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(labAnalysisProvider(reportId)),
        ),
      _ => const SkeletonCard(lines: 4),
    };
  }
}

/// The plain-language explanation.
///
/// Behind a button rather than fetched on open: it is a POST that calls an LLM
/// every time, and opening a report should not spend that on someone who only
/// wanted to look at the scan.
class _Explanation extends ConsumerStatefulWidget {
  const _Explanation({required this.reportId});

  final String reportId;

  @override
  ConsumerState<_Explanation> createState() => _ExplanationState();
}

class _ExplanationState extends ConsumerState<_Explanation> {
  bool _asked = false;

  @override
  Widget build(BuildContext context) {
    if (!_asked) {
      return Card(
        child: Padding(
          padding: AppSpacing.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('In plain language', style: context.texts.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Have the report rewritten without the jargon. It is a '
                'reading aid, not medical advice, and takes a few seconds.',
                style: context.texts.bodyMedium
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () => setState(() => _asked = true),
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: const Text('Explain simply'),
              ),
            ],
          ),
        ),
      );
    }

    final explanation = ref.watch(explanationProvider(widget.reportId));
    return _Section(
      title: 'In plain language',
      caption: 'Generated by AI. Check anything that matters with your doctor.',
      child: switch (explanation) {
        AsyncData(:final value) =>
          Text(value.trim(), style: context.texts.bodyMedium),
        AsyncError(:final error) => ErrorView(
            error: error,
            onRetry: () =>
                ref.invalidate(explanationProvider(widget.reportId)),
          ),
        _ => const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton.line(),
              SizedBox(height: AppSpacing.sm),
              Skeleton.line(),
              SizedBox(height: AppSpacing.sm),
              Skeleton(width: 180, height: 14),
            ],
          ),
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.caption});

  final String title;
  final String? caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: context.texts.titleLarge),
            if (caption != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                caption!,
                style: context.texts.bodySmall
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}
