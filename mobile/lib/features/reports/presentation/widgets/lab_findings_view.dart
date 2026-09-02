/// Lab values pulled out of a report's text, grouped by what they measure.
///
/// The server recognises a table of common analytes (`app/core/lab_analysis.py`)
/// and returns each with its value, unit, reference range and a HIGH/LOW/NORMAL
/// verdict. The range bar is drawn from the reference-range label the server
/// sends ("12–17.5", "< 200", "> 40"), so a reading's position on the band is
/// visible; the pencil lets the user correct a value the OCR misread, which is
/// then re-evaluated against the reference range on the server.
///
/// A panel is commonly fifteen analytes, so each row answers "am I all right?"
/// on its face — status dot, name, value — and keeps the range bar, the
/// reference range and the correction behind a tap. Rows that are out of range
/// start open, because those are the ones somebody came to read.
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
          'a diagnosis. Tap a row for its range, or to correct a value the '
          'scan misread.',
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

/// One analyte, answered twice over.
///
/// **Collapsed** is the whole answer for somebody who only wants to know
/// whether they are all right: a status dot, the name, the number, and a band
/// label on the rows that are not normal. Nothing else. A panel is fifteen of
/// these, and fifteen range bars stacked up is a wall that hides the two rows
/// that matter.
///
/// **Expanded** is for the person who wants to see it: the range bar with the
/// reading's position on it, the reference range in full, and the pencil that
/// corrects a value the OCR misread.
///
/// Rows that are out of range open by default — a flagged value that needs a
/// tap to be understood is progressive disclosure applied to the one thing the
/// user came for.
class _FindingRow extends ConsumerStatefulWidget {
  const _FindingRow({required this.reportId, required this.finding});

  final String reportId;
  final LabFinding finding;

  @override
  ConsumerState<_FindingRow> createState() => _FindingRowState();
}

class _FindingRowState extends ConsumerState<_FindingRow> {
  late bool _expanded = !widget.finding.isNormal;

  @override
  Widget build(BuildContext context) {
    final finding = widget.finding;
    final (tone, direction, label) = switch (finding.status.toUpperCase()) {
      'HIGH' => (RangeStatus.alert, RangeDirection.above, 'High'),
      'LOW' => (RangeStatus.caution, RangeDirection.below, 'Low'),
      _ => (RangeStatus.ok, RangeDirection.within, 'Normal'),
    };
    final bounds = parseRangeLabel(finding.referenceRange);
    final banded = bounds.low != null || bounds.high != null;
    final window = _windowFor(finding.value, bounds.low, bounds.high);
    final toneColour = switch (tone) {
      RangeStatus.ok => context.status.ok,
      RangeStatus.caution => context.status.caution,
      RangeStatus.alert => context.status.alert,
    };

    return Theme(
      // The stock ExpansionTile paints a divider above and below itself and
      // tints its own header when open; both fight the card it sits in.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: _expanded,
        onExpansionChanged: (open) => setState(() => _expanded = open),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        // Colour is never the only signal: the dot is backed by the band name
        // on any row that is not normal, and by the value itself on every row.
        leading: Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: AppSpacing.xs),
          decoration: BoxDecoration(color: toneColour, shape: BoxShape.circle),
        ),
        title: Text(finding.name, style: context.texts.bodyMedium),
        subtitle: finding.isNormal
            ? null
            : Text(
                label,
                style: context.texts.labelSmall?.copyWith(color: toneColour),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_number(finding.value), style: context.numerals.numericMedium),
            const SizedBox(width: AppSpacing.xs),
            Text(
              finding.unit,
              style: context.texts.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            AnimatedRotation(
              turns: _expanded ? 0.5 : 0,
              duration: AppMotion.of(context, AppMotion.base),
              curve: AppMotion.standard,
              child: const Icon(Icons.expand_more, size: 20),
            ),
          ],
        ),
        children: [
          if (banded) ...[
            RangeBar(
              value: finding.value,
              min: window.min,
              max: window.max,
              normalLow: bounds.low ?? finding.value,
              normalHigh: bounds.high ?? finding.value,
              status: tone,
              direction: direction,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  'Normal range ${finding.referenceRange} ${finding.unit}',
                  style: context.texts.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _promptCorrection(context, ref),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Correct'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _promptCorrection(BuildContext context, WidgetRef ref) async {
    final finding = widget.finding;
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
      await ref.read(reportRepositoryProvider).correctValues(widget.reportId, {
        finding.name: {
          'value': corrected.value,
          'unit': corrected.unit.isEmpty ? null : corrected.unit,
        },
      });
      ref.invalidate(labAnalysisProvider(widget.reportId));
      ref.invalidate(reportTrendsProvider);
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
