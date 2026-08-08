/// Visits, and the paperwork each one produced.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/files/file_bytes.dart';
import '../../../core/files/file_viewer.dart';
import '../../../core/files/pick_file.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/time/medi_time.dart';
import '../../../core/widgets/form_sheet.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/states.dart';
import '../data/document_repository.dart';
import '../domain/document.dart';
import 'documents_controller.dart';

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key, this.highlightId});

  /// Opened from a search result: that visit's card starts expanded, so the
  /// user lands on the thing they searched for rather than on a list they have
  /// to find it in again. There is no document detail screen to deep-link to —
  /// the card *is* the detail view.
  final String? highlightId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(documentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      floatingActionButton: documents.hasValue && documents.value!.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _showDocumentSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.read(documentsProvider.notifier).refresh(),
        child: switch (documents) {
          AsyncData(:final value) when value.isEmpty =>
            _Empty(onAdd: () => _showDocumentSheet(context)),
          AsyncData(:final value) => ListView.builder(
              padding: AppSpacing.screen,
              itemCount: value.length + 1,
              itemBuilder: (context, index) => index == value.length
                  ? const SizedBox(height: 88)
                  : Padding(
                      key: ValueKey(value[index].id),
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _DocumentCard(
                        document: value[index],
                        startExpanded: value[index].id == highlightId,
                      ),
                    ),
            ),
          AsyncError(:final error) => ListView(
              padding: AppSpacing.screen,
              children: [
                ErrorView(
                  error: error,
                  onRetry: () =>
                      ref.read(documentsProvider.notifier).refresh(),
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

class _DocumentCard extends ConsumerWidget {
  const _DocumentCard({required this.document, this.startExpanded = false});

  final MedicalDocument document;
  final bool startExpanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visited = document.visited;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: startExpanded,
        // No border under the header when collapsed — the card already has one.
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        title: Text(document.hospital, style: context.texts.titleMedium),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (document.subtitle.isNotEmpty)
              Text(
                document.subtitle,
                style: context.texts.bodySmall
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            Text(
              visited == null ? 'Undated' : MediTime.date(visited),
              style: context.texts.bodySmall
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (document.description?.trim().isNotEmpty ?? false) ...[
                  Text(
                    document.description!.trim(),
                    style: context.texts.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                _Attachments(document: document),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _attach(context, ref),
                      icon: const Icon(Icons.attach_file, size: 18),
                      label: const Text('Add a file'),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _confirmDelete(context, ref),
                      icon: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: context.colors.error,
                      ),
                      label: Text(
                        'Delete',
                        style: TextStyle(color: context.colors.error),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _attach(BuildContext context, WidgetRef ref) async {
    final file = await pickFile(context);
    if (file == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    if (file.isTooBig) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${file.name} is ${file.readableSize}. The limit is 10 MB.',
          ),
        ),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(content: Text('Uploading ${file.name}…')),
    );
    try {
      await ref.read(documentRepositoryProvider).attach(
            document.id,
            filePath: file.path,
            fileName: file.name,
          );
      ref.invalidate(documentFilesProvider(document.id));
      messenger.showSnackBar(SnackBar(content: Text('Added ${file.name}')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorText.of(error))));
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete the ${document.hospital} visit?'),
        // The cascade is the important part: a user who only meant to tidy the
        // list would not expect the scans to go with it.
        content: const Text(
          'Every file attached to it is deleted too. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(documentsProvider.notifier).remove(document.id);
      messenger.showSnackBar(const SnackBar(content: Text('Visit deleted')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorText.of(error))));
    }
  }
}

class _Attachments extends ConsumerWidget {
  const _Attachments({required this.document});

  final MedicalDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = ref.watch(documentFilesProvider(document.id));

    return switch (files) {
      AsyncData(:final value) when value.isEmpty => Text(
          'No files attached to this visit yet.',
          style: context.texts.bodySmall
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
      AsyncData(:final value) => Column(
          children: [
            for (final file in value)
              ListTile(
                key: ValueKey(file.id),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  switch (fileKindOf(file.name)) {
                    FileKind.image => Icons.image_outlined,
                    FileKind.pdf => Icons.picture_as_pdf_outlined,
                    FileKind.other => Icons.insert_drive_file_outlined,
                  },
                ),
                title: Text(file.name, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FileViewerScreen(
                      title: document.hospital,
                      fileName: file.name,
                      path: DocumentRepository.filePath(document.id, file.id),
                    ),
                  ),
                ),
              ),
          ],
        ),
      AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(documentFilesProvider(document.id)),
        ),
      _ => const Skeleton(width: 200, height: 14),
    };
  }
}

Future<void> _showDocumentSheet(BuildContext context) async {
  await showFormSheet<MedicalDocument>(
    context: context,
    builder: (_) => const _DocumentFormSheet(),
  );
}

class _DocumentFormSheet extends ConsumerStatefulWidget {
  const _DocumentFormSheet();

  @override
  ConsumerState<_DocumentFormSheet> createState() => _DocumentFormSheetState();
}

class _DocumentFormSheetState extends ConsumerState<_DocumentFormSheet> {
  final _form = GlobalKey<FormState>();
  final _hospital = TextEditingController();
  final _department = TextEditingController();
  final _doctor = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();

  late DateTime _visitedOn = DateTime.now();
  bool _busy = false;
  Object? _error;

  @override
  void dispose() {
    _hospital.dispose();
    _department.dispose();
    _doctor.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitedOn,
      firstDate: DateTime(now.year - 20),
      lastDate: now,
      helpText: 'Date of the visit',
    );
    if (picked != null) setState(() => _visitedOn = picked);
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final saved = await ref.read(documentsProvider.notifier).add(
            hospital: _hospital.text.trim(),
            department: _text(_department),
            doctorName: _text(_doctor),
            location: _text(_location),
            description: _text(_description),
            visitedOn: _visitedOn,
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

  static String? _text(TextEditingController field) {
    final value = field.text.trim();
    return value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: 'Add a visit',
      subtitle: 'Record where you went, then attach whatever you were given.',
      submitLabel: 'Save visit',
      busy: _busy,
      error: _error,
      onSubmit: _save,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _hospital,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Hospital or clinic',
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Where was the visit?'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Align(
                alignment: Alignment.centerLeft,
                child: Text('Visited  ${MediTime.date(_visitedOn)}'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _department,
              textCapitalization: TextCapitalization.words,
              decoration:
                  const InputDecoration(labelText: 'Department (optional)'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _doctor,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Doctor (optional)'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _location,
              textCapitalization: TextCapitalization.words,
              decoration:
                  const InputDecoration(labelText: 'Location (optional)'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _description,
              textCapitalization: TextCapitalization.sentences,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'What it was for (optional)',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
        EmptyState(
          icon: Icons.folder_outlined,
          title: 'No visits recorded',
          message: 'Keep a record of where you went and who you saw, with the '
              'discharge summaries and prescriptions attached to it.',
          actionLabel: 'Add your first visit',
          onAction: onAdd,
        ),
      ],
    );
  }
}
