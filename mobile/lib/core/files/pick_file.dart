/// Choosing a file to upload.
///
/// Three sources, because a health record arrives in three ways: the report is
/// already a PDF on the phone, or it is a photo in the gallery, or it is a
/// piece of paper in the user's hand. The camera is the one the web app cannot
/// offer and the one most likely to be used.
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// A file chosen but not yet uploaded.
@immutable
class PickedFile {
  const PickedFile({
    required this.name,
    required this.bytes,
    required this.path,
  });

  final String name;
  final Uint8List bytes;

  /// The on-disk path. dio streams from here rather than holding the file in
  /// memory twice.
  final String path;

  int get sizeBytes => bytes.length;

  /// The server refuses anything larger, on both upload routes.
  static const maxBytes = 10 * 1024 * 1024;

  bool get isTooBig => sizeBytes > maxBytes;

  String get readableSize {
    final mb = sizeBytes / (1024 * 1024);
    if (mb >= 1) return '${mb.toStringAsFixed(1)} MB';
    return '${(sizeBytes / 1024).round()} KB';
  }
}

/// Asks where the file is coming from, then gets it. Null if the user backs
/// out at either step.
Future<PickedFile?> pickFile(BuildContext context) async {
  final source = await showModalBottomSheet<_Source>(
    context: context,
    useSafeArea: true,
    builder: (context) => const _SourceSheet(),
  );
  if (source == null) return null;

  return switch (source) {
    _Source.camera => _fromCamera(),
    _Source.gallery => _fromGallery(),
    _Source.files => _fromFiles(),
  };
}

enum _Source { camera, gallery, files }

Future<PickedFile?> _fromCamera() async {
  final shot = await ImagePicker().pickImage(
    source: ImageSource.camera,
    // A 12-megapixel photo of an A4 page is 6 MB of mostly-white paper and is
    // no easier to read than this. Staying under the server's 10 MB cap by
    // construction beats explaining a rejection afterwards.
    maxWidth: 2400,
    imageQuality: 85,
  );
  return shot == null ? null : _fromXFile(shot);
}

Future<PickedFile?> _fromGallery() async {
  final shot = await ImagePicker().pickImage(source: ImageSource.gallery);
  return shot == null ? null : _fromXFile(shot);
}

Future<PickedFile?> _fromXFile(XFile file) async {
  final bytes = await file.readAsBytes();
  return PickedFile(name: file.name, bytes: bytes, path: file.path);
}

Future<PickedFile?> _fromFiles() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
    withData: true,
  );
  final file = result?.files.single;
  final bytes = file?.bytes;
  final path = file?.path;
  if (file == null || bytes == null || path == null) return null;
  return PickedFile(name: file.name, bytes: bytes, path: path);
}

class _SourceSheet extends StatelessWidget {
  const _SourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Add a file', style: context.texts.titleLarge),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            subtitle: const Text('Point the camera at the printout'),
            onTap: () => Navigator.of(context).pop(_Source.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose a photo'),
            onTap: () => Navigator.of(context).pop(_Source.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Choose a file'),
            subtitle: const Text('PDF or image, up to 10 MB'),
            onTap: () => Navigator.of(context).pop(_Source.files),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}
