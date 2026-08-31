/// Build-time configuration.
///
/// Nothing here is a secret and nothing here is a user's data: the only knob is
/// which Ayuvo backend to talk to, supplied at build time.
///
/// Production is the default for iOS and web. For local dev, pass:
///   flutter run --dart-define=API_BASE_URL=http://127.0.0.1:3001
library;

abstract final class Env {
  /// Set with `--dart-define=API_BASE_URL=...`. Empty means "use platform default".
  static const String _override = String.fromEnvironment('API_BASE_URL');

  /// Where the Next.js app lives, for the two links that must open in a
  /// browser: a share link and an emergency ID. Both are read by someone who
  /// does not have this app — a doctor handed a QR, a paramedic scanning a
  /// wallet card — so they point at `front/`, never at a deep link.
  static const String _webOverride = String.fromEnvironment('WEB_BASE_URL');

  /// The production API.  The hostname is *not* derivable from render.yaml —
  /// Render appended a random suffix when the service was created.  A wrong
  /// hostname resolves via wildcard and hangs instead of failing fast.
  static const String _production = 'https://medistore-api-vwyr.onrender.com';

  static String get apiBaseUrl {
    if (_override.isNotEmpty) {
      final url = _stripTrailingSlash(_override);
      assert(
        url.startsWith('https://') || url.contains('127.0.0.1') || url.contains('localhost') || url.contains('10.0.2.2'),
        'Production API_BASE_URL must be https:// — cleartext http is debug only',
      );
      return url;
    }
    // Production by default — real Android devices must hit the live API.
    // For the Android emulator use: --dart-define=API_BASE_URL=http://10.0.2.2:3001
    // (10.0.2.2 is the emulator's alias for the host; it is unreachable on a real device).
    return _production;
  }

  static const String _productionWeb = 'https://ayuvo-health.vercel.app';

  static String get webBaseUrl => _webOverride.isEmpty
      ? _productionWeb
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
