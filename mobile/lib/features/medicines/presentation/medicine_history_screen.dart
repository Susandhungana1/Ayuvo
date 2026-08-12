/// Two histories the web app never showed: the doses you marked, and every
/// change made to the list.
///
/// `GET /api/medicines/intake/log` has existed unused since it was written, and
/// `GET /api/medicines/audit` is the patient's only way to see what a caretaker
/// did on their behalf. Both are read-only.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/time/medi_time.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/states.dart';
import '../data/medicine_repository.dart';
import '../domain/medicine.dart';
import 'medicines_controller.dart';

/// `GET /api/medicines/audit`, scoped like the list.
final medicineAuditProvider =
    FutureProvider.family<List<MedicineAuditEntry>, String?>(
  (ref, patientId) =>
      ref.watch(medicineRepositoryProvider).audit(patientId: patientId),
);

class MedicineHistoryScreen extends ConsumerWidget {
  const MedicineHistoryScreen({super.key, this.patientId});

  final String? patientId;

  /// The dose log is the patient's own account of what they swallowed, so the
  /// server offers no way to read someone else's. A caretaker gets one tab.
  bool get _showDoses => patientId == null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: _showDoses ? 2 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('History'),
          bottom: TabBar(
            tabs: [
              if (_showDoses) const Tab(text: 'Doses'),
              const Tab(text: 'Changes'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            if (_showDoses) const _DoseLog(),
            _ChangeLog(patientId: patientId),
          ],
        ),
      ),
    );
  }
}

class _DoseLog extends ConsumerWidget {
  const _DoseLog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(intakeLogProvider);
    // Names, so a row can say "Amlodipine" rather than an id. A medicine that
    // has since been deleted simply has no name here, and the row says so
    // rather than hiding.
    final names = {
      for (final medicine in ref.watch(medicinesProvider(null)).valueOrNull ??
          const <Medicine>[])
        medicine.id: medicine.name,
    };

    return switch (log) {
      AsyncData(:final value) when value.isEmpty => const EmptyState(
          icon: Icons.check_circle_outline,
          title: 'No doses marked yet',
          message: 'When you mark a dose as taken, snoozed or skipped from '
              'your schedule, it is recorded here.',
        ),
      AsyncData(:final value) => ListView.builder(
          padding: AppSpacing.screen,
          itemCount: value.length,
          itemBuilder: (context, index) => _IntakeRow(
            intake: value[index],
            medicineName: names[value[index].medicineId],
          ),
        ),
      AsyncError(:final error) => ListView(
          padding: AppSpacing.screen,
          children: [
            ErrorView(
              error: error,
              onRetry: () => ref.invalidate(intakeLogProvider),
            ),
          ],
        ),
      _ => const _LoadingRows(),
    };
  }
}

class _IntakeRow extends StatelessWidget {
  const _IntakeRow({required this.intake, required this.medicineName});

  final MedicineIntake intake;
  final String? medicineName;

  @override
  Widget build(BuildContext context) {
    final (icon, tone, verb) = switch (intake.status) {
      'taken' => (Icons.check_circle, context.status.ok, 'Taken'),
      'snoozed' => (Icons.snooze, context.status.caution, 'Snoozed'),
      'skipped' => (Icons.remove_circle_outline, context.status.alert, 'Skipped'),
      _ => (Icons.circle_outlined, context.colors.onSurfaceVariant, intake.status),
    };
    final recorded = intake.recorded;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: tone),
      title: Text(medicineName ?? 'A medicine you have since removed'),
      subtitle: Text(
        '$verb · ${MediTime.clockLabel(intake.scheduledTime)} dose'
        '${recorded == null ? '' : ' · ${MediTime.ago(recorded)}'}',
      ),
    );
  }
}

class _ChangeLog extends ConsumerWidget {
  const _ChangeLog({required this.patientId});

  final String? patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audit = ref.watch(medicineAuditProvider(patientId));

    return switch (audit) {
      AsyncData(:final value) when value.isEmpty => const EmptyState(
          icon: Icons.history,
          title: 'No changes recorded',
          message: 'Every addition, edit and removal shows up here — '
              'including anything a caretaker does for you.',
        ),
      AsyncData(:final value) => ListView.builder(
          padding: AppSpacing.screen,
          itemCount: value.length,
          itemBuilder: (context, index) => _AuditRow(entry: value[index]),
        ),
      AsyncError(:final error) => ListView(
          padding: AppSpacing.screen,
          children: [
            ErrorView(
              error: error,
              onRetry: () => ref.invalidate(medicineAuditProvider(patientId)),
            ),
          ],
        ),
      _ => const _LoadingRows(),
    };
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry});

  final MedicineAuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final (icon, verb) = switch (entry.action) {
      'create' => (Icons.add_circle_outline, 'Added'),
      'update' => (Icons.edit_outlined, 'Edited'),
      'delete' => (Icons.delete_outline, 'Removed'),
      'restore' => (Icons.undo, 'Restored'),
      _ => (Icons.circle_outlined, entry.action),
    };
    final created = entry.created;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: context.colors.onSurfaceVariant),
      title: Text('$verb ${entry.medicineName ?? 'a medicine'}'),
      subtitle: Text(
        [
          // "You" reads better than your own name in your own history.
          entry.byCaretaker ? '${entry.actorName} (caretaker)' : 'You',
          if (created != null) MediTime.ago(created),
        ].join(' · '),
      ),
    );
  }
}

class _LoadingRows extends StatelessWidget {
  const _LoadingRows();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.screen,
      children: const [
        SkeletonCard(lines: 2),
        SizedBox(height: AppSpacing.md),
        SkeletonCard(lines: 2),
        SizedBox(height: AppSpacing.md),
        SkeletonCard(lines: 2),
      ],
    );
  }
}
