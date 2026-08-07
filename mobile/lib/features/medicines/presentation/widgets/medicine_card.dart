/// One medicine in the list.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/time/medi_time.dart';
import '../../domain/dose_times.dart';
import '../../domain/medicine.dart';

class MedicineCard extends StatelessWidget {
  const MedicineCard({
    super.key,
    required this.medicine,
    required this.onEdit,
    required this.onRemove,
    this.now,
  });

  final Medicine medicine;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  /// Injectable so a widget test can pin the clock that decides which dose
  /// chips read as already past.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final clock = now ?? DateTime.now();
    final finished = medicine.hasEnded;

    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(medicine.name, style: context.texts.titleMedium),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '${medicine.dosage} · ${medicine.frequency}',
                        style: context.texts.bodyMedium
                            ?.copyWith(color: context.colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                _Menu(onEdit: onEdit, onRemove: onRemove, name: medicine.name),
              ],
            ),
            if (medicine.times.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final time in medicine.times)
                    _DoseChip(
                      time: time,
                      // A chip only reads as "done for today" while the course
                      // is running; on a finished course every time is history
                      // and striking them all through says nothing useful.
                      past: !finished && _isPast(time, clock),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              _courseLine(medicine),
              style: context.texts.bodySmall
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
            if (medicine.notes?.trim().isNotEmpty ?? false) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(medicine.notes!.trim(), style: context.texts.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  static bool _isPast(String time, DateTime now) {
    final minutes = DoseTimes.minutesOfDay(time);
    if (minutes == null) return false;
    return now.hour * 60 + now.minute > minutes;
  }

  static String _courseLine(Medicine medicine) {
    final start = MediTime.parseDate(medicine.startDate);
    final end = MediTime.parseDate(medicine.endDate);
    final from = start == null ? medicine.startDate : MediTime.date(start);
    if (end == null) return 'From $from · ongoing';
    return 'From $from to ${MediTime.date(end)}';
  }
}

/// A scheduled time. Struck through once the clock has passed it, so a glance
/// at the card says what is left today — the strike does the work, and the
/// muted colour only reinforces it.
class _DoseChip extends StatelessWidget {
  const _DoseChip({required this.time, required this.past});

  final String time;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final label = MediTime.clockLabel(time);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: AppRadius.full,
      ),
      child: Text(
        label,
        style: context.numerals.numericMedium.copyWith(
          fontSize: 13,
          color: past
              ? context.colors.onSurfaceVariant
              : context.colors.onSurface,
          decoration: past ? TextDecoration.lineThrough : null,
        ),
        semanticsLabel: past ? '$label, already passed' : label,
      ),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({
    required this.onEdit,
    required this.onRemove,
    required this.name,
  });

  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final String name;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      builder: (context, controller, child) => IconButton(
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.more_vert),
        tooltip: 'More for $name',
      ),
      menuChildren: [
        MenuItemButton(
          onPressed: onEdit,
          leadingIcon: const Icon(Icons.edit_outlined),
          child: const Text('Edit'),
        ),
        MenuItemButton(
          onPressed: onRemove,
          leadingIcon: Icon(Icons.delete_outline, color: context.colors.error),
          child: Text(
            'Remove',
            style: TextStyle(color: context.colors.error),
          ),
        ),
      ],
    );
  }
}
