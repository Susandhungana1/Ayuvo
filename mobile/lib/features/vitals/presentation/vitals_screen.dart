/// Vitals: the latest reading judged against its bands, how each metric has
/// moved, and the readings themselves.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/time/medi_time.dart';
import '../../../core/widgets/range_bar.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/states.dart';
import '../domain/vital_ranges.dart';
import '../domain/vital_sign.dart';
import 'vital_form_sheet.dart';
import 'vitals_controller.dart';
import 'widgets/vital_tile.dart';
import 'widgets/vital_trend_chart.dart';

/// Which metric the trend chart is showing. Survives a rebuild of the screen
/// but not a restart — a chart selection is not worth persisting.
final _selectedMetricProvider =
    StateProvider<VitalMetric>((ref) => VitalMetric.bloodPressure);

class VitalsScreen extends ConsumerWidget {
  const VitalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vitals = ref.watch(vitalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Vitals')),
      floatingActionButton: vitals.hasValue && vitals.value!.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => showVitalSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Record'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.read(vitalsProvider.notifier).refresh(),
        child: switch (vitals) {
          AsyncData(:final value) when value.isEmpty =>
            _Empty(onAdd: () => showVitalSheet(context)),
          AsyncData(:final value) => _Loaded(readings: value),
          AsyncError(:final error) => ListView(
              padding: AppSpacing.screen,
              children: [
                ErrorView(
                  error: error,
                  onRetry: () => ref.read(vitalsProvider.notifier).refresh(),
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
  const _Loaded({required this.readings});

  final List<VitalSign> readings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = readings.first;
    final tiles = VitalRanges.readingsOf(latest);
    final selected = ref.watch(_selectedMetricProvider);

    return ListView(
      padding: AppSpacing.screen,
      children: [
        _LatestHeader(reading: latest),
        const SizedBox(height: AppSpacing.md),
        if (tiles.isEmpty)
          Card(
            child: Padding(
              padding: AppSpacing.card,
              child: Text(
                'Your latest entry has no measurements in it.',
                style: context.texts.bodyMedium,
              ),
            ),
          )
        else
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            // Tall enough for a chip and a range bar under the number at the
            // default text size; the tile itself has no fixed height, so
            // turning text scaling up grows it rather than clipping it.
            childAspectRatio: 0.92,
            children: [for (final tile in tiles) VitalTile(reading: tile)],
          ),
        const SizedBox(height: AppSpacing.xl),
        Text('Trend', style: context.texts.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        _MetricPicker(
          selected: selected,
          available: _metricsPresentIn(readings),
          onSelect: (metric) =>
              ref.read(_selectedMetricProvider.notifier).state = metric,
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: AppSpacing.card,
            child: VitalTrendChart(metric: selected, readings: readings),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('All readings', style: context.texts.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        for (final reading in readings)
          Padding(
            key: ValueKey(reading.id),
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _ReadingRow(reading: reading),
          ),
        const SizedBox(height: 88),
      ],
    );
  }

  /// Only offer a metric that has been recorded at least once — an empty chart
  /// behind a chip nobody can fill is a dead end.
  static List<VitalMetric> _metricsPresentIn(List<VitalSign> readings) {
    final present = [
      for (final metric in VitalMetric.values)
        if (readings.any(metric.presentIn)) metric,
    ];
    return present.isEmpty ? [VitalMetric.bloodPressure] : present;
  }
}

class _LatestHeader extends StatelessWidget {
  const _LatestHeader({required this.reading});

  final VitalSign reading;

  @override
  Widget build(BuildContext context) {
    final measured = reading.measured;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Latest', style: context.texts.titleLarge),
              if (measured != null)
                Text(
                  MediTime.ago(measured),
                  style: context.texts.bodyMedium
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricPicker extends StatelessWidget {
  const _MetricPicker({
    required this.selected,
    required this.available,
    required this.onSelect,
  });

  final VitalMetric selected;
  final List<VitalMetric> available;
  final ValueChanged<VitalMetric> onSelect;

  @override
  Widget build(BuildContext context) {
    // Scrolls horizontally rather than wrapping: six chips on two lines push
    // the chart below the fold on a small phone.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final metric in available)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(metric.shortLabel),
                selected: metric == selected,
                onSelected: (_) => onSelect(metric),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReadingRow extends ConsumerWidget {
  const _ReadingRow({required this.reading});

  final VitalSign reading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final measured = reading.measured;
    final readings = VitalRanges.readingsOf(reading);

    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    measured == null
                        ? 'Undated reading'
                        : MediTime.dateTime(measured),
                    style: context.texts.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => _confirmRemove(context, ref),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete this reading',
                ),
              ],
            ),
            if (readings.isEmpty)
              Text(
                'No measurements were recorded in this entry.',
                style: context.texts.bodySmall
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              )
            else
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final item in readings)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.metric.shortLabel,
                          style: context.texts.labelSmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              item.display,
                              style: context.numerals.numericMedium,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            // The band's name only appears when it isn't
                            // "Normal" — a column of the word Normal is noise,
                            // and the exceptions are what the row is for.
                            if (!item.isNormal)
                              Text(
                                item.status,
                                style: context.texts.bodySmall?.copyWith(
                                  color: switch (item.tone) {
                                    RangeStatus.ok => context.status.ok,
                                    RangeStatus.caution => context.status.caution,
                                    RangeStatus.alert => context.status.alert,
                                  },
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            if (reading.notes?.trim().isNotEmpty ?? false) ...[
              const SizedBox(height: AppSpacing.md),
              Text(reading.notes!.trim(), style: context.texts.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this reading?'),
        // Vitals are hard-deleted server-side — unlike a medicine, there is no
        // restore route, and the dialog must not imply otherwise.
        content: const Text('This one cannot be undone.'),
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

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(vitalsProvider.notifier).remove(reading.id);
      messenger.showSnackBar(const SnackBar(content: Text('Reading deleted')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorText.of(error))));
    }
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
          icon: Icons.monitor_heart_outlined,
          title: 'No readings yet',
          message: 'Record a blood pressure, a temperature, a weight — '
              'whatever you measure. Each one is shown against its normal '
              'range, and two of anything makes a trend.',
          actionLabel: 'Record your first reading',
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
        Skeleton(width: 120, height: 20),
        SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(child: SkeletonCard(lines: 3)),
            SizedBox(width: AppSpacing.md),
            Expanded(child: SkeletonCard(lines: 3)),
          ],
        ),
        SizedBox(height: AppSpacing.md),
        SkeletonCard(lines: 4),
      ],
    );
  }
}
