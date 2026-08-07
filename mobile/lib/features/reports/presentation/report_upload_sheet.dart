/// Uploading a report — the slowest thing this app does.
///
/// `POST /api/reports` runs OCR and then two LLM calls before it answers, so
/// the request routinely takes a minute or more. Bytes-sent progress covers
/// only the first few seconds of that, and a bar frozen at 100% reads as a
/// hang. So this screen shows two phases and names them: *Uploading* while
/// bytes move, then *Reading the report* while the server works.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/files/pick_file.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/time/medi_time.dart';
import '../../../core/widgets/form_sheet.dart';
import '../../../core/widgets/states.dart';
import '../data/report_repository.dart';
import '../domain/report.dart';
import 'reports_controller.dart';

Future<MedicalReport?> showReportUploadSheet(BuildContext context) {
  return showFormSheet<MedicalReport>(
    context: context,
    builder: (_) => const ReportUploadSheet(),
  );
}

class ReportUploadSheet extends ConsumerStatefulWidget {
  const ReportUploadSheet({super.key});

  @override
  ConsumerState<ReportUploadSheet> createState() => _ReportUploadSheetState();
}

class _ReportUploadSheetState extends ConsumerState<ReportUploadSheet> {
  final _hospital = TextEditingController();
  final _doctor = TextEditingController();
  final _notes = TextEditingController();

  PickedFile? _file;
  ReportType _type = ReportType.bloodTest;
  DateTime? _reportDate;

  /// null = not started. 0…1 = bytes sent. 1 with [_processing] = the server
  /// is reading it.
  double? _sent;
  bool _processing = false;
  Object? _error;

  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;

  bool get _busy => _sent != null;

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _hospital.dispose();
    _doctor.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    final picked = await pickFile(context);
    if (picked == null || !mounted) return;
    setState(() {
      _file = picked;
      _error = null;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _reportDate ?? now,
      firstDate: DateTime(now.year - 20),
      lastDate: now,
      helpText: 'Date on the report',
    );
    if (picked != null) setState(() => _reportDate = picked);
  }

  Future<void> _upload() async {
    final file = _file;
    if (file == null || file.isTooBig) return;

    setState(() {
      _sent = 0;
      _processing = false;
      _error = null;
      _elapsed = Duration.zero;
    });
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });

    try {
      final report = await ref.read(reportRepositoryProvider).upload(
            filePath: file.path,
            fileName: file.name,
            type: _type,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            reportDate:
                _reportDate == null ? null : MediTime.dateOnly(_reportDate!),
            hospital:
                _hospital.text.trim().isEmpty ? null : _hospital.text.trim(),
            doctorName:
                _doctor.text.trim().isEmpty ? null : _doctor.text.trim(),
            onProgress: (sent, total) {
              if (!mounted || total <= 0) return;
              setState(() {
                _sent = sent / total;
                // Bytes are all gone; everything after this is the server
                // reading the file, which reports no progress at all.
                _processing = sent >= total;
              });
            },
          );
      _elapsedTimer?.cancel();
      ref.read(reportsProvider.notifier).remember(report);
      if (mounted) Navigator.of(context).pop(report);
    } catch (error) {
      _elapsedTimer?.cancel();
      if (mounted) {
        setState(() {
          _sent = null;
          _processing = false;
          _error = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    final canUpload = file != null && !file.isTooBig;

    return FormSheet(
      title: 'Add a report',
      subtitle: 'Reading it takes a minute or so — the text is extracted and '
          'summarised on the server before it appears.',
      submitLabel: 'Upload report',
      busyLabel: _processing ? 'Reading the report…' : 'Uploading…',
      busy: _busy,
      error: _error,
      onSubmit: canUpload ? _upload : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FilePicker(file: file, onChoose: _busy ? null : _choose),
          if (_busy) ...[
            const SizedBox(height: AppSpacing.lg),
            _Progress(
              sent: _sent ?? 0,
              processing: _processing,
              elapsed: _elapsed,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text('What kind of report', style: context.texts.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final type in ReportType.values)
                ChoiceChip(
                  label: Text(type.label),
                  selected: type == _type,
                  onSelected: _busy ? null : (_) => setState(() => _type = type),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickDate,
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _reportDate == null
                    ? 'Date on the report (optional)'
                    : 'Dated  ${MediTime.date(_reportDate!)}',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _hospital,
            enabled: !_busy,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Hospital or lab (optional)',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _doctor,
            enabled: !_busy,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Doctor (optional)',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _notes,
            enabled: !_busy,
            textCapitalization: TextCapitalization.sentences,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilePicker extends StatelessWidget {
  const _FilePicker({required this.file, required this.onChoose});

  final PickedFile? file;
  final VoidCallback? onChoose;

  @override
  Widget build(BuildContext context) {
    if (file == null) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onChoose,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text('Choose a file or take a photo'),
        ),
      );
    }

    final chosen = file!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(chosen.name, overflow: TextOverflow.ellipsis),
            subtitle: Text(chosen.readableSize),
            trailing: onChoose == null
                ? null
                : TextButton(onPressed: onChoose, child: const Text('Change')),
          ),
        ),
        if (chosen.isTooBig) ...[
          const SizedBox(height: AppSpacing.sm),
          const MessageBanner(
            message: 'That file is over the 10 MB limit. Choose a smaller one, '
                'or photograph the report instead of scanning it.',
          ),
        ],
      ],
    );
  }
}

/// Two honest phases. The determinate bar is real while bytes are moving; once
/// they have all gone it becomes indeterminate, because the server gives no
/// progress and a fake bar would be a lie about a wait the user can see.
class _Progress extends StatelessWidget {
  const _Progress({
    required this.sent,
    required this.processing,
    required this.elapsed,
  });

  final double sent;
  final bool processing;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(value: processing ? null : sent),
        const SizedBox(height: AppSpacing.sm),
        Text(
          processing
              ? 'Sent. The server is extracting the text and summarising it — '
                  'this is the slow part. ${_clock(elapsed)} so far.'
              : 'Uploading… ${(sent * 100).round()}%',
          style: context.texts.bodySmall
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
      ],
    );
  }

  static String _clock(Duration elapsed) {
    final seconds = elapsed.inSeconds;
    if (seconds < 60) return '${seconds}s';
    return '${elapsed.inMinutes}m ${seconds % 60}s';
  }
}
