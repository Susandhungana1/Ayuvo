/// Looking at a file the server holds.
///
/// Images render from memory with pinch-to-zoom; PDFs go through `printing`,
/// which rasterises with the platform's own renderer and brings share and print
/// with it. Anything else says plainly that it can't be shown here rather than
/// presenting an empty frame.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../widgets/states.dart';
import 'file_bytes.dart';

class FileViewerScreen extends ConsumerWidget {
  const FileViewerScreen({
    super.key,
    required this.title,
    required this.fileName,
    required this.path,
  });

  /// What the file is — "Blood test, 6 Aug 2026".
  final String title;

  /// Decides how to render. The server guesses content type from this too.
  final String fileName;

  /// The API path the bytes come from, already scoped.
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(fileBytesProvider(path));

    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.sm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                fileName,
                style: context.texts.bodySmall
                    ?.copyWith(color: context.colors.onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
      body: switch (bytes) {
        AsyncData(:final value) => switch (fileKindOf(fileName)) {
            FileKind.image => InteractiveViewer(
                maxScale: 6,
                child: Center(child: Image.memory(value)),
              ),
            FileKind.pdf => PdfPreview(
                build: (_) => value,
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
              ),
            FileKind.other => _Unsupported(fileName: fileName),
          },
        AsyncError(:final error) => Padding(
            padding: AppSpacing.screen,
            child: ErrorView(
              error: error,
              onRetry: () => ref.invalidate(fileBytesProvider(path)),
            ),
          ),
        // A file download has no shape to skeleton, and it can be megabytes on
        // a slow connection, so this is the one place a spinner is the honest
        // answer — with a line saying what it is waiting for.
        _ => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: AppSpacing.lg),
                Text('Fetching $fileName…', style: context.texts.bodyMedium),
              ],
            ),
          ),
      },
    );
  }
}

class _Unsupported extends StatelessWidget {
  const _Unsupported({required this.fileName});

  final String fileName;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.insert_drive_file_outlined,
      title: 'Can\'t show this one here',
      message: '$fileName isn\'t an image or a PDF, so there is nothing to '
          'render. It is safely stored and still downloadable from the web '
          'app.',
    );
  }
}
