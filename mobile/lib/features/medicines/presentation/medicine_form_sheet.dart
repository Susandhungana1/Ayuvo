/// Add or edit one medicine. The same sheet does both: the fields are
/// identical, and two near-copies would drift.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/time/medi_time.dart';
import '../../../core/widgets/form_sheet.dart';
import '../domain/medicine.dart';
import 'medicines_controller.dart';

/// Opens the sheet. Returns the saved medicine, or null if it was dismissed.
Future<Medicine?> showMedicineSheet(
  BuildContext context, {
  Medicine? existing,
  String? patientId,
}) {
  return showFormSheet<Medicine>(
    context: context,
    builder: (_) =>
        MedicineFormSheet(existing: existing, patientId: patientId),
  );
}

class MedicineFormSheet extends ConsumerStatefulWidget {
  const MedicineFormSheet({super.key, this.existing, this.patientId});

  final Medicine? existing;
  final String? patientId;

  @override
  ConsumerState<MedicineFormSheet> createState() => _MedicineFormSheetState();
}

class _MedicineFormSheetState extends ConsumerState<MedicineFormSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _dosage;
  late final TextEditingController _frequency;
  late final TextEditingController _notes;

  late DateTime _startDate;
  DateTime? _endDate;
  late List<String> _times;

  bool _busy = false;
  Object? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _dosage = TextEditingController(text: existing?.dosage ?? '');
    _frequency = TextEditingController(text: existing?.frequency ?? '');
    _notes = TextEditingController(text: existing?.notes ?? '');
    _times = [...?existing?.times];
    _startDate =
        MediTime.parseDate(existing?.startDate) ?? _today;
    _endDate = MediTime.parseDate(existing?.endDate);
  }

  @override
  void dispose() {
    _name.dispose();
    _dosage.dispose();
    _frequency.dispose();
    _notes.dispose();
    super.dispose();
  }

  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      // A course can legitimately have started years ago and can be scheduled
      // ahead, so neither bound is tight.
      firstDate: DateTime(_today.year - 10),
      lastDate: DateTime(_today.year + 5),
      helpText: 'Start date',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _startDate = picked;
      // An end before the start is not a state the user can be left in.
      if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
    });
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate,
      firstDate: _startDate,
      lastDate: DateTime(_today.year + 5),
      helpText: 'End date',
    );
    if (picked == null || !mounted) return;
    setState(() => _endDate = picked);
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: 'Dose time',
    );
    if (picked == null || !mounted) return;
    final value = MediTime.clock(picked.hour, picked.minute);
    if (_times.contains(value)) return;
    setState(() => _times = [..._times, value]..sort());
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final controller = ref.read(medicinesProvider(widget.patientId).notifier);
    try {
      final saved = _isEdit
          ? await controller.edit(
              widget.existing!.id,
              name: _name.text.trim(),
              dosage: _dosage.text.trim(),
              frequency: _frequency.text.trim(),
              startDate: MediTime.dateOnly(_startDate),
              // `PUT` reads null as "leave unchanged", so clearing an end date
              // sends an empty string — the nearest thing to "no end" this
              // route allows. See the repository for why.
              endDate: _endDate == null ? '' : MediTime.dateOnly(_endDate!),
              times: _times,
              notes: _notes.text.trim(),
            )
          : await controller.add(
              name: _name.text.trim(),
              dosage: _dosage.text.trim(),
              frequency: _frequency.text.trim(),
              startDate: MediTime.dateOnly(_startDate),
              endDate: _endDate == null ? null : MediTime.dateOnly(_endDate!),
              times: _times,
              notes: _notes.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: _isEdit ? 'Edit medicine' : 'Add a medicine',
      submitLabel: _isEdit ? 'Save changes' : 'Add medicine',
      busy: _busy,
      error: _error,
      onSubmit: _save,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Amlodipine',
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Enter the medicine\'s name.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _dosage,
              decoration: const InputDecoration(
                labelText: 'Dosage',
                hintText: '5 mg',
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Enter the dose, such as 5 mg.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _frequency,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'How often',
                hintText: 'Once daily',
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Say how often it is taken.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            _FrequencySuggestions(
              onPick: (value) => _frequency.text = value,
            ),
            const SizedBox(height: AppSpacing.lg),
            _DateRow(
              label: 'Starts',
              value: MediTime.date(_startDate),
              onTap: _pickStart,
            ),
            const SizedBox(height: AppSpacing.sm),
            _DateRow(
              label: 'Ends',
              value: _endDate == null ? 'Ongoing' : MediTime.date(_endDate!),
              onTap: _pickEnd,
              onClear: _endDate == null ? null : () => setState(() => _endDate = null),
            ),
            const SizedBox(height: AppSpacing.lg),
            _TimesField(
              times: _times,
              onAdd: _addTime,
              onRemove: (time) =>
                  setState(() => _times = [..._times]..remove(time)),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _notes,
              textCapitalization: TextCapitalization.sentences,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Take with food',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The four answers that cover most prescriptions. Tapping one fills the field,
/// which stays editable — the server takes free text and some courses really
/// are "every other day, in the evening".
class _FrequencySuggestions extends StatelessWidget {
  const _FrequencySuggestions({required this.onPick});

  final ValueChanged<String> onPick;

  static const _options = [
    'Once daily',
    'Twice daily',
    'Three times daily',
    'As needed',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        for (final option in _options)
          ActionChip(label: Text(option), onPressed: () => onPick(option)),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Align(
              alignment: Alignment.centerLeft,
              child: Text('$label  $value'),
            ),
          ),
        ),
        if (onClear != null)
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close),
            tooltip: 'Clear the end date',
          ),
      ],
    );
  }
}

class _TimesField extends StatelessWidget {
  const _TimesField({
    required this.times,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> times;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dose times', style: context.texts.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          times.isEmpty
              ? 'Without a time this medicine is on your list but not on your '
                  'schedule, and no reminder can be set for it.'
              : 'Used for today\'s schedule and the next-dose countdown.',
          style: context.texts.bodySmall
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final time in times)
              InputChip(
                label: Text(MediTime.clockLabel(time)),
                onDeleted: () => onRemove(time),
                deleteButtonTooltipMessage: 'Remove this dose time',
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Add a time'),
              onPressed: onAdd,
            ),
          ],
        ),
      ],
    );
  }
}
