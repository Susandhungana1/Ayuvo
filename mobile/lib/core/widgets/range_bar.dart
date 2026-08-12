/// The design system's signature element — see DESIGN.md §1.
///
/// Every meaningful number in this product is judged against a band: a blood
/// pressure is "128/82, which is elevated"; a lab result is a value beside the
/// reference range printed next to it. The range bar shows that band instead of
/// only naming it, so a reading's position carries the meaning and colour is
/// never doing the job alone.
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

enum RangeStatus { ok, caution, alert }

/// Which side of the band a reading sits on. Rendered as a glyph, so the state
/// survives greyscale, colour blindness and forced-colours mode.
enum RangeDirection { within, below, above }

class RangeBar extends StatelessWidget {
  const RangeBar({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.normalLow,
    required this.normalHigh,
    required this.status,
    this.direction = RangeDirection.within,
    this.showBounds = true,
  });

  final double value;

  /// The ends of the drawn track — wider than the normal band, so an
  /// out-of-range reading still lands somewhere visible.
  final double min;
  final double max;

  /// The normal band, drawn as the filled segment.
  final double normalLow;
  final double normalHigh;

  final RangeStatus status;
  final RangeDirection direction;
  final bool showBounds;

  static const _trackHeight = 6.0;
  static const _markerWidth = 3.0;
  static const _markerHeight = 14.0;

  double _fraction(double v) =>
      ((v - min) / (max - min)).clamp(0.0, 1.0).toDouble();

  Color _statusColor(BuildContext context) => switch (status) {
        RangeStatus.ok => context.status.ok,
        RangeStatus.caution => context.status.caution,
        RangeStatus.alert => context.status.alert,
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final marker = _statusColor(context);

    return Semantics(
      // A screen reader gets the sentence, not the geometry.
      label: 'Reading $value, normal range $normalLow to $normalHigh',
      value: switch (direction) {
        RangeDirection.within => 'within range',
        RangeDirection.below => 'below range',
        RangeDirection.above => 'above range',
      },
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: _markerHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final bandLeft = _fraction(normalLow) * width;
                final bandRight = _fraction(normalHigh) * width;
                final markerLeft = (_fraction(value) * width)
                    .clamp(0.0, width - _markerWidth);

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // The full track.
                    Positioned(
                      left: 0,
                      right: 0,
                      top: (_markerHeight - _trackHeight) / 2,
                      child: Container(
                        height: _trackHeight,
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: AppRadius.full,
                        ),
                      ),
                    ),
                    // The normal band.
                    Positioned(
                      left: bandLeft,
                      width: bandRight - bandLeft,
                      top: (_markerHeight - _trackHeight) / 2,
                      child: Container(
                        height: _trackHeight,
                        decoration: BoxDecoration(
                          color: context.status.okContainer,
                          borderRadius: AppRadius.full,
                        ),
                      ),
                    ),
                    // The reading.
                    Positioned(
                      left: markerLeft,
                      top: 0,
                      child: Container(
                        width: _markerWidth,
                        height: _markerHeight,
                        decoration: BoxDecoration(
                          color: marker,
                          borderRadius: AppRadius.full,
                          // A 2px surface ring keeps the marker legible where
                          // it overlaps the band fill.
                          border: Border.all(color: colors.surface, width: 0),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (showBounds) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(_format(normalLow), style: context.texts.bodySmall),
                ),
                Flexible(
                  child: Text(_format(normalHigh), style: context.texts.bodySmall),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _format(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

/// A status label. Carries its text and, when out of range, a direction glyph —
/// never colour alone.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.status,
    this.direction = RangeDirection.within,
  });

  final String label;
  final RangeStatus status;
  final RangeDirection direction;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (status) {
      RangeStatus.ok => (context.status.ok, context.status.okContainer),
      RangeStatus.caution => (context.status.caution, context.status.cautionContainer),
      RangeStatus.alert => (context.status.alert, context.status.alertContainer),
    };

    final glyph = switch (direction) {
      RangeDirection.within => null,
      RangeDirection.below => '▼',
      RangeDirection.above => '▲',
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.full),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (glyph != null) ...[
            Text(glyph, style: context.texts.labelSmall?.copyWith(color: fg)),
            const SizedBox(width: AppSpacing.xxs),
          ],
          // Flexible so a long band name in a bounded column wraps instead of
          // overflowing once text scaling is turned up.
          Flexible(
            child: Text(label, style: context.texts.labelSmall?.copyWith(color: fg)),
          ),
        ],
      ),
    );
  }
}
