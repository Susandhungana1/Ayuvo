/// The drug-interaction warning that sits above the medicine list.
///
/// The data is an **offline dataset** checked against active medicines only —
/// not a live pharmacological service and not a clinical decision. The
/// disclaimer is carried verbatim from the web app for that reason, and the
/// banner says how many medicines were actually looked at so "nothing found"
/// cannot be mistaken for "nothing to find".
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../domain/medicine.dart';

const interactionDisclaimer =
    'Educational check only — always confirm with your doctor or pharmacist.';

class InteractionBanner extends StatelessWidget {
  const InteractionBanner({super.key, required this.check});

  final InteractionCheck check;

  @override
  Widget build(BuildContext context) {
    final interactions = check.interactions;
    if (interactions.isEmpty) return const SizedBox.shrink();

    return Card(
      color: context.status.alertContainer,
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 20, color: context.status.alert),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    interactions.length == 1
                        ? '1 possible interaction'
                        : '${interactions.length} possible interactions',
                    style: context.texts.titleMedium
                        ?.copyWith(color: context.status.alert),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            for (final interaction in interactions) ...[
              _InteractionRow(interaction: interaction),
              const SizedBox(height: AppSpacing.sm),
            ],
            Text(
              interactionDisclaimer,
              style: context.texts.bodySmall
                  ?.copyWith(color: context.status.alert),
            ),
            Text(
              'Checked ${check.checkedCount} '
              '${check.checkedCount == 1 ? 'medicine' : 'medicines'} you are '
              'currently taking. Finished courses are not included.',
              style: context.texts.bodySmall
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _InteractionRow extends StatelessWidget {
  const _InteractionRow({required this.interaction});

  final DrugInteraction interaction;

  @override
  Widget build(BuildContext context) {
    // Severity gets a word as well as a colour — the three levels have to
    // survive greyscale and colour blindness.
    final (label, tone) = switch (interaction.severity.toLowerCase()) {
      'severe' => ('Severe', context.status.alert),
      'moderate' => ('Moderate', context.status.caution),
      _ => ('Minor', context.colors.onSurfaceVariant),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.sm,
        border: Border.all(color: tone.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                label.toUpperCase(),
                style: context.texts.labelSmall?.copyWith(color: tone),
              ),
              Text(
                '${interaction.drugA} + ${interaction.drugB}',
                style: context.texts.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(interaction.description, style: context.texts.bodySmall),
        ],
      ),
    );
  }
}
