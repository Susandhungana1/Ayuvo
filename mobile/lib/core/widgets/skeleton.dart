/// Loading placeholders shaped like the thing that is coming.
///
/// DESIGN.md §6: a bare spinner tells you nothing about what to expect, so
/// every async surface loads as a skeleton in the shape of its result.
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    required this.width,
    this.height = 16,
    this.radius = AppRadius.sm,
  });

  /// A full-width block, for a line of body text.
  const Skeleton.line({Key? key, double height = 16})
      : this(key: key, width: double.infinity, height: height);

  final double width;
  final double height;
  final BorderRadius radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion means no pulse — it holds still at the mid opacity rather
    // than breathing.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controller
        ..stop()
        ..value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.colors.surfaceContainerHighest;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(base, context.colors.outlineVariant,
                _controller.value * 0.6),
            borderRadius: widget.radius,
          ),
        ),
      ),
    );
  }
}

/// A card-shaped skeleton: a title line and two body lines.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.lines = 2});

  final int lines;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Skeleton(width: 140, height: 20),
            for (var i = 0; i < lines; i++) ...[
              const SizedBox(height: AppSpacing.md),
              Skeleton.line(height: i.isEven ? 14 : 12),
            ],
          ],
        ),
      ),
    );
  }
}
