/// The public single-report reader: `front/app/share/[token]`, reachable inside
/// the app too. One report, plus the patient's emergency context.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/time/medi_time.dart';
import '../../../core/widgets/states.dart';
import '../data/share_repository.dart';
import '../domain/shared_record.dart';
import 'shared_file_viewer.dart';
import 'shared_reader_widgets.dart';

class SharedReportScreen extends ConsumerStatefulWidget {
  const SharedReportScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<SharedReportScreen> createState() => _SharedReportScreenState();
}

class _SharedReportScreenState extends ConsumerState<SharedReportScreen> {
  late Future<SharedReportPage> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<SharedReportPage> _load() =>
      ref.read(shareRepositoryProvider).fetchSharedReport(widget.token);

  void _retry() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shared report')),
      body: FutureBuilder<SharedReportPage>(
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
          final page = snapshot.data!;
          final report = page.report;
          return SafeArea(
            child: ListView(
              padding: AppSpacing.screen,
              children: [
                SharedSectionHeader(report.reportType.replaceAll('_', ' ')),
                const SizedBox(height: AppSpacing.sm),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: AppSpacing.card,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(report.fileName, style: context.texts.bodyLarge),
                        if (report.created != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Uploaded ${MediTime.date(report.created!)}',
                            style: context.texts.bodySmall,
                          ),
                        ],
                        if (report.doctorName?.trim().isNotEmpty ?? false) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Doctor: ${report.doctorName}',
                            style: context.texts.bodySmall,
                          ),
                        ],
                        if (report.hospital?.trim().isNotEmpty ?? false) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Hospital: ${report.hospital}',
                            style: context.texts.bodySmall,
                          ),
                        ],
                        if (report.notes?.trim().isNotEmpty ?? false) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(report.notes!, style: context.texts.bodyMedium),
                        ],
                        if (report.hasFile) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Center(
                            child: FilledButton.icon(
                              onPressed: _open(context, page),
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('View original'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (page.emergency.hasAnything) ...[
                  const SizedBox(height: AppSpacing.lg),
                  SharedEmergencyCard(emergency: page.emergency),
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

  VoidCallback _open(BuildContext context, SharedReportPage page) {
    return () {
      final problem = openSharedFile(
        page.report.fileContentB64,
        page.report.fileName,
      );
      if (problem != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(problem)));
      }
    };
  }
}
