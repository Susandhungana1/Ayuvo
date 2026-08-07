/// The hours a doctor posts, one card per weekday.
///
/// This is what `available-slots` runs on: a patient can only book inside a
/// window that is switched on, and the slot spacing comes from
/// `slot_duration_minutes` — which the web editor never exposed, so every
/// window created there sits on the 30-minute default whether that suits the
/// practice or not. It is a field here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/time/medi_time.dart';
import '../../../core/widgets/form_sheet.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/states.dart';
import '../domain/doctor.dart';
import 'doctor_controllers.dart';

class AvailabilityScreen extends ConsumerWidget {
  const AvailabilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windows = ref.watch(myAvailabilityProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Availability')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(myAvailabilityProvider.notifier).refresh(),
        child: switch (windows) {
          AsyncData(:final value) => _Week(byDay: byWeekday(value)),
          AsyncError(:final error)
              when ApiException.from(error).kind == ApiErrorKind.notFound =>
            const _NoProfile(),
          AsyncError(:final error) => ListView(
              padding: AppSpacing.screen,
              children: [
                ErrorView(
                  error: error,
                  onRetry: () =>
                      ref.read(myAvailabilityProvider.notifier).refresh(),
                ),
              ],
            ),
          _ => ListView(
              padding: AppSpacing.screen,
              children: const [
                SkeletonCard(lines: 2),
                SizedBox(height: AppSpacing.md),
                SkeletonCard(lines: 2),
              ],
            ),
        },
      ),
    );
  }
}

class _Week extends StatelessWidget {
  const _Week({required this.byDay});

  final Map<Weekday, List<AvailabilityWindow>> byDay;

  @override
  Widget build(BuildContext context) {
    final total = byDay.values.fold(0, (sum, list) => sum + list.length);

    return ListView(
      padding: AppSpacing.screen,
      children: [
        if (total == 0) ...[
          const MessageBanner(
            tone: BannerTone.notice,
            message: 'You have posted no hours, so nobody can book you. Add a '
                'window to any day below.',
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        for (final day in Weekday.values)
          Padding(
            key: ValueKey(day),
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _DayCard(day: day, windows: byDay[day] ?? const []),
          ),
      ],
    );
  }
}

class _DayCard extends ConsumerWidget {
  const _DayCard({required this.day, required this.windows});

  final Weekday day;
  final List<AvailabilityWindow> windows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(day.label, style: context.texts.titleMedium),
            if (windows.isEmpty)
              Text(
                'Not working',
                style: context.texts.bodyMedium
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              )
            else
              for (final window in windows)
                _WindowRow(key: ValueKey(window.id), day: day, window: window),
            // Below the windows rather than beside the day name: at large text
            // sizes a button on the heading line has nowhere to go, and reading
            // "Monday, 9–5, add hours" top to bottom says what the button adds
            // to better than a button floating off the title does.
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => showWindowSheet(context, day: day),
                icon: const Icon(Icons.add, size: 18),
                label: Text(windows.isEmpty ? 'Add hours' : 'Add more hours'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowRow extends ConsumerWidget {
  const _WindowRow({
    super.key,
    required this.day,
    required this.window,
  });

  /// Passed down rather than read off [window]: the card already grouped by it,
  /// and a window whose weekday did not parse never reaches a card at all.
  final Weekday day;
  final AvailabilityWindow window;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final off = !window.isAvailable;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${MediTime.clockLabel(window.startTime)} – '
                  '${MediTime.clockLabel(window.endTime)}',
                  style: context.numerals.numericMedium.copyWith(
                    color: off ? context.colors.onSurfaceVariant : null,
                    decoration: off ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  off
                      ? 'Paused — nobody can book this'
                      : '${window.slotDurationMinutes}-minute slots',
                  style: context.texts.bodySmall,
                ),
              ],
            ),
          ),
          Switch(
            value: window.isAvailable,
            onChanged: (value) => _toggle(context, ref, value),
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () =>
                showWindowSheet(context, day: day, existing: window),
          ),
          IconButton(
            tooltip: 'Remove',
            icon: Icon(
              Icons.delete_outline,
              size: 20,
              color: context.colors.error,
            ),
            onPressed: () => _confirmRemove(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(myAvailabilityProvider.notifier)
          .edit(window.id, isAvailable: value);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorText.of(error))));
    }
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove these hours?'),
        // The server does not look back at bookings when a window goes, so say
        // so — a doctor deleting a Tuesday should not assume Tuesday is clear.
        content: const Text(
          'Appointments already booked inside them stay in your inbox. Only '
          'new bookings are affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep them'),
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
      await ref.read(myAvailabilityProvider.notifier).remove(window.id);
      messenger.showSnackBar(const SnackBar(content: Text('Hours removed')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorText.of(error))));
    }
  }
}

Future<void> showWindowSheet(
  BuildContext context, {
  required Weekday day,
  AvailabilityWindow? existing,
}) {
  return showFormSheet<void>(
    context: context,
    builder: (_) => _WindowSheet(day: day, existing: existing),
  );
}

class _WindowSheet extends ConsumerStatefulWidget {
  const _WindowSheet({required this.day, this.existing});

  final Weekday day;
  final AvailabilityWindow? existing;

  @override
  ConsumerState<_WindowSheet> createState() => _WindowSheetState();
}

class _WindowSheetState extends ConsumerState<_WindowSheet> {
  late TimeOfDay _start;
  late TimeOfDay _end;
  late int _slot;

  bool _busy = false;
  Object? _error;

  bool get _isEdit => widget.existing != null;

  /// The four spacings a consultation realistically takes.
  static const _slotOptions = [10, 15, 20, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _start = _parse(existing?.startTime) ?? const TimeOfDay(hour: 9, minute: 0);
    _end = _parse(existing?.endTime) ?? const TimeOfDay(hour: 17, minute: 0);
    _slot = existing?.slotDurationMinutes ?? 30;
  }

  static TimeOfDay? _parse(String? clock) {
    if (clock == null) return null;
    final parts = clock.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  int get _minutes =>
      (_end.hour * 60 + _end.minute) - (_start.hour * 60 + _start.minute);

  /// A window shorter than one slot generates nothing, which looks to the
  /// patient exactly like a doctor who does not work that day.
  bool get _tooShort => _minutes < _slot;

  Future<void> _pick({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
      helpText: isStart ? 'Start of the window' : 'End of the window',
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final controller = ref.read(myAvailabilityProvider.notifier);
    final start = MediTime.clock(_start.hour, _start.minute);
    final end = MediTime.clock(_end.hour, _end.minute);

    try {
      if (_isEdit) {
        await controller.edit(
          widget.existing!.id,
          startTime: start,
          endTime: end,
          slotDurationMinutes: _slot,
        );
      } else {
        await controller.add(
          day: widget.day,
          startTime: start,
          endTime: end,
          slotDurationMinutes: _slot,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: _isEdit
          ? 'Edit ${widget.day.label} hours'
          : '${widget.day.label} hours',
      subtitle: 'Patients see one bookable slot every $_slot minutes inside '
          'this window.',
      submitLabel: _isEdit ? 'Save hours' : 'Add hours',
      busy: _busy,
      error: _error,
      onSubmit: _tooShort ? null : _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(isStart: true),
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(
                    _start.format(context),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(isStart: false),
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(
                    _end.format(context),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Slot length', style: context.texts.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final minutes in _slotOptions)
                ChoiceChip(
                  label: Text('$minutes min'),
                  selected: minutes == _slot,
                  onSelected: (_) => setState(() => _slot = minutes),
                ),
            ],
          ),
          if (_tooShort) ...[
            const SizedBox(height: AppSpacing.md),
            MessageBanner(
              message: _minutes <= 0
                  ? 'The window has to end after it starts.'
                  : 'A $_minutes-minute window fits no $_slot-minute slot, so '
                      'nobody could book it.',
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'That is ${_minutes ~/ _slot} slots.',
              style: context.texts.bodySmall,
            ),
          ],
        ],
      ),
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
          message: 'Hours are attached to a doctor profile. Add your NMC '
              'registration under Account and this page opens.',
        ),
      ],
    );
  }
}
