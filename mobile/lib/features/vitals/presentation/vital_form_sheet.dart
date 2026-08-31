/// Record a reading.
///
/// Every metric is optional server-side — `POST /api/vitals` will happily store
/// a row with nothing in it — so the one rule this form enforces that the API
/// does not is that a reading must contain at least one measurement. See
/// `BACKEND_NOTES.md`: tightening it server-side would turn a 200 into a 400 on
/// an existing route, so it is guarded here instead.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/time/medi_time.dart';
import '../../../core/widgets/form_sheet.dart';
import '../../../core/widgets/states.dart';
import '../domain/vital_sign.dart';
import 'vitals_controller.dart';

Future<VitalSign?> showVitalSheet(BuildContext context) {
  return showFormSheet<VitalSign>(
    context: context,
    builder: (_) => const VitalFormSheet(),
  );
}

class VitalFormSheet extends ConsumerStatefulWidget {
  const VitalFormSheet({super.key});

  @override
  ConsumerState<VitalFormSheet> createState() => _VitalFormSheetState();
}

class _VitalFormSheetState extends ConsumerState<VitalFormSheet> {
  final _form = GlobalKey<FormState>();
  final _systolic = TextEditingController();
  final _diastolic = TextEditingController();
  final _heartRate = TextEditingController();
  final _sugar = TextEditingController();
  final _temperature = TextEditingController();
  final _oxygen = TextEditingController();
  final _weight = TextEditingController();
  final _notes = TextEditingController();

  late DateTime _measuredAt = DateTime.now();
  bool _busy = false;
  Object? _error;

  /// Recomputed on every keystroke so the save button reflects whether there is
  /// anything to save.
  bool _hasAnyValue = false;

  /// One half of a blood pressure and not the other. Tracked here rather than
  /// read straight off the controllers in `build`, because a controller change
  /// only rebuilds this widget when one of these flags flips — filling the
  /// second half would otherwise leave the button disabled and the warning up.
  bool _bpHalfFilled = false;

  @override
  void initState() {
    super.initState();
    for (final controller in _metricFields) {
      controller.addListener(_onFieldChanged);
    }
  }

  List<TextEditingController> get _metricFields => [
        _systolic,
        _diastolic,
        _heartRate,
        _sugar,
        _temperature,
        _oxygen,
        _weight,
      ];

  void _onFieldChanged() {
    final any = _metricFields.any((field) => field.text.trim().isNotEmpty);
    // Both halves of a blood pressure or neither: one number on its own is not
    // a blood pressure, and the analyser skips a half-filled pair silently.
    final halfBp = _systolic.text.trim().isEmpty !=
        _diastolic.text.trim().isEmpty;
    if (any == _hasAnyValue && halfBp == _bpHalfFilled) return;
    setState(() {
      _hasAnyValue = any;
      _bpHalfFilled = halfBp;
    });
  }

  @override
  void dispose() {
    for (final controller in _metricFields) {
      controller.removeListener(_onFieldChanged);
      controller.dispose();
    }
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickMoment() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _measuredAt,
      firstDate: DateTime(DateTime.now().year - 5),
      // A reading cannot have been taken in the future.
      lastDate: DateTime.now(),
      helpText: 'When was it taken?',
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_measuredAt),
      helpText: 'Time it was taken',
    );
    if (time == null || !mounted) return;

    setState(() {
      _measuredAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (!_hasAnyValue) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final saved = await ref.read(vitalsProvider.notifier).add(
            systolic: _int(_systolic),
            diastolic: _int(_diastolic),
            heartRate: _int(_heartRate),
            bloodSugar: _double(_sugar),
            temperature: _double(_temperature),
            oxygenSaturation: _int(_oxygen),
            weight: _double(_weight),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            measuredAt: _measuredAt,
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

  static int? _int(TextEditingController field) =>
      int.tryParse(field.text.trim());

  static double? _double(TextEditingController field) =>
      double.tryParse(field.text.trim());

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: 'Record a reading',
      subtitle: 'Fill in whatever you measured. Anything you leave blank is '
          'simply not recorded.',
      submitLabel: 'Save reading',
      busy: _busy,
      error: _error,
      onSubmit: _hasAnyValue && !_bpHalfFilled ? _save : null,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _WhenRow(moment: _measuredAt, onTap: _pickMoment),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _NumberField(
                    controller: _systolic,
                    label: 'Systolic',
                    suffix: 'mmHg',
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _NumberField(
                    controller: _diastolic,
                    label: 'Diastolic',
                    suffix: 'mmHg',
                  ),
                ),
              ],
            ),
            if (_bpHalfFilled) ...[
              const SizedBox(height: AppSpacing.sm),
              const MessageBanner(
                message: 'A blood pressure needs both numbers.',
                tone: BannerTone.notice,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    controller: _heartRate,
                    label: 'Heart rate',
                    suffix: 'bpm',
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _NumberField(
                    controller: _oxygen,
                    label: 'Oxygen',
                    suffix: '%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    controller: _temperature,
                    label: 'Temperature',
                    suffix: '°C',
                    decimal: true,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _NumberField(
                    controller: _weight,
                    label: 'Weight',
                    suffix: 'kg',
                    decimal: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _NumberField(
              controller: _sugar,
              label: 'Blood sugar',
              // The web's summary strip says mmol/L while its own form and
              // analyser use mg/dL. mg/dL is the real unit; saying so on the
              // field is the only place a user can be warned.
              suffix: 'mg/dL',
              decimal: true,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _notes,
              textCapitalization: TextCapitalization.sentences,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Before breakfast, after a walk…',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhenRow extends StatelessWidget {
  const _WhenRow({required this.moment, required this.onTap});

  final DateTime moment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.schedule, size: 18),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text('Taken  ${MediTime.dateTime(moment)}'),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.suffix,
    this.decimal = false,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          decimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
        ),
      ],
      style: context.numerals.numericMedium,
      decoration: InputDecoration(labelText: label, suffixText: suffix),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return null;
        final num? parsed = decimal ? double.tryParse(text) : int.tryParse(text);
        if (parsed == null) return 'Numbers only.';
        if (parsed <= 0) return 'Must be above zero.';
        return null;
      },
    );
  }
}
