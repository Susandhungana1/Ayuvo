/// Fetching an auth-gated file.
///
/// Report files and document attachments are not public URLs — they are routes
/// that read the bearer token and 401 without it. `Image.network` sends no
/// header, so **every** binary in this app is fetched here and handed to the
/// widget as bytes.
///
/// The provider is keyed by path and auto-disposes, so re-opening the same
/// attachment inside one screen reuses the download while leaving the screen
/// releases it. A phone should not hold ten scanned reports in memory because
/// the user looked at them once.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/network_providers.dart';

final fileBytesProvider =
    FutureProvider.autoDispose.family<Uint8List, String>((ref, path) {
  // Kept alive briefly after the last watcher leaves: flipping between the
  // image and its lab values should not re-download the scan.
  final link = ref.keepAlive();
  Timer? timer;
  ref.onDispose(() => timer?.cancel());
  ref.onCancel(() {
    timer = Timer(const Duration(minutes: 2), link.close);
  });
  ref.onResume(() => timer?.cancel());

  return ref.watch(apiClientProvider).getBytes(path);
});

/// What kind of thing the bytes are, decided from the file name because that is
/// what the server decides from too (`documents.py` guesses the content type
/// from the extension, and nothing else is more reliable).
enum FileKind { image, pdf, other }

FileKind fileKindOf(String fileName) {
  final name = fileName.toLowerCase();
  if (name.endsWith('.pdf')) return FileKind.pdf;
  for (final extension in const ['.png', '.jpg', '.jpeg', '.gif', '.webp']) {
    if (name.endsWith(extension)) return FileKind.image;
  }
  return FileKind.other;
}
