/// The web build's [LocalStore]: browser `localStorage`.
///
/// Files do not exist in a browser — every `dart:io` call throws and
/// [FileLocalStore] swallows it, which is why the reminders toggle (and any
/// other preference) silently reset on every reload of the Flutter web build.
/// `localStorage` is the browser's equivalent of "one small file per key": a
/// handful of short string values scoped to the origin, which is exactly the
/// shape this store is documented for.
library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:web/web.dart' as web;

import 'local_store.dart';

class WebLocalStore implements LocalStore {
  web.Storage? get _storage {
    try {
      return web.window.localStorage;
    } catch (error) {
      // A blocked/storage-disabled context still has to run — same deal as a
      // native device with no writable app-support directory.
      debugPrint('Local store unavailable: $error');
      return null;
    }
  }

  @override
  Future<String?> read(String key) async => _storage?.getItem(key);

  @override
  Future<void> write(String key, String value) async {
    _storage?.setItem(key, value);
  }

  @override
  Future<void> delete(String key) async {
    _storage?.removeItem(key);
  }

  @override
  Future<void> clearPrefix(String prefix) async {
    final storage = _storage;
    if (storage == null) return;
    final toRemove = <String>[];
    for (var i = 0; i < storage.length; i++) {
      final key = storage.key(i);
      if (key != null && key.startsWith(prefix)) toRemove.add(key);
    }
    for (final key in toRemove) {
      storage.removeItem(key);
    }
  }
}

/// Files on a phone, `localStorage` in a browser.
LocalStore createDefaultLocalStore() => WebLocalStore();
