import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// A filled button that turns into a progress indicator while it waits, so a
/// form can never be submitted twice by an impatient tap.
class SubmitButton extends StatelessWidget {
  const SubmitButton({
    super.key,
    required this.label,
    required this.submitting,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final bool submitting;
  final VoidCallback onPressed;

  /// Extra gate beyond [submitting] — e.g. the consent checkbox on sign-up.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: submitting || !enabled ? null : onPressed,
      child: submitting
          ? SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.colors.onPrimary,
              ),
            )
          : Text(label),
    );
  }
}
