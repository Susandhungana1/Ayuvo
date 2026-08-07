/// Lab values pulled out of a report's text, grouped by what they measure.
///
/// The server recognises 22 analytes (`app/core/lab_analysis.py`) and returns
/// each with its value, unit, reference range and a HIGH/LOW/NORMAL verdict.
/// The range bar is not drawn here: the reference range arrives as free text
/// (`"3.5 - 5.1"`, `"< 200"`, `"Male: 13-17"`), and inventing numeric bounds
/// from that would be guessing where the marker goes.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/range_bar.dart';
import '../../domain/report.dart';

class LabFindingsView extends StatelessWidget {
  const LabFindingsView({super.key, required this.analysis});

  final LabAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    if (!analysis.hasData) {
      return Card(
        child: Padding(
          padding: AppSpacing.card,
          child: Text(
            'No recognisable lab values in this report. The analyser looks '
            'for 22 common tests by name — a scan, an X-ray or an unusual '
            'panel will not match any of them.',
            style: context.texts.bodyMedium
                ?.copyWith(color: context.colors.onSurfaceVariant),
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
              style: context.texts.labelSmall
                  ?.copyWith(color: context.colors.onSurfaceVariant),
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
                    _FindingRow(finding: finding),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Flagged against typical adult reference ranges — educational, not '
          'a diagnosis.',
          style: context.texts.bodySmall
              ?.copyWith(color: context.colors.onSurfaceVariant),
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
      color: normal ? context.status.okContainer : context.status.cautionContainer,
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

class _FindingRow extends StatelessWidget {
  const _FindingRow({required this.finding});

  final LabFinding finding;

  @override
  Widget build(BuildContext context) {
    final (tone, direction, label) = switch (finding.status.toUpperCase()) {
      'HIGH' => (RangeStatus.alert, RangeDirection.above, 'High'),
      'LOW' => (RangeStatus.alert, RangeDirection.below, 'Low'),
      _ => (RangeStatus.ok, RangeDirection.within, 'Normal'),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(finding.name, style: context.texts.bodyMedium),
                Text(
                  'Range ${finding.referenceRange}',
                  style: context.texts.bodySmall
                      ?.copyWith(color: context.colors.onSurfaceVariant),
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
                    style: context.texts.bodySmall
                        ?.copyWith(color: context.colors.onSurfaceVariant),
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

  static String _number(double value) => value == value.roundToDouble()
      ? '${value.round()}'
      : value.toStringAsFixed(1);
}
