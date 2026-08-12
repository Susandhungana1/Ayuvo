/// Opens a shared report's original file from a base64 blob.
///
/// The share API returns `file_content` as base64. Only the web build can open
/// it (a Blob needs a DOM); a native build gets an honest "web only" answer
/// rather than silence. Picked by conditional import, the same trick
/// `web_reminders.dart` uses so the VM test target never compiles `package:web`.
library;

import 'shared_file_viewer_stub.dart'
    if (dart.library.js_interop) 'shared_file_viewer_web.dart'
    as impl;

/// Decodes [base64] and opens it in a new tab. Returns a reason string when the
/// file cannot be opened; null on success.
String? openSharedFile(String base64, String fileName) =>
    impl.openSharedFile(base64, fileName);
