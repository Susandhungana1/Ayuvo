/// Lab values pulled out of a report's text, grouped by what they measure.
///
/// The server recognises a table of common analytes (`app/core/lab_analysis.py`)
/// and returns each with its value, unit, reference range and a HIGH/LOW/NORMAL
/// verdict. The range bar is drawn from the reference-range label the server
/// sends ("12–17.5", "< 200", "> 40"), so a reading's position on the band is
/// visible; the pencil lets the user correct a value the OCR misread, which is
/// then re-evaluated against the reference range on the server.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/range_bar.dart';
import '../../../../core/widgets/states.dart';
import '../../data/report_repository.dart';
import '../../domain/report.dart';
import '../reports_controller.dart';

/// Parses a reference-range label into its numeric bounds. The server writes
/// clean labels ("12–17.5", "< 200", "> 40", "-"), but the parser also accepts
/// the hyphen form and whitespace, so it never guesses a marker placement.
({double? low, double? high}) parseRangeLabel(String label) {
  final both = RegExp(r'([\d.]+)\s*[–-]\s*([\d.]+)').firstMatch(label);
  if (both != null) {
    return (
      low: double.tryParse(both.group(1)!),
      high: double.tryParse(both.group(2)!),
    );
  }
  final oneSided = RegExp(r'([<>])\s*([\d.]+)').firstMatch(label);
  if (oneSided != null) {
    final bound = double.tryParse(oneSided.group(2)!);
    return oneSided.group(1) == '<'
        ? (low: null, high: bound)
        : (low: bound, high: null);
  }
  return (low: null, high: null);
}

/// A window that always contains both the value and the normal band, so an
/// out-of-range reading still lands somewhere visible on the track.
({double min, double max}) _windowFor(double value, double? low, double? high) {
  double pad(double v) => (v.abs() * 0.15).clamp(1.0, double.infinity);
  if (low != null && high != null) {
    var min = low - pad(high - low);
    var max = high + pad(high - low);
    if (value < min) min = value - pad(value);
    if (value > max) max = value + pad(value);
    return (min: min, max: max);
  }
  if (high != null) {
    return (min: 0, max: (high > value ? high : value) * 1.25);
  }
  if (low != null) {
    final floor = low < value ? low : value;
    final ceil = low > value ? low : value;
    return (min: floor * 0.75, max: ceil * 1.15);
  }
  final centre = value == 0 ? 1.0 : value;
  return (min: centre * 0.8, max: centre * 1.2);
}

class LabFindingsView extends ConsumerWidget {
  const LabFindingsView({
    super.key,
    required this.analysis,
    required this.reportId,
  });

  final LabAnalysis analysis;
  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!analysis.hasData) {
      return Card(
        child: Padding(
          padding: AppSpacing.card,
          child: Text(
            'No recognisable lab values in this report. The analyser looks '
            'for common tests by name — a scan, an X-ray or an unusual '
            'panel will not match any of them.',
            style: context.texts.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final grouped = analysis.byCategory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Summary(analysis: analysis),
        const SizedBox(height: AppSpacing.md),
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              entry.key.toUpperCase(),
              style: context.texts.labelSmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                children: [
                  for (final finding in entry.value)
                    _FindingRow(reportId: reportId, finding: finding),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Flagged against typical adult reference ranges — educational, not '
          'a diagnosis. Tap the pencil to correct a misread value.',
          style: context.texts.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.analysis});

  final LabAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final abnormal = analysis.abnormalCount;
    final normal = abnormal == 0;

    return Card(
      color: normal
          ? context.status.okContainer
          : context.status.cautionContainer,
      child: Padding(
        padding: AppSpacing.card,
        child: Row(
          children: [
            Icon(
              normal ? Icons.check_circle_outline : Icons.info_outline,
              size: 20,
              color: normal ? context.status.ok : context.status.caution,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                normal
                    ? 'All ${analysis.total} values are within range.'
                    : '$abnormal of ${analysis.total} values are outside '
                          'their range.',
                style: context.texts.bodyMedium?.copyWith(
                  color: normal ? context.status.ok : context.status.caution,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FindingRow extends ConsumerWidget {
  const _FindingRow({required this.reportId, required this.finding});

  final String reportId;
  final LabFinding finding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (tone, direction, label) = switch (finding.status.toUpperCase()) {
      'HIGH' => (RangeStatus.alert, RangeDirection.above, 'High'),
      'LOW' => (RangeStatus.alert, RangeDirection.below, 'Low'),
      _ => (RangeStatus.ok, RangeDirection.within, 'Normal'),
    };
    final bounds = parseRangeLabel(finding.referenceRange);
    final banded = bounds.low != null || bounds.high != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        finding.name,
                        style: context.texts.bodyMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _promptCorrection(context, ref),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Correct this value',
                    ),
                  ],
                ),
                if (banded) ...[
                  const SizedBox(height: AppSpacing.xs),
                  RangeBar(
                    value: finding.value,
                    min: _windowFor(finding.value, bounds.low, bounds.high).min,
                    max: _windowFor(finding.value, bounds.low, bounds.high).max,
                    normalLow: bounds.low ?? finding.value,
                    normalHigh: bounds.high ?? finding.value,
                    status: tone,
                    direction: direction,
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Range ${finding.referenceRange} ${finding.unit}',
                  style: context.texts.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _number(finding.value),
                    style: context.numerals.numericMedium,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    finding.unit,
                    style: context.texts.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              // Normal values get no chip: a column of green "Normal" chips
              // hides the two rows that are not.
              if (!finding.isNormal)
                StatusChip(label: label, status: tone, direction: direction),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _promptCorrection(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final valueController = TextEditingController(text: _number(finding.value));
    final unitController = TextEditingController(text: finding.unit);
    final corrected = await showDialog<({double value, String unit})>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Correct ${finding.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: valueController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Value'),
            ),
            TextField(
              controller: unitController,
              decoration: const InputDecoration(
                labelText: 'Unit',
                helperText: 'Usually leave as-is.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(valueController.text.trim());
              if (value == null) return;
              Navigator.of(
                context,
              ).pop((value: value, unit: unitController.text.trim()));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (corrected == null) return;

    try {
      await ref.read(reportRepositoryProvider).correctValues(reportId, {
        finding.name: {'value': corrected.value, 'unit': corrected.unit},
      });
      ref.invalidate(labAnalysisProvider(reportId));
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${finding.name} updated to ${_number(corrected.value)}',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorText.of(error))));
    }
  }

  static String _number(double value) => value == value.roundToDouble()
      ? '${value.round()}'
      : value.toStringAsFixed(1);
}
