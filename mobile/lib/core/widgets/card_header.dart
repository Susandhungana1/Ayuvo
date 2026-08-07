/// A card's top line: a title that may run long, and a badge that must stay
/// readable beside it.
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// A title with something small pinned to its right.
///
/// The obvious spelling — `Expanded(title)` then the badge — overflows once
/// text scaling is turned up, because a `Row` measures a non-flex child against
/// unbounded width and hands it whatever it asks for. At 2× a status chip
/// reading "Awaiting confirmation" asks for more than the whole phone.
///
/// So the badge is capped at half the line. Under the cap it sizes to its
/// content and sits hard against the right edge, exactly as an uncapped one
/// would; over it, the chip's own internal `Flexible` wraps the label onto a
/// second line rather than pushing off-screen. The title takes what is left and
/// wraps, so neither side can ever run out of room.
class CardHeader extends StatelessWidget {
  const CardHeader({
    super.key,
    required this.title,
    required this.trailing,
    this.titleStyle,
  });

  final String title;
  final Widget trailing;

  /// Defaults to `titleMedium` — the size every card on the app uses for its
  /// first line.
  final TextStyle? titleStyle;

  /// How much of the line the badge may take before it has to wrap.
  static const _trailingShare = 0.5;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cap = constraints.maxWidth.isFinite
            ? constraints.maxWidth * _trailingShare
            : double.infinity;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                style: titleStyle ?? context.texts.titleMedium,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: cap),
              child: trailing,
            ),
          ],
        );
      },
    );
  }
}

/// A list section's heading: what the section is, and how many rows are in it.
///
/// The count is the short half, so the label is the one that wraps.
class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(child: Text(label, style: context.texts.titleMedium)),
          const SizedBox(width: AppSpacing.sm),
          Text('$count', style: context.texts.bodySmall),
        ],
      ),
    );
  }
}
