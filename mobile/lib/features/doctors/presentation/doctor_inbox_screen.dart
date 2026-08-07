/// The doctor's inbox: what patients have booked, and the three answers a
/// doctor can give.
///
/// Every action here goes through `PATCH /{id}/status/by-doctor`. The plain
/// `/status` route authorises against the *patient* who booked, so a doctor
/// using it gets a 404 on everything — which is what the web app did, and why
/// Accept and Reject have never worked in production (`FEATURE_MAP.md` §7.1).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/time/medi_time.dart';
import '../../../core/widgets/card_header.dart';
import '../../../core/widgets/range_bar.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/states.dart';
import '../../appointments/domain/appointment.dart';
import '../../appointments/presentation/appointments_controller.dart';

class DoctorInboxScreen extends ConsumerWidget {
  const DoctorInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(doctorInboxProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Appointments')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(doctorInboxProvider.notifier).refresh(),
        child: switch (inbox) {
          AsyncData(:final value) when value.isEmpty => const _Empty(),
          AsyncData(:final value) => _Inbox(appointments: value),
          // A 404 here is not a broken screen: it is a doctor account with no
          // registration on file. Say which, and point at the fix.
          AsyncError(:final error)
              when ApiException.from(error).kind == ApiErrorKind.notFound =>
            const _NoProfile(),
          AsyncError(:final error) => ListView(
              padding: AppSpacing.screen,
              children: [
                ErrorView(
                  error: error,
                  onRetry: () =>
                      ref.read(doctorInboxProvider.notifier).refresh(),
                ),
              ],
            ),
          _ => ListView(
              padding: AppSpacing.screen,
              children: const [
                SkeletonCard(lines: 3),
                SizedBox(height: AppSpacing.md),
                SkeletonCard(lines: 3),
              ],
            ),
        },
      ),
    );
  }
}

class _Inbox extends StatelessWidget {
  const _Inbox({required this.appointments});

  final List<Appointment> appointments;

  @override
  Widget build(BuildContext context) {
    // Requests waiting on an answer come first, whenever they are for: an
    // inbox sorted purely by date buries a decision behind a month of
    // already-confirmed clinics.
    final waiting = [
      for (final a in appointments)
        if (a.state == AppointmentStatus.pending) a,
    ];
    final rest = [
      for (final a in appointments)
        if (a.state != AppointmentStatus.pending) a,
    ];

    return ListView(
      padding: AppSpacing.screen,
      children: [
        if (waiting.isNotEmpty) ...[
          SectionHeading(label: 'Waiting on you', count: waiting.length),
          for (final appointment in waiting)
            Padding(
              key: ValueKey(appointment.id),
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _InboxCard(appointment: appointment),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (rest.isNotEmpty) ...[
          SectionHeading(label: 'Everything else', count: rest.length),
          for (final appointment in rest)
            Padding(
              key: ValueKey(appointment.id),
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _InboxCard(appointment: appointment),
            ),
        ],
      ],
    );
  }
}

class _InboxCard extends ConsumerStatefulWidget {
  const _InboxCard({required this.appointment});

  final Appointment appointment;

  @override
  ConsumerState<_InboxCard> createState() => _InboxCardState();
}

class _InboxCardState extends ConsumerState<_InboxCard> {
  bool _busy = false;

  Future<void> _set(AppointmentStatus status, String done) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(doctorInboxProvider.notifier)
          .setStatus(widget.appointment.id, status);
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorText.of(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;
    final start = appointment.startsAt;
    final state = appointment.state;

    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CardHeader(
              title: appointment.title,
              trailing: StatusChip(
                label: appointment.statusLabel,
                status: switch (state) {
                  AppointmentStatus.confirmed ||
                  AppointmentStatus.completed =>
                    RangeStatus.ok,
                  AppointmentStatus.pending => RangeStatus.caution,
                  AppointmentStatus.cancelled || null => RangeStatus.alert,
                },
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              start == null
                  ? 'Date unreadable'
                  : '${MediTime.dateTime(start)} · ${appointment.durationMinutes} min',
              style: context.numerals.numericMedium,
            ),
            if (appointment.reason?.trim().isNotEmpty ?? false) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(appointment.reason!.trim(), style: context.texts.bodyMedium),
            ],
            if (_actionsFor(state) case final actions when actions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final (label, status, done) in actions)
                    if (status == AppointmentStatus.cancelled)
                      TextButton(
                        onPressed: _busy ? null : () => _set(status, done),
                        child: Text(label),
                      )
                    else
                      FilledButton(
                        onPressed: _busy ? null : () => _set(status, done),
                        child: Text(label),
                      ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// What a doctor can do next, by where the appointment already is. A
  /// cancelled or completed booking is finished — offering "Accept" on it
  /// would be offering to undo history.
  static List<(String, AppointmentStatus, String)> _actionsFor(
    AppointmentStatus? state,
  ) =>
      switch (state) {
        AppointmentStatus.pending => const [
            ('Accept', AppointmentStatus.confirmed, 'Accepted'),
            ('Decline', AppointmentStatus.cancelled, 'Declined'),
          ],
        AppointmentStatus.confirmed => const [
            ('Mark seen', AppointmentStatus.completed, 'Marked as seen'),
            ('Cancel', AppointmentStatus.cancelled, 'Cancelled'),
          ],
        _ => const [],
      };
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
        const EmptyState(
          icon: Icons.inbox_outlined,
          title: 'Nothing booked yet',
          message: 'Patients can only book against hours you have posted. Add '
              'your weekly availability and this fills up.',
        ),
      ],
    );
  }
}

class _NoProfile extends StatelessWidget {
  const _NoProfile();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
        const EmptyState(
          icon: Icons.badge_outlined,
          title: 'Finish your registration first',
          message: 'Your account is a doctor account, but there is no NMC '
              'registration on file yet. Add it under Account, then post your '
              'hours.',
        ),
      ],
    );
  }
}
