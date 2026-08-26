/// The public whole-record reader: `front/app/share/qr-code/[token]`, reachable
/// inside the app too.
///
/// Someone opens this after scanning a QR code or tapping "Open in App" — they
/// may have no account, and the token does the authenticating. Whole-record
/// links are PIN-guarded, so the first fetch usually answers 401 with "PIN
/// protected": the screen then asks for the 6-digit PIN before it shows
/// anything. The emergency profile, medicines and reports render exactly as
/// the web reader does.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/states.dart';
import '../data/share_repository.dart';
import '../domain/shared_record.dart';
import 'shared_file_viewer.dart';
import 'shared_reader_widgets.dart';

class SharedRecordScreen extends ConsumerStatefulWidget {
  const SharedRecordScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<SharedRecordScreen> createState() => _SharedRecordScreenState();
}

class _SharedRecordScreenState extends ConsumerState<SharedRecordScreen> {
  late Future<SharedRecord> _future;
  bool _pinKnown = false;
  String _enteredPin = '';
  String? _pinError;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<SharedRecord> _load({String? pin}) =>
      ref.read(shareRepositoryProvider).fetchSharedRecord(
            widget.token,
            pin: pin,
          );

  /// Whether the server answered 401 with a PIN message. Anything else —
  /// expired (410), revoked (404), server trouble — must not be swallowed into
  /// the PIN prompt.
  static bool _isPinChallenge(Object error) {
    final api = ApiException.from(error);
    if (api.statusCode != 401) return false;
    final detail = api.detail?.toLowerCase() ?? '';
    return detail.contains('pin');
  }

  void _submitPin() {
    final pin = _enteredPin.trim();
    if (pin.length != 6) return;
    setState(() {
      _pinKnown = true;
      _pinError = null;
      _future = _load(pin: pin);
    });
  }

  void _retry() {
    setState(() {
      _future = _load(pin: _pinKnown ? _enteredPin.trim() : null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shared record')),
      body: FutureBuilder<SharedRecord>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final error = snapshot.error!;
            if (!_pinKnown && _isPinChallenge(error)) {
              return _PinPrompt(
                error: _pinError,
                value: _enteredPin,
                onChanged: (value) => setState(() => _enteredPin = value),
                onSubmit: _submitPin,
              );
            }
            if (_pinKnown && _isPinChallenge(error)) {
              // Wrong PIN: keep the prompt, explain what happened.
              return _PinPrompt(
                error: 'Incorrect PIN — try again.',
                value: _enteredPin,
                onChanged: (value) => setState(() => _enteredPin = value),
                onSubmit: _submitPin,
              );
            }
            return SafeArea(
              child: SingleChildScrollView(
                padding: AppSpacing.screen,
                child: ErrorView(error: error, onRetry: _retry),
              ),
            );
          }
          final record = snapshot.data!;
          return SafeArea(
            child: ListView(
              padding: AppSpacing.screen,
              children: [
                Text('Shared medical record', style: context.texts.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${record.reports.length} report(s) · '
                  '${record.medicines.length} medicine(s)',
                  style: context.texts.bodySmall,
                ),
                if (record.emergency.hasAnything) ...[
                  const SizedBox(height: AppSpacing.md),
                  SharedEmergencyCard(emergency: record.emergency),
                ],
                if (record.medicines.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  SharedSectionHeader('Medicines'),
                  const SizedBox(height: AppSpacing.sm),
                  for (final med in record.medicines)
                    SharedMedicineTile(medicine: med),
                ],
                if (record.reports.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  SharedSectionHeader('Medical reports'),
                  const SizedBox(height: AppSpacing.sm),
                  for (final report in record.reports)
                    SharedReportTile(
                      report: report,
                      onView: report.hasFile
                          ? () {
                              final problem = openSharedFile(
                                report.fileContentB64,
                                report.fileName,
                              );
                              if (problem != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(problem)),
                                );
                              }
                            }
                          : null,
                    ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Shared with Ayuvo · the link expires and can be revoked '
                  'by its owner at any time',
                  style: context.texts.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PinPrompt extends StatelessWidget {
  const _PinPrompt({
    required this.error,
    required this.value,
    required this.onChanged,
    required this.onSubmit,
  });

  final String? error;
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final canSubmit = value.trim().length == 6;
    return SafeArea(
      child: SingleChildScrollView(
        padding: AppSpacing.screen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This record is PIN-protected',
              style: context.texts.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'The owner set a 6-digit PIN on this shared record. Ask them '
              'for it — it is never sent with the link.',
              style: context.texts.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: context.texts.bodyLarge?.copyWith(
                letterSpacing: 6,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              decoration: InputDecoration(
                labelText: '6-digit PIN',
                counterText: '',
                border: const OutlineInputBorder(),
                errorText: error,
              ),
              onChanged: onChanged,
              onSubmitted: (_) {
                if (canSubmit) onSubmit();
              },
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canSubmit ? onSubmit : null,
                child: const Text('View health record'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}