/// Small, non-secret values on disk: preferences, and the offline cache.
///
/// **Not the keystore.** `SessionStore` holds a bearer credential and belongs
/// in the platform keychain; this holds "the user picked Nepali" and "here is
/// the medicine list as of an hour ago". Putting the second kind in the
/// keychain would be slow and pointless, and putting the first kind here would
/// be a bug.
///
/// One file per key under the app support directory, which is app-private on
/// both platforms and excluded from iCloud/Android auto-backup by default for
/// this location. Files rather than SharedPreferences: the cache entries are
/// JSON documents of a few kilobytes, and a preferences map is the wrong shape
/// for them. There is one storage mechanism here, not two.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

abstract interface class LocalStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);

  /// Every key beginning with [prefix].
  ///
  /// Prefix rather than "everything": signing out must drop the cached record
  /// but must **not** reset the language the user chose. Both live here, and a
  /// blanket `clear()` would quietly do the second while meaning the first.
  Future<void> clearPrefix(String prefix);
}

class FileLocalStore implements LocalStore {
  FileLocalStore({Future<Directory> Function()? directory})
      : _directory = directory ?? _appSupport;

  static const _folder = 'medistore';

  final Future<Directory> Function() _directory;

  Directory? _resolved;

  /// Asking the platform where to write is a method-channel round trip, and a
  /// channel that never answers would otherwise hold up the medicine list
  /// behind it — the cache is meant to make the app work when things are
  /// broken, not to become another thing that can break it.
  static const _lookupTimeout = Duration(seconds: 3);

  static Future<Directory> _appSupport() => getApplicationSupportDirectory();

  Future<Directory?> _folderFor() async {
    if (_resolved != null) return _resolved;
    try {
      final base = await _directory().timeout(_lookupTimeout);
      final dir = Directory('${base.path}/$_folder');
      if (!dir.existsSync()) await dir.create(recursive: true);
      return _resolved = dir;
    } catch (error) {
      // A device with no writable app support directory still has to run: the
      // cache is an optimisation and the preferences have defaults.
      debugPrint('Local store unavailable: $error');
      return null;
    }
  }

  /// `medicines.v1` → `medicines.v1.json`. Keys are internal constants, but
  /// anything that could climb out of the folder is refused rather than
  /// sanitised — a silently renamed key is harder to debug than a thrown one.
  File? _fileFor(Directory dir, String key) {
    if (key.isEmpty || key.contains('/') || key.contains('..')) {
      throw ArgumentError.value(key, 'key', 'must be a bare file-safe name');
    }
    return File('${dir.path}/$key.json');
  }

  @override
  Future<String?> read(String key) async {
    final dir = await _folderFor();
    if (dir == null) return null;
    try {
      final file = _fileFor(dir, key)!;
      return file.existsSync() ? await file.readAsString() : null;
    } on FileSystemException catch (error) {
      debugPrint('Local store read failed for $key: ${error.message}');
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    final dir = await _folderFor();
    if (dir == null) return;
    try {
      await _fileFor(dir, key)!.writeAsString(value, flush: true);
    } on FileSystemException catch (error) {
      debugPrint('Local store write failed for $key: ${error.message}');
    }
  }

  @override
  Future<void> delete(String key) async {
    final dir = await _folderFor();
    if (dir == null) return;
    try {
      final file = _fileFor(dir, key)!;
      if (file.existsSync()) await file.delete();
    } on FileSystemException catch (error) {
      debugPrint('Local store delete failed for $key: ${error.message}');
    }
  }

  @override
  Future<void> clearPrefix(String prefix) async {
    final dir = await _folderFor();
    if (dir == null || !dir.existsSync()) return;
    try {
      for (final entity in dir.listSync()) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (entity is File && name.startsWith(prefix)) await entity.delete();
      }
    } on FileSystemException catch (error) {
      debugPrint('Local store clear failed: ${error.message}');
    }
  }
}

/// For tests, and for the design gallery. Never wired into a real build.
class InMemoryLocalStore implements LocalStore {
  InMemoryLocalStore([Map<String, String>? seed])
      : _values = {...?seed};

  final Map<String, String> _values;

  Map<String, String> get contents => Map.unmodifiable(_values);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<void> clearPrefix(String prefix) async =>
      _values.removeWhere((key, _) => key.startsWith(prefix));
}

final localStoreProvider = Provider<LocalStore>((ref) => FileLocalStore());

/// Reads a JSON object, tolerating a file written by an older version or
/// truncated by a crash mid-write. Corrupt input is a cache miss, never a
/// crash on launch.
Map<String, dynamic>? decodeJsonObject(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : null;
  } on FormatException {
    return null;
  }
}
