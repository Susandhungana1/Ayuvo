/// The shape every "add" and "edit" in this app takes.
///
/// A modal bottom sheet with a drag handle, a title, a scrolling body and a
/// footer that stays put — so the save button is reachable with a thumb and
/// does not scroll away under a keyboard. Four features use it; the behaviour
/// they share (busy state, inline failure, keyboard inset) lives here once.
library;

import 'package:flutter/material.dart';

import '../network/api_exception.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import 'states.dart';

/// Opens [child] as a modal sheet sized to its content, capped at 92% of the
/// screen so the sheet always reads as a sheet rather than a page.
Future<T?> showFormSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.92,
    ),
    builder: builder,
  );
}

class FormSheet extends StatelessWidget {
  const FormSheet({
    super.key,
    required this.title,
    required this.child,
    required this.submitLabel,
    required this.onSubmit,
    this.subtitle,
    this.busy = false,
    this.error,
    this.busyLabel,
  });

  final String title;

  /// One line on what saving will do, when that isn't obvious from the title.
  final String? subtitle;

  final Widget child;

  /// Names the action — "Save medicine", never "Submit".
  final String submitLabel;

  /// Null disables the button: a form that cannot be submitted says so by
  /// looking unavailable, not by failing when tapped.
  final VoidCallback? onSubmit;

  final bool busy;

  /// Shown while [busy] — "Uploading…" beats a spinner with no explanation.
  final String? busyLabel;

  /// Why the last save failed. Stays on screen while the user fixes it, which
  /// a snackbar would not.
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final failure = error == null ? null : ApiException.from(error!);

    return PopScope(
      // A save in flight cannot be swiped away. The request would keep running
      // with nobody to hear the answer — which for a report upload means four
      // minutes of OCR and two LLM calls landing on a screen that has gone,
      // and a report that exists on the server but not in the list until the
      // next refresh. Blocking the gesture is the honest option: the sheet is
      // already saying what it is waiting for.
      canPop: !busy,
      child: Padding(
        // The keyboard inset, so the footer sits above it rather than behind it.
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _DragHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.texts.titleLarge),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    style: context.texts.bodyMedium
                        ?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: child,
            ),
          ),
            _Footer(
              submitLabel: submitLabel,
              busyLabel: busyLabel,
              onSubmit: onSubmit,
              busy: busy,
              failure: failure,
            ),
          ],
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.outline,
        borderRadius: AppRadius.full,
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.submitLabel,
    required this.busyLabel,
    required this.onSubmit,
    required this.busy,
    required this.failure,
  });

  final String submitLabel;
  final String? busyLabel;
  final VoidCallback? onSubmit;
  final bool busy;
  final ApiException? failure;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (failure != null) ...[
            MessageBanner(message: failure!.message),
            const SizedBox(height: AppSpacing.md),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: busy ? null : onSubmit,
              child: busy
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.colors.onPrimary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(busyLabel ?? 'Saving…'),
                      ],
                    )
                  : Text(submitLabel),
            ),
          ),
        ],
      ),
    );
  }
}
