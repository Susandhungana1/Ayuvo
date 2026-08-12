/// Reading the expiry out of the session token.
///
/// The signature is **not** verified here and must never be trusted: only the
/// server can do that. This exists so the app can tell, at launch and offline,
/// that a seven-day token has already run out — and send the user to sign-in
/// with a reason instead of to a screen that will 401 on its first request.
library;

import 'dart:convert';

/// The `exp` claim as a UTC instant, or null if the token can't be read.
DateTime? jwtExpiry(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (payload is! Map) return null;
    final exp = payload['exp'];
    if (exp is! int) return null;
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
  } on FormatException {
    return null;
  }
}

/// True only when the token is provably past its expiry.
///
/// An unreadable token answers false on purpose: the server is the authority,
/// and signing someone out over a parsing quirk of ours would be worse than
/// letting one request come back 401.
bool isTokenExpired(
  String token, {
  Duration leeway = const Duration(seconds: 30),
  DateTime? now,
}) {
  final expiry = jwtExpiry(token);
  if (expiry == null) return false;
  return (now ?? DateTime.now().toUtc()).isAfter(expiry.subtract(leeway));
}
