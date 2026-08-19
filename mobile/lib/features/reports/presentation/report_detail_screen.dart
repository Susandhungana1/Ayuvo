/// One report, and everything the API can say about it.
///
/// The web offers four actions: View · Lab Values · Download PDF · Delete. On
/// a phone that row does not fit, so the file is opened from a single button.
library;

import 'dart:async';

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
import 'reports_controller.dart';
import 'widgets/lab_findings_view.dart';

class ReportDetailScreen extends ConsumerWidget {
  const ReportDetailScreen({super.key, required this.reportId});

  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read from the list rather than refetching: `GET /api/reports` already
    // carried every field this screen shows, including the full OCR text.
    final report = ref
        .watch(reportsProvider)
        .valueOrNull
        ?.where((candidate) => candidate.id == reportId);

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
          _Actions(report: report),
          if (report.isOcrPending) ...[
            const SizedBox(height: AppSpacing.lg),
            _OcrPending(report: report),
          ] else if (!report.hasText) ...[
            const SizedBox(height: AppSpacing.lg),
            const MessageBanner(
              tone: BannerTone.notice,
              message:
                  'No text could be read from this file, so the lab '
                  'values are not available for it. The file itself is '
                  'stored and viewable.',
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.xl),
            Text('Lab values', style: context.texts.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            _LabValues(reportId: report.id),
          ],
          if (report.notes?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: AppSpacing.xl),
            _Section(
              title: 'Your notes',
              child: Text(
                report.notes!.trim(),
                style: context.texts.bodyMedium,
              ),
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
      AsyncData(:final value) => LabFindingsView(
        analysis: value,
        reportId: reportId,
      ),
      AsyncError(:final error) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(labAnalysisProvider(reportId)),
      ),
      _ => const SkeletonCard(lines: 4),
    };
  }
}

/// Shown while the server's background OCR is still reading the file: the
/// report has no text yet, so lab values would be reported as "none found".
/// Polls the list until the text lands (or the server gives up), then hands
/// over to the normal rendering.
class _OcrPending extends ConsumerStatefulWidget {
  const _OcrPending({required this.report});

  final MedicalReport report;

  @override
  ConsumerState<_OcrPending> createState() => _OcrPendingState();
}

class _OcrPendingState extends ConsumerState<_OcrPending> {
  static const _pollEvery = Duration(seconds: 2);
  static const _maxPolls = 10;

  int _polls = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_pollEvery, (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _poll() {
    ref.read(reportsProvider.notifier).refresh();
    _polls += 1;
    if (_polls >= _maxPolls) _timer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Still reading this file — lab values will appear in a '
                'moment.',
                style: context.texts.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
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
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}
