/// The public whole-record reader: `front/app/share/qr-code/[token]`, reachable
/// inside the app too.
///
/// Someone opens this after scanning a QR code or tapping "Open in App" — they
/// may have no account, and the token does the authenticating. The screen
/// fetches the record itself (no session) and shows the emergency profile, the
/// medicines, and the reports, exactly as the web reader does.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<SharedRecord> _load() =>
      ref.read(shareRepositoryProvider).fetchSharedRecord(widget.token);

  void _retry() {
    setState(() {
      _future = _load();
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
            return SafeArea(
              child: SingleChildScrollView(
                padding: AppSpacing.screen,
                child: ErrorView(error: snapshot.error!, onRetry: _retry),
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
                  'Shared with MediStore · the link expires and can be revoked '
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
