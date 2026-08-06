/// The two async states that are not "here is your data".
///
/// DESIGN.md §6: empty says what the screen is for and offers the one action
/// that fills it; error says what failed and offers Retry. Neither is ever a
/// shrug — "Something went wrong" is not allowed to reach a screen.
library;

import 'package:flutter/material.dart';

import '../network/api_exception.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;

  /// What this screen is for, in a few words.
  final String title;

  /// One sentence on what will be here once there is something.
  final String message;

  /// Names the action — "Add your first medicine", never "OK".
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: context.colors.onSurfaceVariant),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: context.texts.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: context.texts.bodyMedium
                  ?.copyWith(color: context.colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// What a failed load looks like inside a screen that otherwise works.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final failure = ApiException.from(error);
    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 20,
                  color: context.colors.error,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(failure.message, style: context.texts.bodyMedium),
                ),
              ],
            ),
            if (onRetry != null && failure.isRetryable) ...[
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum BannerTone { error, notice }

/// An inline message above a form: why the last submit failed, or why the app
/// sent you back to sign-in. Not a snackbar — it must stay on screen while the
/// user fixes the thing it is talking about.
class MessageBanner extends StatelessWidget {
  const MessageBanner({
    super.key,
    required this.message,
    this.tone = BannerTone.error,
  });

  final String message;
  final BannerTone tone;

  @override
  Widget build(BuildContext context) {
    final (fg, bg, icon) = switch (tone) {
      BannerTone.error => (
          context.colors.onErrorContainer,
          context.colors.errorContainer,
          Icons.error_outline,
        ),
      BannerTone.notice => (
          context.colors.onSurface,
          context.colors.surfaceContainerHigh,
          Icons.info_outline,
        ),
    };

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: bg, borderRadius: AppRadius.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: context.texts.bodyMedium?.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
