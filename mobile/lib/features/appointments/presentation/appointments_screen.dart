/// What is coming up, and what already happened.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/time/medi_time.dart';
import '../../../core/widgets/card_header.dart';
import '../../../core/widgets/range_bar.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/states.dart';
import '../domain/appointment.dart';
import '../domain/calendar_invite.dart';
import 'appointments_controller.dart';
import 'book_appointment_sheet.dart';

class AppointmentsScreen extends ConsumerWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointments = ref.watch(appointmentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Appointments')),
      floatingActionButton:
          appointments.hasValue && appointments.value!.isNotEmpty
              ? FloatingActionButton.extended(
                  onPressed: () => showBookingSheet(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Book'),
                )
              : null,
      body: RefreshIndicator(
        onRefresh: () => ref.read(appointmentsProvider.notifier).refresh(),
        child: switch (appointments) {
          AsyncData(:final value) when value.isEmpty =>
            _Empty(onBook: () => showBookingSheet(context)),
          AsyncData(:final value) => _List(split: splitAppointments(value)),
          AsyncError(:final error) => ListView(
              padding: AppSpacing.screen,
              children: [
                ErrorView(
                  error: error,
                  onRetry: () =>
                      ref.read(appointmentsProvider.notifier).refresh(),
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

class _List extends StatelessWidget {
  const _List({required this.split});

  final SplitAppointments split;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.screen,
      children: [
        if (split.upcoming.isNotEmpty) ...[
          SectionHeading(
            label: 'Coming up',
            count: split.upcoming.length,
          ),
          for (final appointment in split.upcoming)
            Padding(
              key: ValueKey(appointment.id),
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _AppointmentCard(appointment: appointment),
            ),
        ],
        if (split.past.isNotEmpty) ...[
          if (split.upcoming.isNotEmpty) const SizedBox(height: AppSpacing.lg),
          SectionHeading(label: 'Earlier', count: split.past.length),
          for (final appointment in split.past)
            Padding(
              key: ValueKey(appointment.id),
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _AppointmentCard(appointment: appointment),
            ),
        ],
        // Clear of the FAB.
        const SizedBox(height: 88),
      ],
    );
  }
}

class _AppointmentCard extends ConsumerWidget {
  const _AppointmentCard({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final start = appointment.startsAt;
    final closed = appointment.isClosed;

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
                status: _statusTone(appointment),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              start == null
                  ? 'Date unreadable'
                  : '${MediTime.dateTime(start)} · ${appointment.durationMinutes} min',
              style: context.numerals.numericMedium,
            ),
            if (appointment.who.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                appointment.who,
                style: context.texts.bodyMedium
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ],
            if (appointment.reason?.trim().isNotEmpty ?? false) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(appointment.reason!.trim(), style: context.texts.bodyMedium),
            ],
            if (appointment.state == AppointmentStatus.pending &&
                appointment.doctorId == null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Saved as your own reminder — the clinic has not been told.',
                style: context.texts.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                if (start != null)
                  TextButton.icon(
                    onPressed: () => _addToCalendar(context),
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: const Text('Add to calendar'),
                  ),
                if (!closed) ...[
                  TextButton.icon(
                    onPressed: () =>
                        showBookingSheet(context, existing: appointment),
                    icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                    label: const Text('Move'),
                  ),
                  TextButton(
                    onPressed: () => _confirmCancel(context, ref),
                    child: const Text('Cancel'),
                  ),
                ] else
                  TextButton.icon(
                    onPressed: () => _confirmDelete(context, ref),
                    icon: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: context.colors.error,
                    ),
                    label: Text(
                      'Remove',
                      style: TextStyle(color: context.colors.error),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Pending is amber because it is genuinely unsettled: nobody has agreed to
  /// it yet. Completed is green rather than neutral — it is the only status
  /// that means the visit actually happened.
  static RangeStatus _statusTone(Appointment appointment) =>
      switch (appointment.state) {
        AppointmentStatus.confirmed ||
        AppointmentStatus.completed =>
          RangeStatus.ok,
        AppointmentStatus.pending => RangeStatus.caution,
        AppointmentStatus.cancelled || null => RangeStatus.alert,
      };

  Future<void> _addToCalendar(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final box = context.findRenderObject() as RenderBox?;
    try {
      final ics = CalendarInvite.of(appointment);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(ics)),
              // The extension is on the name, not the path: this file is built
              // in memory and never written to disk.
              name: CalendarInvite.fileName(appointment),
              mimeType: 'text/calendar',
            ),
          ],
          subject: appointment.title,
          sharePositionOrigin:
              box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't build a calendar entry.")),
      );
    }
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel ${appointment.title}?'),
        content: Text(
          appointment.doctorId == null
              ? 'The reminder stays in your record, marked cancelled. Tell the '
                  'clinic yourself — MediStore has not contacted them.'
              : 'The doctor sees the cancellation and the slot goes back into '
                  'their diary.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel it'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(appointmentsProvider.notifier).cancel(appointment.id);
      messenger.showSnackBar(
        const SnackBar(content: Text('Appointment cancelled')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorText.of(error))));
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove it from your record?'),
        content: const Text(
          'This deletes the appointment outright. Your history will no longer '
          'show that it happened.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(appointmentsProvider.notifier).remove(appointment.id);
      messenger.showSnackBar(
        const SnackBar(content: Text('Appointment removed')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorText.of(error))));
    }
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onBook});

  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
        EmptyState(
          icon: Icons.event_outlined,
          title: 'No appointments',
          message: 'Book with a doctor listed on MediStore and the slot is '
              'confirmed straight away. Anywhere else, keep the reminder here '
              'so it is beside the rest of your record.',
          actionLabel: 'Book an appointment',
          onAction: onBook,
        ),
      ],
    );
  }
}
