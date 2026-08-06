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

  /// A desktop or iOS simulator shares the host's loopback.
  static const String _localhost = 'http://127.0.0.1:3001';

  /// The Android emulator does not: 10.0.2.2 is its alias for the host.
  /// Getting this wrong looks like "the server is down" on one device only, so
  /// the default picks it rather than making every run pass a dart-define.
  static const String _androidEmulator = 'http://10.0.2.2:3001';

  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _stripTrailingSlash(_override);
    if (!kIsWeb && Platform.isAndroid) return _androidEmulator;
    return _localhost;
  }

  /// True when the app is pointed at a developer machine. Used to decide
  /// whether showing the base URL on screen is helpful or just noise.
  static bool get isLocal =>
      apiBaseUrl.contains('127.0.0.1') ||
      apiBaseUrl.contains('localhost') ||
      apiBaseUrl.contains('10.0.2.2');

  static String _stripTrailingSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}
