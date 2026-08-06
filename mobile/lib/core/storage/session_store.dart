/// Where the session token lives.
///
/// The JWT is a bearer credential for a health record, so it goes in the
/// platform keystore — never SharedPreferences, never a plain file. The store
/// deals in opaque strings and knows nothing about what is inside them.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SessionStore {
  /// The stored session blob, or null when nobody is signed in.
  Future<String?> read();

  Future<void> write(String value);

  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  const SecureSessionStore([
    this._storage = const FlutterSecureStorage(
      // resetOnError: a keystore entry can end up undecryptable after an OEM
      // backup restore. Clearing it costs a sign-in; throwing would mean an app
      // that can never sign in again without a reinstall.
      aOptions: AndroidOptions(resetOnError: true),
      // Readable after the first unlock (so a scheduled reminder can still fire
      // before the user opens the phone), and never copied to another device.
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
      mOptions: MacOsOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    ),
  ]);

  static const _key = 'medistore.session.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } on PlatformException catch (error) {
      // Corrupt or inaccessible keystore. Treat it as "signed out" rather than
      // crashing on launch, and make sure the bad entry goes away.
      debugPrint('Secure storage unreadable (${error.code}); signing out.');
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } on PlatformException catch (error) {
      debugPrint('Secure storage delete failed (${error.code}).');
    }
  }
}

/// For tests and for a widget preview — never wired into a real build.
class InMemorySessionStore implements SessionStore {
  InMemorySessionStore([this._value]);

  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String value) async => _value = value;

  @override
  Future<void> clear() async => _value = null;
}
