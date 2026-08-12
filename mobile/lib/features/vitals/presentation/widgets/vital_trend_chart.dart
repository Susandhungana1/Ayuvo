/// One metric over time, against the band it is judged by.
///
/// Chart decisions, from the dataviz skill:
///   * a line, because the job is change over time on an irregular schedule —
///     so x is the actual instant, not the reading's position in a list;
///   * **one axis.** Blood pressure is two series on one mmHg scale, which is
///     legitimate; two metrics of different scale would be two charts;
///   * the normal band is drawn behind the line as a shaded region, so "is this
///     reading fine" is answered by position rather than by colour;
///   * series colours come from the validated categorical ramp and are assigned
///     in fixed order — never a status colour, which already means something
///     else in this product;
///   * the last point is labelled directly; every point is not.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/time/medi_time.dart';
import '../../domain/vital_ranges.dart';
import '../../domain/vital_sign.dart';

class VitalTrendChart extends StatelessWidget {
  const VitalTrendChart({
    super.key,
    required this.metric,
    required this.readings,
  });

  final VitalMetric metric;

  /// Newest first, as the API returns them.
  final List<VitalSign> readings;

  @override
  Widget build(BuildContext context) {
    // Oldest → newest, and only the readings that carry this metric.
    final points = <(DateTime, double, double?)>[];
    for (final reading in readings.reversed) {
      final at = reading.measured;
      final value = metric.valueIn(reading);
      if (at == null || value == null) continue;
      points.add((at, value, metric.diastolicOf(reading)));
    }

    if (points.length < 2) {
      return _NotEnough(count: points.length, metric: metric);
    }

    final band = metric.band;
    final colors = context.chart.series;

    final primary = [
      for (final (at, value, _) in points)
        FlSpot(at.millisecondsSinceEpoch.toDouble(), value),
    ];
    final secondary = metric == VitalMetric.bloodPressure
        ? [
            for (final (at, _, diastolic) in points)
              if (diastolic != null)
                FlSpot(at.millisecondsSinceEpoch.toDouble(), diastolic),
          ]
        : const <FlSpot>[];

    final values = [
      for (final spot in primary) spot.y,
      for (final spot in secondary) spot.y,
      // Keep the band on screen even when every reading sits well clear of it,
      // so "how far outside is this" stays answerable.
      if (band != null) ...[band.low, band.high],
    ];
    final lowest = values.reduce((a, b) => a < b ? a : b);
    final highest = values.reduce((a, b) => a > b ? a : b);
    final padding = ((highest - lowest) * 0.15).clamp(1.0, 40.0);

    // Every reading at the same instant is not a hypothetical: `measured_at`
    // defaults to `utcnow()` server-side, so two rows saved in the same second
    // share an x. fl_chart asserts on a zero interval, which would take the
    // whole screen down, so fall back to any positive number — with one
    // distinct x there is one label to place either way.
    final span = (primary.last.x - primary.first.x).abs();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (secondary.isNotEmpty)
          _Legend(
            entries: [
              ('Systolic', colors[0]),
              ('Diastolic', colors[1]),
            ],
          ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minY: lowest - padding,
              maxY: highest + padding,
              clipData: const FlClipData.all(),
              rangeAnnotations: RangeAnnotations(
                horizontalRangeAnnotations: [
                  if (band != null)
                    HorizontalRangeAnnotation(
                      y1: band.low,
                      y2: band.high,
                      color: context.chart.band,
                    ),
                ],
              ),
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: context.colors.outlineVariant,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) => Text(
                      value.toStringAsFixed(metric.decimals),
                      style: context.texts.bodySmall
                          ?.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    // Two labels only — the ends. A date under every point is
                    // unreadable at phone width and adds nothing a tooltip
                    // doesn't answer better.
                    interval: span == 0 ? 1 : span,
                    getTitlesWidget: (value, meta) => Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        MediTime.day(
                          DateTime.fromMillisecondsSinceEpoch(value.toInt()),
                        ),
                        style: context.texts.bodySmall
                            ?.copyWith(color: context.colors.onSurfaceVariant),
                      ),
                    ),
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => context.colors.inverseSurface,
                  getTooltipItems: (spots) => [
                    for (final spot in spots)
                      LineTooltipItem(
                        '${spot.y.toStringAsFixed(metric.decimals)} '
                        '${metric.unit}\n'
                        '${MediTime.date(DateTime.fromMillisecondsSinceEpoch(spot.x.toInt()))}',
                        context.texts.bodySmall?.copyWith(
                              color: context.colors.onInverseSurface,
                            ) ??
                            const TextStyle(),
                      ),
                  ],
                ),
              ),
              lineBarsData: [
                _line(context, primary, colors[0]),
                if (secondary.isNotEmpty)
                  _line(context, secondary, colors[1]),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          band == null
              ? '${points.length} readings. Weight has no normal range.'
              : '${points.length} readings. The shaded band is '
                  '${metric.normalLabel} ${metric.unit}.',
          style: context.texts.bodySmall
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
      ],
    );
  }

  static LineChartBarData _line(
    BuildContext context,
    List<FlSpot> spots,
    Color color,
  ) {
    return LineChartBarData(
      spots: spots,
      color: color,
      barWidth: 2,
      isCurved: false,
      // Dots only when there are few enough to be marks rather than noise.
      dotData: FlDotData(
        show: spots.length <= 12,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 4,
          color: color,
          // A 2px surface ring keeps overlapping marks legible.
          strokeWidth: 2,
          strokeColor: context.colors.surface,
        ),
      ),
      belowBarData: BarAreaData(show: false),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.entries});

  final List<(String, Color)> entries;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.lg,
      children: [
        for (final (label, color) in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.xs),
              // Text wears an ink token, never the series colour.
              Text(label, style: context.texts.bodySmall),
            ],
          ),
      ],
    );
  }
}

class _NotEnough extends StatelessWidget {
  const _NotEnough({required this.count, required this.metric});

  final int count;
  final VitalMetric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      alignment: Alignment.center,
      child: Text(
        count == 0
            ? 'No ${metric.label.toLowerCase()} readings yet.'
            : 'One reading so far. A trend needs two.',
        style: context.texts.bodyMedium
            ?.copyWith(color: context.colors.onSurfaceVariant),
        textAlign: TextAlign.center,
      ),
    );
  }
}
