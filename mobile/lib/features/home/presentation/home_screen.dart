/// The dashboard: what to take next, what is late, and everything else one tap
/// away.
///
/// Five sections, in the order a patient needs them: a health summary that
/// answers "what now?", a row of actions that reaches every core screen, the
/// newest reports, the way to hand a record to a doctor, and what has happened
/// lately. It reads the medicines, vitals, reports and appointments the other
/// tabs already hold, so opening the app costs no extra request and switching
/// to a tab shows data that is already there.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/cache/offline_cache.dart';
import '../../../core/router/routes.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/time/medi_time.dart';
import '../../../core/widgets/range_bar.dart' show RangeStatus;
import '../../../core/widgets/press_effect.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/states.dart';
import '../../care/presentation/people_i_care_for.dart';
import '../../appointments/domain/appointment.dart';
import '../../appointments/presentation/appointments_controller.dart';
import '../../medicines/data/medicine_repository.dart';
import '../../medicines/domain/dose_schedule.dart';
import '../../medicines/domain/medicine.dart';
import '../../medicines/presentation/medicines_controller.dart';
import '../../reports/presentation/report_upload_sheet.dart';
import '../../reports/presentation/reports_controller.dart';
import '../../vitals/domain/vital_ranges.dart';
import '../../vitals/domain/vital_sign.dart';
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
    final now = ref.watch(_clockProvider).valueOrNull ?? DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: RefreshIndicator(
        onRefresh: () async {
          // The intake log is what "taken" is read from, so a pull that leaves
          // it stale would show a dose as still due after it was marked.
          ref.invalidate(intakeLogProvider);
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
            const _OfflineNotice(),

            // 1 — Greeting and health summary.
            Text(
              '${_greeting(now)}, ${user?.shortName ?? 'there'}',
              style: context.texts.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            const _HealthSummary(),

            // 2 — Everything core, one tap away.
            const SizedBox(height: AppSpacing.xl),
            const _QuickActions(),

            // 3 — The newest reports.
            const SizedBox(height: AppSpacing.xl),
            const _RecentReports(),

            // 4 — The one thing done *for someone else*.
            const SizedBox(height: AppSpacing.xl),
            const _ShareRecordCard(),

            // 5 — What has happened. Hidden entirely when nothing has.
            const SizedBox(height: AppSpacing.xl),
            const _RecentActivity(),

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

String _greeting(DateTime now) {
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 17) return 'Good afternoon';
  return 'Good evening';
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
            'Ayuvo could not be reached, so anything added since is '
            'missing.',
      ),
    );
  }
}

/// Section 1 — the whole answer to "what do I do about my health right now".
///
/// Next dose, anything late, what is left today, the streak, and the latest
/// reading. Doses that are already taken are not listed: there is no undo, so
/// a taken row is furniture. The counter says how many there were.
class _HealthSummary extends ConsumerWidget {
  const _HealthSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medicines = ref.watch(medicinesProvider(null));

    return switch (medicines) {
      AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.read(medicinesProvider(null).notifier).refresh(),
        ),
      AsyncData(:final value) => _card(context, ref, value),
      _ => const SkeletonCard(lines: 3),
    };
  }

  Widget _card(BuildContext context, WidgetRef ref, List<Medicine> medicines) {
    final now = ref.watch(_clockProvider).valueOrNull ?? DateTime.now();
    final intakeLog = ref.watch(intakeLogProvider).valueOrNull ?? const [];
    final latestVital = ref.watch(latestVitalProvider);

    // An account with no medicines still has readings, and they belong on the
    // summary card just as much. Returning early here hid them completely.
    if (medicines.isEmpty) {
      return Card(
        child: Padding(
          padding: AppSpacing.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.medication_outlined,
                color: context.colors.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.md),
              Text('No medicines yet', style: context.texts.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Add your first medicine to get reminders',
                style: context.texts.bodyMedium
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => context.go(Routes.medicines),
                child: const Text('Add a medicine'),
              ),
              if (latestVital != null) _VitalsStrip(latest: latestVital),
            ],
          ),
        ),
      );
    }

    final taken = _takenKeys(intakeLog);
    final todaySlots = DoseSchedule.forDay(medicines, now);
    final overdue = [
      for (final slot in todaySlots)
        if (slot.isPast(now) && !taken.contains(slot.key)) slot,
    ];
    // A dose marked taken drops out of the list entirely: there is no undo, so
    // leaving it there is furniture, and leaving its button live would let the
    // same slot be posted twice.
    final upcomingToday = [
      for (final slot in todaySlots)
        if (!slot.isPast(now) && !taken.contains(slot.key)) slot,
    ];
    final doneToday =
        todaySlots.where((slot) => taken.contains(slot.key)).length;
    final next = DoseSchedule.next(medicines, now);
    final streak = _adherenceStreak(medicines, intakeLog, now);

    // Once today is spent, the useful list is tomorrow's — read-only, because
    // a dose that has not come round yet has nothing to mark.
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final tomorrowSlots = upcomingToday.isEmpty && overdue.isEmpty
        ? DoseSchedule.forDay(medicines, tomorrow)
        : const <DoseSlot>[];

    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _NextDoseHeadline(next: next, now: now)),
                if (streak >= 2) ...[
                  const SizedBox(width: AppSpacing.sm),
                  _StreakBadge(days: streak),
                ],
              ],
            ),

            if (overdue.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              _OverdueBlock(slots: overdue),
            ],

            if (todaySlots.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Today · $doneToday of ${todaySlots.length} taken',
                style: context.texts.labelSmall
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
              for (final slot in upcomingToday)
                _DoseRow(key: ValueKey(slot.key), slot: slot),
              if (upcomingToday.isEmpty && tomorrowSlots.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    'Nothing left today.',
                    style: context.texts.bodyMedium
                        ?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                ),
            ],

            if (tomorrowSlots.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Tomorrow',
                style: context.texts.labelSmall
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
              for (final slot in tomorrowSlots)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
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

            if (latestVital != null) _VitalsStrip(latest: latestVital),
          ],
        ),
      ),
    );
  }
}

/// The one line the whole screen exists for.
class _NextDoseHeadline extends StatelessWidget {
  const _NextDoseHeadline({required this.next, required this.now});

  final DoseSlot? next;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    if (next == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nothing scheduled', style: context.texts.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'None of your medicines has a dose time set, so there is no '
            'schedule to count down to.',
            style: context.texts.bodyMedium
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ],
      );
    }

    final slot = next!;
    final isTomorrow = slot.at.day != now.day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Next dose',
          style: context.texts.labelSmall
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(slot.medicine.name, style: context.texts.headlineSmall),
        const SizedBox(height: AppSpacing.xxs),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: MediTime.clockLabel(slot.time),
                style: TextStyle(
                  color: context.colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(
                text: '${isTomorrow ? ' tomorrow' : ''} · '
                    '${slot.medicine.dosage} · '
                    '${MediTime.until(slot.at.difference(now))}',
              ),
            ],
          ),
          style: context.texts.bodyMedium
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Consecutive perfect days. Colour *and* a glyph *and* the word — never
/// colour alone (DESIGN.md §2.5).
class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$days day adherence streak',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: context.status.okContainer,
          borderRadius: AppRadius.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_fire_department,
                  size: 14,
                  color: context.status.ok,
                ),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  'Streak',
                  style: context.texts.labelSmall
                      ?.copyWith(color: context.status.ok),
                ),
              ],
            ),
            Text(
              '$days d',
              style: context.numerals.numericMedium
                  .copyWith(color: context.status.ok),
            ),
          ],
        ),
      ),
    );
  }
}

/// Doses that came and went unmarked. The one place on this screen that is
/// allowed to use the alert colour.
class _OverdueBlock extends StatelessWidget {
  const _OverdueBlock({required this.slots});

  final List<DoseSlot> slots;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.errorContainer,
        borderRadius: AppRadius.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                size: 18,
                color: context.colors.onErrorContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  slots.length == 1
                      ? '1 dose overdue'
                      : '${slots.length} doses overdue',
                  style: context.texts.titleMedium
                      ?.copyWith(color: context.colors.onErrorContainer),
                ),
              ),
            ],
          ),
          for (final slot in slots)
            _DoseRow(
              key: ValueKey('overdue-${slot.key}'),
              slot: slot,
              overdue: true,
            ),
        ],
      ),
    );
  }
}

/// One-glance health status: label, latest value, status colour. Full detail
/// and trends live in the Vitals tab, one tap away; home only answers
/// "am I OK?".
class _VitalsStrip extends StatelessWidget {
  const _VitalsStrip({required this.latest});

  final VitalSign latest;

  @override
  Widget build(BuildContext context) {
    final readings = VitalRanges.readingsOf(latest);
    // `POST /api/vitals` accepts a body where every measurement is null, and
    // the web app's form will send one. Nothing to show, so nothing is drawn —
    // including the rule that would otherwise sit above an empty strip.
    if (readings.isEmpty) return const SizedBox.shrink();

    return Column(
      // Keyed so a test can assert the strip is absent without depending on an
      // icon or a heading that other cards also use.
      key: const ValueKey('home.vitals-strip'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),
        const Divider(height: 1),
        _strip(context, readings),
      ],
    );
  }

  Widget _strip(BuildContext context, List<VitalReading> readings) {
    return InkWell(
      onTap: () => context.go(Routes.vitals),
      borderRadius: AppRadius.sm,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
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
              ? reading.metric.shortLabel
              : '${reading.metric.shortLabel} · ${reading.status}',
          style: context.texts.labelSmall?.copyWith(
            color: reading.isNormal ? context.colors.onSurfaceVariant : tone,
          ),
        ),
      ],
    );
  }
}

/// Section 2 — five destinations, each one tap from here.
///
/// A scrolling row rather than a grid so the cards keep the size that makes
/// them comfortable targets, and so the fifth peeking at the edge says there
/// is more. Heights are intrinsic, so a doubled text scale grows the row
/// instead of overflowing it.
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickAction>[
      _QuickAction(
        label: 'Medicines',
        icon: Icons.medication_outlined,
        onTap: () => context.go(Routes.medicines),
      ),
      _QuickAction(
        label: 'Scan report',
        icon: Icons.document_scanner_outlined,
        onTap: () => showReportUploadSheet(context),
      ),
      _QuickAction(
        label: 'Vitals',
        icon: Icons.monitor_heart_outlined,
        onTap: () => context.go(Routes.vitals),
      ),
      _QuickAction(
        label: 'Appointments',
        icon: Icons.event_outlined,
        onTap: () => context.go(Routes.appointments),
      ),
      _QuickAction(
        label: 'Documents',
        icon: Icons.folder_outlined,
        onTap: () => context.go(Routes.documents),
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final action in actions) ...[
              SizedBox(
                width: 104,
                child: PressEffect(child: _QuickActionCard(action: action)),
              ),
              if (action != actions.last) const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: AppRadius.md,
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: context.colors.surfaceContainerHighest,
                  borderRadius: AppRadius.sm,
                ),
                child: Icon(
                  action.icon,
                  size: 20,
                  color: context.colors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(action.label, style: context.texts.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section 3 — the newest three reports, and the way to the rest.
class _RecentReports extends ConsumerWidget {
  const _RecentReports();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(reportsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Recent reports', style: context.texts.titleLarge),
            ),
            TextButton(
              onPressed: () => context.go(Routes.reports),
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        switch (reports) {
          AsyncError(:final error) => ErrorView(
              error: error,
              onRetry: () => ref.read(reportsProvider.notifier).refresh(),
            ),
          AsyncData(:final value) when value.isEmpty => Card(
              child: Padding(
                padding: AppSpacing.card,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      color: context.colors.onSurfaceVariant,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Scan or upload a lab report to see it here',
                      style: context.texts.bodyMedium
                          ?.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    OutlinedButton(
                      onPressed: () => showReportUploadSheet(context),
                      child: const Text('Scan a report'),
                    ),
                  ],
                ),
              ),
            ),
          AsyncData(:final value) => Card(
              child: Column(
                children: [
                  for (final report in value.take(3))
                    ListTile(
                      key: ValueKey(report.id),
                      leading: const Icon(Icons.description_outlined),
                      title: Text(report.typeLabel),
                      subtitle: Text(
                        report.dated == null
                            ? 'Undated'
                            : MediTime.date(report.dated!),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go(Routes.reports),
                    ),
                ],
              ),
            ),
          _ => const SkeletonCard(lines: 2),
        },
      ],
    );
  }
}

/// Section 4 — the page's only filled card, because handing your record to a
/// doctor is the one thing here done for somebody else.
///
/// The QR is an icon, not a live code: generating a real one mints a share
/// token with a PIN, which is a deliberate act, not something a home screen
/// should do on your behalf while it loads. DESIGN.md §1 rules out gradients,
/// so the accent fill does the drawing-attention.
class _ShareRecordCard extends StatelessWidget {
  const _ShareRecordCard();

  @override
  Widget build(BuildContext context) {
    return PressEffect(
      child: Card(
        color: context.colors.primaryContainer,
        child: InkWell(
          borderRadius: AppRadius.md,
          onTap: () => context.go(Routes.share),
          child: Padding(
            padding: AppSpacing.card,
            child: Row(
              children: [
                // Dark on white in both themes, as every QR in this app is: a
                // code inverted for dark mode is one a scanner cannot read.
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: const BoxDecoration(
                    color: AppPalette.white,
                    borderRadius: AppRadius.sm,
                  ),
                  child: const Icon(
                    Icons.qr_code_2,
                    size: 36,
                    color: AppPalette.ink900,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share your health record',
                        style: context.texts.titleMedium?.copyWith(
                          color: context.colors.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Show a QR code or send a read-only link to a doctor '
                        'or caretaker.',
                        style: context.texts.bodySmall?.copyWith(
                          color: context.colors.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  Icons.chevron_right,
                  color: context.colors.onPrimaryContainer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Section 5 — what has actually happened, newest first.
///
/// Only events the API timestamps: doses marked taken, and appointments
/// already attended. A report carries no upload time — `created_at` is not in
/// the response — and inventing one would be a lie, so reports stay in their
/// own section above. Hidden entirely when there is nothing.
class _RecentActivity extends ConsumerWidget {
  const _RecentActivity();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(_clockProvider).valueOrNull ?? DateTime.now();
    final medicines = ref.watch(medicinesProvider(null)).valueOrNull ?? const [];
    final intakeLog = ref.watch(intakeLogProvider).valueOrNull ?? const [];
    final appointments =
        ref.watch(appointmentsProvider).valueOrNull ?? const <Appointment>[];

    final names = {for (final medicine in medicines) medicine.id: medicine.name};

    final items = <_ActivityItem>[
      for (final intake in intakeLog)
        if (intake.status == 'taken' && intake.recorded != null)
          _ActivityItem(
            icon: Icons.check_circle_outline,
            title: 'Took ${names[intake.medicineId] ?? 'a medicine'}',
            detail: '${MediTime.clockLabel(intake.scheduledTime)} dose',
            at: intake.recorded!,
            route: Routes.medicines,
          ),
      for (final appointment in appointments)
        if (appointment.state != AppointmentStatus.cancelled &&
            appointment.startsAt != null &&
            appointment.startsAt!.isBefore(now))
          _ActivityItem(
            icon: Icons.event_available_outlined,
            title: appointment.title,
            detail: appointment.who.isEmpty ? 'Appointment' : appointment.who,
            at: appointment.startsAt!,
            route: Routes.appointments,
          ),
    ]..sort((a, b) => b.at.compareTo(a.at));

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent activity', style: context.texts.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Column(
            children: [
              for (final item in items.take(5))
                ListTile(
                  key: ValueKey('${item.route}-${item.title}-${item.at}'),
                  leading: Icon(item.icon, color: context.colors.primary),
                  title: Text(item.title),
                  subtitle: Text(item.detail),
                  trailing: Text(
                    MediTime.ago(item.at, now: now),
                    style: context.texts.bodySmall
                        ?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                  onTap: () => context.go(item.route),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActivityItem {
  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.detail,
    required this.at,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String detail;
  final DateTime at;
  final String route;
}

/// Every dose slot already marked taken, keyed the way [DoseSlot.key] keys.
Set<String> _takenKeys(Iterable<MedicineIntake> intakeLog) => {
      for (final intake in intakeLog)
        if (intake.status == 'taken' && intake.recorded != null)
          '${intake.medicineId}-${intake.scheduledTime}'
              '-${MediTime.dateOnly(intake.recorded!)}',
    };

/// Consecutive days, ending yesterday, where every scheduled dose was marked
/// taken. Days with no schedule are neutral (neither break nor extend).
/// Today is deliberately excluded: an unfinished day says nothing yet.
int _adherenceStreak(
  List<Medicine> medicines,
  Iterable<MedicineIntake> intakeLog,
  DateTime now,
) {
  final taken = _takenKeys(intakeLog);

  var streak = 0;
  for (var back = 1; back <= 30; back++) {
    final day = DateTime(now.year, now.month, now.day - back);
    final slots = DoseSchedule.forDay(medicines, day);
    if (slots.isEmpty) continue; // a day off neither breaks nor extends
    final allTaken = slots.every(
      (slot) => taken.contains(slot.key),
    );
    if (!allTaken) return streak;
    streak++;
  }
  return streak;
}

/// One dose, with the one action worth having on a dashboard: mark it taken.
///
/// `POST /{id}/intake` is self-only and has no undo, so the row commits
/// straight away and reports failure rather than pretending. Snooze and skip
/// belong with the reminder that fires.
class _DoseRow extends ConsumerStatefulWidget {
  const _DoseRow({super.key, required this.slot, this.overdue = false});

  final DoseSlot slot;

  /// Drawn on the alert container rather than the card, so its text and its
  /// button take the "on error container" colour instead of the card's.
  final bool overdue;

  @override
  ConsumerState<_DoseRow> createState() => _DoseRowState();
}

class _DoseRowState extends ConsumerState<_DoseRow> {
  bool _saving = false;

  /// Local mark from pressing "Taken" this session, so the row settles before
  /// the invalidated intake log comes back.
  bool _localMarked = false;

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
    final onSurface = widget.overdue
        ? context.colors.onErrorContainer
        : context.colors.onSurface;
    final onVariant = widget.overdue
        ? context.colors.onErrorContainer
        : context.colors.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            child: Text(
              MediTime.clockLabel(widget.slot.time),
              style: context.numerals.numericMedium.copyWith(color: onVariant),
            ),
          ),
          Expanded(
            child: Text(
              widget.slot.medicine.name,
              style: context.texts.bodyMedium?.copyWith(
                color: _localMarked ? onVariant : onSurface,
                decoration: _localMarked ? TextDecoration.lineThrough : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_localMarked)
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
              style: widget.overdue
                  ? TextButton.styleFrom(
                      foregroundColor: context.colors.onErrorContainer,
                    )
                  : null,
              child: Semantics(
                label: 'Mark ${widget.slot.medicine.name} at '
                    '${MediTime.clockLabel(widget.slot.time)} as taken',
                excludeSemantics: true,
                child: const Text('Taken'),
              ),
            ),
        ],
      ),
    );
  }
}
