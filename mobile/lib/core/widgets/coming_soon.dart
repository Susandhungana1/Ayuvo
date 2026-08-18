/// A placeholder for features that are not available yet.
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

class ComingSoonView extends StatelessWidget {
  const ComingSoonView({super.key, this.title = 'Coming soon'});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: context.colors.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.schedule,
                size: 32,
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: context.texts.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Appointments are on the way. We are preparing the booking '
              'experience — check back soon.',
              textAlign: TextAlign.center,
              style: context.texts.bodyMedium
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}