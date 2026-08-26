/// Book an appointment, or move one. The same sheet does both.
///
/// Two paths, because the API has two. Picking a **listed doctor** reads their
/// diary and books a real slot, and the server confirms it on the spot. Naming
/// somebody who is not in the directory books a **reminder**: it stays
/// `PENDING` forever, because there is nobody on the other end to accept it.
/// The sheet says which one is happening rather than leaving the status to be
/// discovered afterwards.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/time/medi_time.dart';
import '../../../core/widgets/form_sheet.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/states.dart';
import '../../doctors/domain/doctor.dart';
import '../../doctors/presentation/doctor_controllers.dart';
import '../domain/appointment.dart';
import 'appointments_controller.dart';

/// Opens the sheet. Returns the saved appointment, or null if it was dismissed.
Future<Appointment?> showBookingSheet(
  BuildContext context, {
  Appointment? existing,
}) {
  return showFormSheet<Appointment>(
    context: context,
    builder: (_) => BookAppointmentSheet(existing: existing),
  );
}

/// Which of the two paths the sheet is on.
enum BookingMode { listedDoctor, elsewhere }

class BookAppointmentSheet extends ConsumerStatefulWidget {
  const BookAppointmentSheet({super.key, this.existing});

  final Appointment? existing;

  @override
  ConsumerState<BookAppointmentSheet> createState() =>
      _BookAppointmentSheetState();
}

class _BookAppointmentSheetState extends ConsumerState<BookAppointmentSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _doctorName;
  late final TextEditingController _hospital;
  late final TextEditingController _reason;

  late BookingMode _mode;
  String? _doctorId;
  late DateTime _day;
  DateTime? _startsAt;
  late int _duration;
  late List<int> _durations;

  /// A time the user has picked that the server will refuse. Kept as state
  /// rather than derived in `build`, because it is the *picker* that knows —
  /// and the answer must survive until the next pick.
  bool _timeInPast = false;

  bool _busy = false;
  Object? _error;

  bool get _isEdit => widget.existing != null;

  /// 15 minutes to an hour. The server takes any integer, but a slot list has
  /// to divide into a posted window and these are the four that do.
  static const _defaultDurations = [15, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(text: existing?.title ?? '');
    _doctorName = TextEditingController(text: existing?.doctorName ?? '');
    _hospital = TextEditingController(text: existing?.hospital ?? '');
    _reason = TextEditingController(text: existing?.reason ?? '');
    _doctorId = existing?.doctorId;
    // A new booking starts on the listed-doctor path: it is the one the API
    // was built for and the only one that confirms anything. Rescheduling
    // starts on whichever path the appointment was made on — a free-text
    // booking has no `doctor_id` to reschedule against.
    _mode = existing == null || existing.doctorId != null
        ? BookingMode.listedDoctor
        : BookingMode.elsewhere;
    _duration = existing?.durationMinutes ?? 30;
    // An appointment booked elsewhere with an odd length keeps it rather than
    // being silently rounded to the nearest chip.
    _durations = _defaultDurations.contains(_duration)
        ? _defaultDurations
        : ([..._defaultDurations, _duration]..sort());

    final start = existing?.startsAt;
    // Rescheduling starts from the appointment's own day; a new booking starts
    // from tomorrow, because today's remaining slots are usually gone and an
    // empty first screen reads as "this doctor has no hours".
    final seed = start ?? DateTime.now().add(const Duration(days: 1));
    _day = DateTime(seed.year, seed.month, seed.day);
    // A time already chosen is only kept when it can still be honoured.
    _startsAt = (start?.isAfter(DateTime.now()) ?? false) ? start : null;
  }

  @override
  void dispose() {
    _title.dispose();
    _doctorName.dispose();
    _hospital.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _setMode(BookingMode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      // The two paths pick a time in different ways, so a time chosen under one
      // of them cannot survive the switch.
      _startsAt = null;
      _timeInPast = false;
      _error = null;
    });
  }

  Future<void> _pickDay() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Day of the appointment',
    );
    if (picked == null) return;
    setState(() {
      _day = DateTime(picked.year, picked.month, picked.day);
      _startsAt = null;
      _timeInPast = false;
    });
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt ?? _day.add(_nineAm)),
      helpText: 'Time of the appointment',
    );
    if (picked == null) return;
    final at = DateTime(
      _day.year,
      _day.month,
      _day.day,
      picked.hour,
      picked.minute,
    );
    setState(() {
      _startsAt = at;
      // The server refuses a past appointment with a validation error. Saying
      // so here, next to the field, beats a round trip that comes back with
      // "Appointment date must be in the future" — and beats a Save button
      // that looks available and then is not.
      _timeInPast = !at.isAfter(now);
    });
  }

  static const _nineAm = Duration(hours: 9);

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final startsAt = _startsAt;
    if (startsAt == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final controller = ref.read(appointmentsProvider.notifier);
    final onListedDoctor = _mode == BookingMode.listedDoctor;
    // A listed booking carries the doctor's own name, so the list does not have
    // to hold the directory in memory to render a row.
    final doctorName = onListedDoctor
        ? _selectedDoctor()?.name
        : _trimmed(_doctorName);

    try {
      final saved = _isEdit
          ? await controller.reschedule(
              widget.existing!.id,
              title: _title.text.trim(),
              startsAt: startsAt,
              durationMinutes: _duration,
              doctorId: onListedDoctor ? _doctorId : null,
              doctorName: doctorName,
              hospital: onListedDoctor ? null : _trimmed(_hospital),
              reason: _trimmed(_reason),
            )
          : await controller.book(
              title: _title.text.trim(),
              startsAt: startsAt,
              durationMinutes: _duration,
              doctorId: onListedDoctor ? _doctorId : null,
              doctorName: doctorName,
              hospital: onListedDoctor ? null : _trimmed(_hospital),
              reason: _trimmed(_reason),
            );
      if (mounted) Navigator.of(context).pop(saved);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error;
        });
      }
    }
  }

  Doctor? _selectedDoctor() {
    final doctors = ref.read(verifiedDoctorsProvider).valueOrNull;
    if (doctors == null) return null;
    for (final doctor in doctors) {
      if (doctor.id == _doctorId) return doctor;
    }
    return null;
  }

  static String? _trimmed(TextEditingController field) {
    final value = field.text.trim();
    return value.isEmpty ? null : value;
  }

  bool get _canSave =>
      _startsAt != null &&
      !_timeInPast &&
      _title.text.trim().isNotEmpty &&
      (_mode == BookingMode.elsewhere || _doctorId != null);

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: _isEdit ? 'Move this appointment' : 'Book an appointment',
      subtitle: _isEdit
          ? 'The whole booking is rewritten, so check every field before saving.'
          : null,
      submitLabel: _isEdit ? 'Save changes' : 'Book it',
      busyLabel: 'Booking…',
      busy: _busy,
      error: _error,
      onSubmit: _canSave ? _save : null,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What is it for?',
                hintText: 'Follow-up, blood test, review',
              ),
              onChanged: (_) => setState(() {}),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Give it a name you will recognise later.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            SegmentedButton<BookingMode>(
              segments: const [
                ButtonSegment(
                  value: BookingMode.listedDoctor,
                  label: Text('A listed doctor'),
                ),
                ButtonSegment(
                  value: BookingMode.elsewhere,
                  label: Text('Somewhere else'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) => _setMode(selection.first),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_mode == BookingMode.listedDoctor)
              _ListedDoctorFields(
                doctorId: _doctorId,
                day: _day,
                duration: _duration,
                startsAt: _startsAt,
                durations: _durations,
                onDoctorChanged: (id) => setState(() {
                  _doctorId = id;
                  _startsAt = null;
                }),
                onDurationChanged: (minutes) => setState(() {
                  _duration = minutes;
                  _startsAt = null;
                }),
                onPickDay: _pickDay,
                onSlotChosen: (at) => setState(() => _startsAt = at),
                onNoDoctors: () => _setMode(BookingMode.elsewhere),
              )
            else
              _ElsewhereFields(
                doctorName: _doctorName,
                hospital: _hospital,
                day: _day,
                startsAt: _startsAt,
                duration: _duration,
                durations: _durations,
                onPickDay: _pickDay,
                onPickTime: _pickTime,
                onDurationChanged: (minutes) =>
                    setState(() => _duration = minutes),
              ),
            if (_timeInPast) ...[
              const SizedBox(height: AppSpacing.md),
              const MessageBanner(
                message: 'That time has already passed. Pick a later one.',
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _reason,
              textCapitalization: TextCapitalization.sentences,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Anything the clinic should know (optional)',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListedDoctorFields extends ConsumerWidget {
  const _ListedDoctorFields({
    required this.doctorId,
    required this.day,
    required this.duration,
    required this.startsAt,
    required this.durations,
    required this.onDoctorChanged,
    required this.onDurationChanged,
    required this.onPickDay,
    required this.onSlotChosen,
    required this.onNoDoctors,
  });

  final String? doctorId;
  final DateTime day;
  final int duration;
  final DateTime? startsAt;
  final List<int> durations;
  final ValueChanged<String?> onDoctorChanged;
  final ValueChanged<int> onDurationChanged;
  final VoidCallback onPickDay;
  final ValueChanged<DateTime> onSlotChosen;
  final VoidCallback onNoDoctors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctors = ref.watch(verifiedDoctorsProvider);

    return switch (doctors) {
      AsyncData(:final value) when value.isEmpty => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MessageBanner(
              tone: BannerTone.notice,
              message: 'No doctors are listed on Ayuvo yet. A doctor '
                  'appears here once an administrator has verified them.',
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: onNoDoctors,
              child: const Text('Book somewhere else instead'),
            ),
          ],
        ),
      AsyncData(:final value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: doctorId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Doctor'),
              items: [
                for (final doctor in value)
                  DropdownMenuItem(
                    value: doctor.id,
                    child: Text(
                      doctor.credentials.isEmpty
                          ? doctor.name
                          : '${doctor.name} — ${doctor.credentials}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: onDoctorChanged,
            ),
            const SizedBox(height: AppSpacing.md),
            _DurationChips(
              value: duration,
              options: durations,
              onChanged: onDurationChanged,
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: onPickDay,
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Align(
                alignment: Alignment.centerLeft,
                child: Text(MediTime.date(day)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (doctorId == null)
              Text(
                'Pick a doctor to see when they are free.',
                style: context.texts.bodySmall,
              )
            else
              _Slots(
                doctorId: doctorId!,
                day: day,
                duration: duration,
                selected: startsAt,
                onChosen: onSlotChosen,
              ),
          ],
        ),
      AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(verifiedDoctorsProvider),
        ),
      _ => const SkeletonCard(lines: 2),
    };
  }
}

class _Slots extends ConsumerWidget {
  const _Slots({
    required this.doctorId,
    required this.day,
    required this.duration,
    required this.selected,
    required this.onChosen,
  });

  final String doctorId;
  final DateTime day;
  final int duration;
  final DateTime? selected;
  final ValueChanged<DateTime> onChosen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = (doctorId: doctorId, day: day, durationMinutes: duration);
    final slots = ref.watch(availableSlotsProvider(query));

    return switch (slots) {
      AsyncData(:final value) => _SlotGrid(
          slots: bookableSlots(value),
          generated: value.length,
          day: day,
          doctorId: doctorId,
          selected: selected,
          onChosen: onChosen,
        ),
      AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(availableSlotsProvider(query)),
        ),
      _ => const Skeleton(width: double.infinity, height: 40),
    };
  }
}

class _SlotGrid extends ConsumerWidget {
  const _SlotGrid({
    required this.slots,
    required this.generated,
    required this.day,
    required this.doctorId,
    required this.selected,
    required this.onChosen,
  });

  /// The slots that can still be booked.
  final List<AppointmentSlot> slots;

  /// How many the server produced before the past-time filter. The difference
  /// between the two numbers is what separates "come back tomorrow" from "this
  /// doctor does not work on Sundays" — one is fixed by picking another day,
  /// the other by picking another doctor, and a single "no slots" tells the
  /// patient neither.
  final int generated;

  final DateTime day;
  final String doctorId;
  final DateTime? selected;
  final ValueChanged<DateTime> onChosen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (slots.isEmpty) {
      final weekday = Weekday.of(day);
      final postsHours = ref
              .watch(doctorAvailabilityProvider(doctorId))
              .valueOrNull
              ?.any((window) => window.day == weekday && window.isAvailable) ??
          // Their posted hours have not loaded, so say the safe thing: what is
          // certain either way is that there is nothing here today.
          true;

      return MessageBanner(
        tone: BannerTone.notice,
        message: switch ((generated, postsHours)) {
          (> 0, _) => "Today's remaining slots have already gone. Try "
              'tomorrow.',
          (_, false) =>
            'This doctor posts no hours on a ${weekday.label}. Try another '
                'day.',
          _ => 'Every slot on ${MediTime.date(day)} is taken. Try another day.',
        },
      );
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final slot in slots)
          if (slot.start case final start?)
            ChoiceChip(
              label: Text(MediTime.time(start)),
              selected: selected == start,
              onSelected: (_) => onChosen(start),
            ),
      ],
    );
  }
}

class _ElsewhereFields extends StatelessWidget {
  const _ElsewhereFields({
    required this.doctorName,
    required this.hospital,
    required this.day,
    required this.startsAt,
    required this.duration,
    required this.durations,
    required this.onPickDay,
    required this.onPickTime,
    required this.onDurationChanged,
  });

  final TextEditingController doctorName;
  final TextEditingController hospital;
  final DateTime day;
  final DateTime? startsAt;
  final int duration;
  final List<int> durations;
  final VoidCallback onPickDay;
  final VoidCallback onPickTime;
  final ValueChanged<int> onDurationChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MessageBanner(
          tone: BannerTone.notice,
          message: 'This saves a reminder for you. Nobody at the clinic is '
              'told, so book with them the way you normally would.',
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: doctorName,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Doctor (optional)'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: hospital,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Hospital or clinic (optional)',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPickDay,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(MediTime.date(day), overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPickTime,
                icon: const Icon(Icons.schedule, size: 18),
                label: Text(
                  startsAt == null ? 'Pick a time' : MediTime.time(startsAt!),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _DurationChips(
          value: duration,
          options: durations,
          onChanged: onDurationChanged,
        ),
      ],
    );
  }
}

class _DurationChips extends StatelessWidget {
  const _DurationChips({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final int value;
  final List<int> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How long', style: context.texts.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final minutes in options)
              ChoiceChip(
                label: Text('$minutes min'),
                selected: minutes == value,
                onSelected: (_) => onChanged(minutes),
              ),
          ],
        ),
      ],
    );
  }
}
