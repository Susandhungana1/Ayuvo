/// The web implementation of [openSharedFile]: decodes the base64 and opens it
/// in a new tab. `dart:js_interop` and `package:web` are web-only, so this file
/// is only compiled on the web target — the conditional import in
/// `shared_file_viewer.dart` swaps in the stub everywhere else.
library;

import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

String? openSharedFile(String base64, String fileName) {
  try {
    final bytes = base64Decode(base64);
    final lower = fileName.toLowerCase();
    final String mimeType;
    if (lower.endsWith('.pdf')) {
      mimeType = 'application/pdf';
    } else if (lower.endsWith('.png')) {
      mimeType = 'image/png';
    } else if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      mimeType = 'image/jpeg';
    } else {
      mimeType = 'application/octet-stream';
    }
    if (!kIsWeb) {
      return 'The original file can only be opened on the web version.';
    }
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    web.window.open(url, '_blank');
    return null;
  } catch (_) {
    return 'The original file could not be opened.';
  }
}
