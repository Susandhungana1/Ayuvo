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
import 'package:intl/intl.dart';

import '../../../core/cache/offline_cache.dart';
import '../../../core/router/routes.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/time/medi_time.dart';
import '../../../core/widgets/range_bar.dart' show RangeStatus;
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/states.dart';
import '../../care/presentation/people_i_care_for.dart';
import '../../appointments/presentation/appointments_controller.dart';
import '../../medicines/data/medicine_repository.dart';
import '../../medicines/domain/dose_schedule.dart';
import '../../medicines/domain/medicine.dart';
import '../../medicines/presentation/medicines_controller.dart';
import '../../reports/presentation/reports_controller.dart';
import '../../vitals/domain/vital_ranges.dart';
import '../../vitals/presentation/vitals_controller.dart';

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
            ref.read(appointmentsProvider.notifier).refresh(),
            ref.read(reportsProvider.notifier).refresh(),
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
            const _OfflineNotice(),
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
            const SizedBox(height: AppSpacing.xl),
            const _Upcoming(),
            const SizedBox(height: AppSpacing.md),
            const _TomorrowPlan(),
            // Nothing at all for the vast majority of accounts, which have no
            // care links. See `people_i_care_for.dart`.
            const SizedBox(height: AppSpacing.xl),
            const PeopleICareFor(),
          ],
        ),
      ),
    );
  }
}

/// "You are looking at a saved copy."
///
/// Only appears when the app is actually showing cached rows *and* the attempt
/// to refresh them failed. Silence otherwise: a permanent "offline mode"
/// banner is furniture, and one that appears while the data is in fact current
/// teaches people to ignore it.
class _OfflineNotice extends ConsumerWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(cacheStatusProvider(CacheKeys.medicines));
    if (!status.isStale) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: MessageBanner(
        tone: BannerTone.notice,
        message: 'Showing what was saved ${MediTime.ago(status.savedAt!)}. '
            'MediStore could not be reached, so anything added since is '
            'missing.',
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

/// Consecutive days, ending yesterday, where every scheduled dose was marked
/// taken. Days with no schedule are neutral (neither break nor extend).
/// Today is deliberately excluded: an unfinished day says nothing yet.
int _adherenceStreak(
  List<Medicine> medicines,
  Iterable<dynamic> intakeLog,
  DateTime now,
) {
  final taken = <String>{
    for (final intake in intakeLog)
      if (intake.status == 'taken' && intake.recorded != null)
        '${intake.medicineId}-${intake.scheduledTime}'
            '@${MediTime.dateOnly(intake.recorded!)}',
  };

  var streak = 0;
  for (var back = 1; back <= 30; back++) {
    final day = DateTime(now.year, now.month, now.day - back);
    final slots = DoseSchedule.forDay(medicines, day);
    if (slots.isEmpty) continue; // a day off neither breaks nor extends
    final allTaken = slots.every(
      (slot) =>
          taken.contains('${slot.key}@$day') ||
          taken.contains('${slot.key}@${MediTime.dateOnly(day)}'),
    );
    if (!allTaken) return streak;
    streak++;
  }
  return streak;
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

    // Intake log for pre-marking doses already taken today.
    final intakeLog = ref.watch(intakeLogProvider).valueOrNull ?? const [];
    final todayKey = MediTime.dateOnly(now);
    final preTaken = <String>{};
    for (final intake in intakeLog) {
      if (intake.status != 'taken') continue;
      final recorded = intake.recorded;
      if (recorded == null) continue;
      final intakeDate = MediTime.dateOnly(recorded);
      if (intakeDate != todayKey) continue;
      preTaken.add('${intake.medicineId}-${intake.scheduledTime}');
    }

    final streak = _adherenceStreak(medicines, intakeLog, now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Today', style: context.texts.titleLarge)),
            if (streak >= 2)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department,
                        size: 16, color: context.status.caution),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      '$streak-day streak',
                      style: context.texts.bodySmall?.copyWith(
                        color: context.status.caution,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
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
                  _DoseRow(
                    key: ValueKey(slot.key),
                    slot: slot,
                    now: now,
                    preTaken: preTaken.contains(slot.key),
                  ),
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
  const _DoseRow({
    super.key,
    required this.slot,
    required this.now,
    required this.preTaken,
  });

  final DoseSlot slot;
  final DateTime now;
  final bool preTaken;

  @override
  ConsumerState<_DoseRow> createState() => _DoseRowState();
}

class _DoseRowState extends ConsumerState<_DoseRow> {
  bool _saving = false;

  /// Local mark from pressing "Taken" this session.
  bool _localMarked = false;

  /// Whether the dose was already taken (from intake log).
  bool get _marked => widget.preTaken || _localMarked;

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
          _localMarked = true;
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

/// One-glance health status: a single thin strip of chips — label, latest
/// value, status colour — instead of a tile grid. Full detail and trends live
/// in the Vitals tab, one tap away; home only answers "am I OK?".
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
          SkeletonCard(lines: 1),
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
              child: Text('Health', style: context.texts.titleLarge),
            ),
            if (measured != null)
              Text(
                MediTime.ago(measured),
                style: context.texts.bodySmall
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: InkWell(
            onTap: () => context.go(Routes.vitals),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final reading in readings) ...[
                      _HealthChip(reading: reading),
                      const SizedBox(width: AppSpacing.md),
                    ],
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: context.colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One metric as a chip: coloured status dot · value · short label.
class _HealthChip extends StatelessWidget {
  const _HealthChip({required this.reading});

  final VitalReading reading;

  @override
  Widget build(BuildContext context) {
    final tone = switch (reading.tone) {
      RangeStatus.ok => context.status.ok,
      RangeStatus.caution => context.status.caution,
      RangeStatus.alert => context.status.alert,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              reading.display,
              style: context.numerals.numericMedium
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          // Normal stays quiet — the default state shouldn't shout. Anything
          // else is named, so the strip reads without its colour dot too.
          reading.isNormal
              ? switch (reading.metric) {
                  VitalMetric.bloodPressure => 'BP',
                  VitalMetric.heartRate => 'Heart',
                  VitalMetric.bloodSugar => 'Sugar',
                  VitalMetric.temperature => 'Temp',
                  VitalMetric.oxygenSaturation => 'SpO₂',
                  VitalMetric.weight => 'Weight',
                }
              : '${switch (reading.metric) {
                  VitalMetric.bloodPressure => 'BP',
                  VitalMetric.heartRate => 'Heart',
                  VitalMetric.bloodSugar => 'Sugar',
                  VitalMetric.temperature => 'Temp',
                  VitalMetric.oxygenSaturation => 'SpO₂',
                  VitalMetric.weight => 'Weight',
                }} · ${reading.status}',
          style: context.texts.labelSmall?.copyWith(
            color:
                reading.isNormal ? context.colors.onSurfaceVariant : tone,
          ),
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

/// The next two things on the calendar after doses: the nearest appointment
/// and the newest report. Read-only glances — each deep-links to its tab
/// rather than duplicating it.
class _Upcoming extends ConsumerWidget {
  const _Upcoming();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointments = ref.watch(appointmentsProvider);
    final reports = ref.watch(reportsProvider);

    if (appointments.isLoading || reports.isLoading) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(width: 110, height: 20),
          SizedBox(height: AppSpacing.md),
          SkeletonCard(lines: 1),
        ],
      );
    }

    final upcoming =
        splitAppointments(appointments.valueOrNull ?? const []).upcoming;
    final reportsList = reports.valueOrNull ?? const [];
    final latestReport = reportsList.isEmpty ? null : reportsList.first;

    // Nothing on the calendar and nothing filed: silence beats furniture.
    if (upcoming.isEmpty && latestReport == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Upcoming', style: context.texts.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        if (upcoming.isNotEmpty)
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_outlined),
              title: Text(upcoming.first.title),
              subtitle: Text(
                [
                  if (upcoming.first.who.isNotEmpty) upcoming.first.who,
                  MediTime.dateTime(upcoming.first.startsAt!),
                ].join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(Routes.appointments),
            ),
          ),
        if (latestReport != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(latestReport.typeLabel),
              subtitle: Text(
                latestReport.dated == null
                    ? 'Undated'
                    : MediTime.date(latestReport.dated!),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(Routes.reports),
            ),
          ),
      ],
    );
  }
}

/// Tomorrow's schedule, so the day ahead is knowable the night before.
/// Read-only by design: a future dose has nothing to mark yet. Hidden
/// entirely when nothing is scheduled — silence beats furniture.
class _TomorrowPlan extends ConsumerWidget {
  const _TomorrowPlan();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medicines = ref.watch(medicinesProvider(null)).valueOrNull;
    if (medicines == null || medicines.isEmpty) return const SizedBox.shrink();

    final now = ref.watch(_clockProvider).valueOrNull ?? DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final slots = DoseSchedule.forDay(medicines, tomorrow);
    if (slots.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tomorrow · ${DateFormat.E().format(tomorrow)}',
          style: context.texts.titleMedium,
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
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 68,
                          child: Text(
                            MediTime.clockLabel(slot.time),
                            style: context.numerals.numericMedium.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            slot.medicine.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
