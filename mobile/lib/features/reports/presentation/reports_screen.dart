/// The reports list, and the lab values tracked across them.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/time/medi_time.dart';
import '../../../core/widgets/range_bar.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/states.dart';
import '../domain/report.dart';
import 'report_detail_screen.dart';
import 'report_upload_sheet.dart';
import 'reports_controller.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(reportsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      floatingActionButton: reports.hasValue && reports.value!.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => showReportUploadSheet(context),
              icon: const Icon(Icons.upload_file),
              label: const Text('Add'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.read(reportsProvider.notifier).refresh(),
        child: switch (reports) {
          AsyncData(:final value) when value.isEmpty => _Empty(
            onAdd: () => showReportUploadSheet(context),
          ),
          AsyncData(:final value) => _Loaded(reports: value),
          AsyncError(:final error) => ListView(
            padding: AppSpacing.screen,
            children: [
              ErrorView(
                error: error,
                onRetry: () => ref.read(reportsProvider.notifier).refresh(),
              ),
            ],
          ),
          _ => const _Loading(),
        },
      ),
    );
  }
}

class _Loaded extends ConsumerWidget {
  const _Loaded({required this.reports});

  final List<MedicalReport> reports;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trends = ref.watch(reportTrendsProvider).valueOrNull ?? const [];

    return ListView(
      padding: AppSpacing.screen,
      children: [
        if (trends.isNotEmpty) ...[
          Text('Tracked values', style: context.texts.titleLarge),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Analytes that appear in more than one report. Anything outside '
            'its range is listed first.',
            style: context.texts.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 176,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: trends.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, index) =>
                  _TrendCard(series: trends[index]),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        Text('Your reports', style: context.texts.titleLarge),
        const SizedBox(height: AppSpacing.md),
        for (final report in reports)
          Padding(
            key: ValueKey(report.id),
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _ReportCard(report: report),
          ),
        const SizedBox(height: 88),
      ],
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.series});

  final TrendSeries series;

  @override
  Widget build(BuildContext context) {
    final (tone, statusLabel) = switch (series.latestStatus.toUpperCase()) {
      'HIGH' => (RangeStatus.alert, 'High'),
      'LOW' => (RangeStatus.caution, 'Low'),
      _ => (RangeStatus.ok, 'Normal'),
    };
    final direction = switch (series.direction) {
      'up' => RangeDirection.above,
      'down' => RangeDirection.below,
      _ => RangeDirection.within,
    };

    return SizedBox(
      width: 190,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                series.name,
                style: context.texts.labelSmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _number(series.lastValue),
                    style: context.numerals.numericLarge.copyWith(fontSize: 22),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      series.unit,
                      style: context.texts.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              StatusChip(
                label: statusLabel,
                status: tone,
                // The glyph says which way it moved since the first reading;
                // the word says whether that matters.
                direction: direction,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (series.points.length > 1)
                SizedBox(height: 36, child: _Sparkline(points: series.points)),
              const Spacer(),
              Text(
                _changeLine(series),
                style: context.texts.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _changeLine(TrendSeries series) {
    if (series.direction == 'flat' || series.change == 0) {
      return 'No change · ${series.points.length} results';
    }
    final sign = series.change > 0 ? '+' : '';
    final percent = series.percentChange;
    final amount = '$sign${_number(series.change)}';
    if (percent == null) return '$amount since the first';
    return '$amount ($sign${percent.abs().toStringAsFixed(0)}%) since the first';
  }

  static String _number(double value) => value == value.roundToDouble()
      ? '${value.round()}'
      : value.toStringAsFixed(1);
}

/// The readings of one analyte as a polyline, so a trend is visible before the
/// numbers are read. Painted, not a chart package: three lines of path code.
class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.points});

  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _SparklinePainter(
        values: [for (final p in points) p.value],
        color: context.colors.primary,
        track: context.colors.surfaceContainerHighest,
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.color,
    required this.track,
  });

  final List<double> values;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.isEmpty) return;

    final paint = Paint()
      ..color = track
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );

    var min = values.first;
    var max = values.first;
    for (final v in values) {
      if (v < min) min = v;
      if (v > max) max = v;
    }
    final span = (max - min) == 0 ? 1.0 : (max - min);
    final inset = size.height * 0.2;
    final usable = size.height - inset * 2;

    Offset at(int i) => Offset(
      size.width * i / (values.length - 1),
      inset + (1 - (values[i] - min) / span) * usable,
    );

    final line = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(path, line);

    final dot = Paint()..color = color;
    canvas.drawCircle(at(values.length - 1), 3, dot);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

class _ReportCard extends ConsumerWidget {
  const _ReportCard({required this.report});

  final MedicalReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(labSummaryProvider(report.id)).valueOrNull;
    final dated = report.dated;
    final origin = [
      if (report.hospital?.trim().isNotEmpty ?? false) report.hospital!.trim(),
      if (report.doctorName?.trim().isNotEmpty ?? false)
        report.doctorName!.trim(),
    ].join(' · ');

    return Card(
      child: InkWell(
        borderRadius: AppRadius.md,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ReportDetailScreen(reportId: report.id),
          ),
        ),
        child: Padding(
          padding: AppSpacing.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      report.typeLabel,
                      style: context.texts.titleMedium,
                    ),
                  ),
                  Text(
                    dated == null ? 'Undated' : MediTime.date(dated),
                    style: context.texts.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (origin.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  origin,
                  style: context.texts.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
              if (report.isOcrPending) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        'Reading the file…',
                        style: context.texts.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (summary != null && summary.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: context.status.cautionContainer,
                    borderRadius: AppRadius.full,
                  ),
                  child: Text(
                    '${summary.abnormal} outside range · ${summary.names.join(', ')}',
                    style: context.texts.labelSmall?.copyWith(
                      color: context.status.caution,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              if (report.hasText) ...[
                Text(
                  report.extractedText!.trim(),
                  style: context.texts.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              Text(
                report.fileName,
                style: context.texts.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
        EmptyState(
          icon: Icons.description_outlined,
          title: 'No reports yet',
          message:
              'Photograph a printout or upload a PDF. The text is read '
              'on the server, lab values are pulled out, and anything that '
              'appears twice starts a trend.',
          actionLabel: 'Add your first report',
          onAction: onAdd,
        ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.screen,
      children: const [
        SkeletonCard(lines: 3),
        SizedBox(height: AppSpacing.md),
        SkeletonCard(lines: 3),
      ],
    );
  }
}
