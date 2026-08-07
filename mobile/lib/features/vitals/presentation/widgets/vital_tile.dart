/// One reading, judged against its band.
///
/// The number is the hero; the chip names the band; the range bar shows where
/// the reading sits inside it. Three encodings of the same fact, because a
/// colour on its own is not an answer.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/range_bar.dart';
import '../../domain/vital_ranges.dart';

class VitalTile extends StatelessWidget {
  const VitalTile({super.key, required this.reading, this.onTap});

  final VitalReading reading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final band = reading.metric.band;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.md,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                reading.metric.shortLabel,
                style: context.texts.labelSmall
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.xs),
              // Baseline-aligned so the unit sits on the number's feet rather
              // than floating beside its middle.
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      reading.display,
                      style: context.numerals.numericLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    reading.metric.unit,
                    style: context.texts.bodySmall
                        ?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: StatusChip(
                  label: reading.status,
                  status: reading.tone,
                  direction: reading.direction,
                ),
              ),
              if (band != null) ...[
                const SizedBox(height: AppSpacing.md),
                RangeBar(
                  value: reading.value,
                  min: band.min,
                  max: band.max,
                  normalLow: band.low,
                  normalHigh: band.high,
                  status: reading.tone,
                  direction: reading.direction,
                  showBounds: false,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Normal ${reading.metric.normalLabel}',
                  style: context.texts.bodySmall
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
