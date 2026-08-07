/// The dashboard: what to take next, what is left today, and where the
/// numbers stand.
///
/// It reads the medicines and vitals the other tabs already hold, so opening
/// the app costs two requests rather than five and switching to a tab shows
/// data that is already there. `/dashboard`'s link grid from the web is not
/// ported — a bottom bar makes it a crutch.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/time/medi_time.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/states.dart';
import '../../medicines/data/medicine_repository.dart';
import '../../medicines/domain/dose_schedule.dart';
import '../../medicines/domain/medicine.dart';
import '../../medicines/presentation/medicines_controller.dart';
import '../../vitals/domain/vital_ranges.dart';
import '../../vitals/presentation/vitals_controller.dart';
import '../../vitals/presentation/widgets/vital_tile.dart';

/// Ticks once a minute so the countdown stays true without the screen
/// rebuilding sixty times an hour for nothing.
final _clockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now());
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final medicines = ref.watch(medicinesProvider(null));
    final vitals = ref.watch(vitalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(medicinesProvider(null).notifier).refresh(),
            ref.read(vitalsProvider.notifier).refresh(),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            Text(
              user == null ? 'Hello' : 'Hello, ${user.shortName}',
              style: context.texts.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            const _NextDose(),
            const SizedBox(height: AppSpacing.lg),
            const _Today(),
            const SizedBox(height: AppSpacing.xl),
            const _LatestVitals(),
            // Only surfaces once both loads have settled, so the screen does
            // not offer "add your first" while the answer is still arriving.
            if (medicines.hasValue && vitals.hasValue) ...[
              const SizedBox(height: AppSpacing.xl),
              const _Shortcuts(),
            ],
          ],
        ),
      ),
    );
  }
}

class _NextDose extends ConsumerWidget {
  const _NextDose();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medicines = ref.watch(medicinesProvider(null));
    final now = ref.watch(_clockProvider).valueOrNull ?? DateTime.now();

    return switch (medicines) {
      AsyncData(:final value) => _nextCard(context, ref, value, now),
      AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.read(medicinesProvider(null).notifier).refresh(),
        ),
      _ => const SkeletonCard(lines: 2),
    };
  }

  Widget _nextCard(
    BuildContext context,
    WidgetRef ref,
    List<Medicine> medicines,
    DateTime now,
  ) {
    final next = DoseSchedule.next(medicines, now);
    if (next == null) {
      return Card(
        child: Padding(
          padding: AppSpacing.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nothing scheduled', style: context.texts.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                medicines.isEmpty
                    ? 'Add a medicine with its dose times and the next one '
                        'shows up here.'
                    : 'None of your medicines has a dose time set, so there '
                        'is no schedule to count down to.',
                style: context.texts.bodyMedium
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: () => context.go(Routes.medicines),
                child: Text(
                  medicines.isEmpty ? 'Add a medicine' : 'Set dose times',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final gap = next.at.difference(now);
    final tomorrow = next.at.day != now.day;

    return Card(
      color: context.colors.primaryContainer,
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Next dose',
              style: context.texts.labelSmall
                  ?.copyWith(color: context.colors.onPrimaryContainer),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              next.medicine.name,
              style: context.texts.headlineMedium
                  ?.copyWith(color: context.colors.onPrimaryContainer),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '${next.medicine.dosage} · '
              '${MediTime.clockLabel(next.time)}'
              '${tomorrow ? ' tomorrow' : ''} · ${MediTime.until(gap)}',
              style: context.texts.bodyMedium
                  ?.copyWith(color: context.colors.onPrimaryContainer),
            ),
          ],
        ),
      ),
    );
  }
}

class _Today extends ConsumerWidget {
  const _Today();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medicines = ref.watch(medicinesProvider(null)).valueOrNull;
    if (medicines == null || medicines.isEmpty) return const SizedBox.shrink();

    final now = ref.watch(_clockProvider).valueOrNull ?? DateTime.now();
    final slots = DoseSchedule.forDay(medicines, now);
    if (slots.isEmpty) return const SizedBox.shrink();

    final remaining = slots.where((slot) => !slot.isPast(now)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Today', style: context.texts.titleLarge),
            ),
            Text(
              remaining == 0
                  ? 'All ${slots.length} done'
                  : '$remaining of ${slots.length} left',
              style: context.texts.bodySmall
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: [
                for (final slot in slots)
                  _DoseRow(key: ValueKey(slot.key), slot: slot, now: now),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One dose, with the one action worth having on a dashboard: mark it taken.
///
/// `POST /{id}/intake` is self-only and has no undo, so the row commits
/// straight away and reports failure rather than pretending. Snooze and skip
/// belong with the reminder that fires, which is phase 6.
class _DoseRow extends ConsumerStatefulWidget {
  const _DoseRow({super.key, required this.slot, required this.now});

  final DoseSlot slot;
  final DateTime now;

  @override
  ConsumerState<_DoseRow> createState() => _DoseRowState();
}

class _DoseRowState extends ConsumerState<_DoseRow> {
  bool _saving = false;

  /// Local only. The server keeps a log but exposes no "was this dose taken"
  /// query, so a mark made here survives the screen and not the app — and the
  /// row says so rather than implying a checkmark is permanent.
  bool _marked = false;

  Future<void> _markTaken() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(medicineRepositoryProvider).recordIntake(
            widget.slot.medicine.id,
            scheduledTime: widget.slot.time,
          );
      if (mounted) {
        setState(() {
          _saving = false;
          _marked = true;
        });
      }
      ref.invalidate(intakeLogProvider);
    } catch (error) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(ErrorText.of(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final past = widget.slot.isPast(widget.now);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            child: Text(
              MediTime.clockLabel(widget.slot.time),
              style: context.numerals.numericMedium.copyWith(
                color: past
                    ? context.colors.onSurfaceVariant
                    : context.colors.onSurface,
              ),
            ),
          ),
          Expanded(
            child: Text(
              widget.slot.medicine.name,
              style: context.texts.bodyMedium?.copyWith(
                color: _marked ? context.colors.onSurfaceVariant : null,
                decoration: _marked ? TextDecoration.lineThrough : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_marked)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, size: 18, color: context.status.ok),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Taken',
                    style: context.texts.bodySmall
                        ?.copyWith(color: context.status.ok),
                  ),
                ],
              ),
            )
          else if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.md),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _markTaken,
              child: const Text('Taken'),
            ),
        ],
      ),
    );
  }
}

class _LatestVitals extends ConsumerWidget {
  const _LatestVitals();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vitals = ref.watch(vitalsProvider);
    final latest = ref.watch(latestVitalProvider);

    if (vitals.isLoading) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(width: 120, height: 20),
          SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: SkeletonCard(lines: 2)),
              SizedBox(width: AppSpacing.md),
              Expanded(child: SkeletonCard(lines: 2)),
            ],
          ),
        ],
      );
    }

    if (latest == null) return const SizedBox.shrink();

    final readings = VitalRanges.readingsOf(latest);
    if (readings.isEmpty) return const SizedBox.shrink();

    final measured = latest.measured;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Latest vitals', style: context.texts.titleLarge),
            ),
            if (measured != null)
              Text(
                MediTime.ago(measured),
                style: context.texts.bodySmall
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: 0.92,
          children: [
            for (final reading in readings)
              VitalTile(
                reading: reading,
                onTap: () => context.go(Routes.vitals),
              ),
          ],
        ),
      ],
    );
  }
}

/// The two things a first-time user has nothing of yet. Both disappear once
/// there is something to show, rather than becoming permanent furniture.
class _Shortcuts extends ConsumerWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasMedicines =
        (ref.watch(medicinesProvider(null)).valueOrNull ?? const []).isNotEmpty;
    final hasVitals = ref.watch(latestVitalProvider) != null;
    if (hasMedicines && hasVitals) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Get started', style: context.texts.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        if (!hasMedicines)
          Card(
            child: ListTile(
              leading: const Icon(Icons.medication_outlined),
              title: const Text('Add a medicine'),
              subtitle: const Text('Dose times become your daily schedule'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(Routes.medicines),
            ),
          ),
        if (!hasVitals)
          Card(
            child: ListTile(
              leading: const Icon(Icons.monitor_heart_outlined),
              title: const Text('Record a reading'),
              subtitle: const Text('Judged against its normal range'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(Routes.vitals),
            ),
          ),
      ],
    );
  }
}
