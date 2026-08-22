import 'package:flutter/material.dart';

/// A "Load more" button shown at the end of a paginated list.
///
/// When [loading] is true, a spinner is shown instead of the label.
/// When there are no more items to load ([remaining] <= 0), nothing is rendered.
class LoadMoreButton extends StatelessWidget {
  const LoadMoreButton({
    super.key,
    required this.offset,
    required this.total,
    required this.onTap,
    this.loading = false,
  });

  final int offset;
  final int total;
  final VoidCallback onTap;
  final bool loading;

  int get remaining => total - offset;

  @override
  Widget build(BuildContext context) {
    if (remaining <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: onTap,
                child: Text('Load more ($remaining remaining)'),
              ),
      ),
    );
  }
}
