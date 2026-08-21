/// Reusable pieces for the public share readers (whole record and single
/// report). Kept local to the sharing feature because the web reader renders
/// the same sections and both screens share them.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/time/medi_time.dart';
import '../domain/shared_record.dart';

/// Section heading between blocks of a shared record.
class SharedSectionHeader extends StatelessWidget {
  const SharedSectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: context.texts.titleMedium);
  }
}

/// The red emergency card, shown only when the record has something to say.
class SharedEmergencyCard extends StatelessWidget {
  const SharedEmergencyCard({super.key, required this.emergency});

  final SharedEmergency emergency;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: context.colors.errorContainer,
        borderRadius: AppRadius.md,
        border: Border.all(color: context.colors.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.healing, size: 20, color: context.colors.error),
              const SizedBox(width: AppSpacing.sm),
              Text('Emergency ID', style: context.texts.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (emergency.bloodType?.trim().isNotEmpty ?? false)
            _Row(label: 'Blood type', value: emergency.bloodType!),
          if (emergency.contacts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Emergency contacts', style: context.texts.labelMedium),
            const SizedBox(height: AppSpacing.xxs),
            for (final contact in emergency.contacts)
              Text(
                '${contact.name} · ${contact.phone}',
                style: context.texts.bodySmall,
              ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text('$label: $value', style: context.texts.bodyMedium),
    );
  }
}

/// One medicine row of a shared record.
class SharedMedicineTile extends StatelessWidget {
  const SharedMedicineTile({super.key, required this.medicine});

  final SharedMedicine medicine;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Icon(Icons.medication_outlined, color: context.colors.primary),
        title: Text(medicine.name, style: context.texts.bodyLarge),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (medicine.dosage.trim().isNotEmpty)
              Text(
                'Dosage: ${medicine.dosage}',
                style: context.texts.bodySmall,
              ),
            if (medicine.frequency.trim().isNotEmpty)
              Text(
                'Frequency: ${medicine.frequency}',
                style: context.texts.bodySmall,
              ),
            Text(
              'Started: ${medicine.startDate}',
              style: context.texts.bodySmall,
            ),
            if (medicine.endDate?.trim().isNotEmpty ?? false)
              Text('Ends: ${medicine.endDate}', style: context.texts.bodySmall),
            if (medicine.notes?.trim().isNotEmpty ?? false)
              Text(
                medicine.notes!,
                style: context.texts.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}

/// One report row of a shared record; `onView` opens the original file.
class SharedReportTile extends StatelessWidget {
  const SharedReportTile({super.key, required this.report, this.onView});

  final SharedReportItem report;
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.description_outlined)),
        title: Text(report.reportType.replaceAll('_', ' ')),
        subtitle: Text(
          [
            report.fileName,
            if (report.created != null) MediTime.dateOnly(report.created!),
          ].join('\n'),
          style: context.texts.bodySmall,
        ),
        isThreeLine: report.created != null,
        trailing: onView == null
            ? null
            : TextButton(onPressed: onView, child: const Text('View')),
      ),
    );
  }
}
