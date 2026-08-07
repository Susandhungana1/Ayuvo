/// Build-time configuration.
///
/// Nothing here is a secret and nothing here is a user's data: the only knob is
/// which MediStore backend to talk to, supplied at build time.
///
///   flutter run --dart-define=API_BASE_URL=http://127.0.0.1:3001
///   flutter build apk --dart-define=API_BASE_URL=https://medistore-api-vwyr.onrender.com
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

abstract final class Env {
  /// Set with `--dart-define=API_BASE_URL=...`. Empty means "use local dev".
  static const String _override = String.fromEnvironment('API_BASE_URL');

  /// Where the Next.js app lives, for the two links that must open in a
  /// browser: a share link and an emergency ID. Both are read by someone who
  /// does not have this app — a doctor handed a QR, a paramedic scanning a
  /// wallet card — so they point at `front/`, never at a deep link.
  ///
  /// The server knows this value as `FRONTEND_URL` and does not publish it, so
  /// the client carries its own copy. `BACKEND_NOTES.md` proposes adding it to
  /// `/health` in phase 7; until then a build for a real deployment must pass
  /// `--dart-define=WEB_BASE_URL=https://…` or the QR will point at localhost.
  static const String _webOverride = String.fromEnvironment('WEB_BASE_URL');

  /// A desktop or iOS simulator shares the host's loopback.
  static const String _localhost = 'http://127.0.0.1:3001';

  /// The Android emulator does not: 10.0.2.2 is its alias for the host.
  /// Getting this wrong looks like "the server is down" on one device only, so
  /// the default picks it rather than making every run pass a dart-define.
  static const String _androidEmulator = 'http://10.0.2.2:3001';

  /// `npm run dev` in `front/`. Not 10.0.2.2: unlike the API, nothing in this
  /// app fetches this origin — it is printed, copied and encoded into a QR for
  /// someone else's browser, and an emulator alias is meaningless there.
  static const String _localWeb = 'http://localhost:3000';

  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _stripTrailingSlash(_override);
    if (!kIsWeb && Platform.isAndroid) return _androidEmulator;
    return _localhost;
  }

  static String get webBaseUrl => _webOverride.isEmpty
      ? _localWeb
      : _stripTrailingSlash(_webOverride);

  /// A share or emergency URL, with the path segment encoded. User ids contain
  /// `#`, which is a fragment delimiter: interpolated raw, everything after it
  /// is dropped before the request is ever made.
  static String webLink(String path, String segment) =>
      '$webBaseUrl/$path/${Uri.encodeComponent(segment)}';

  /// True when the app is pointed at a developer machine. Used to decide
  /// whether showing the base URL on screen is helpful or just noise.
  static bool get isLocal =>
      apiBaseUrl.contains('127.0.0.1') ||
      apiBaseUrl.contains('localhost') ||
      apiBaseUrl.contains('10.0.2.2');

  static String _stripTrailingSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}
