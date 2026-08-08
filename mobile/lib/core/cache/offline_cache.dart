/// The offline read path: show what we had, then go and check.
///
/// Replaces `front/lib/offlineCache.ts`. A phone loses signal in a lift, on a
/// bus, in a hospital basement — the three places somebody actually needs to
/// know what they take at eight. The rule is stale-while-revalidate: a screen
/// renders the saved rows immediately, a request goes out anyway, and the
/// screen is corrected when it lands. If it never lands, the saved rows stay
/// and the screen says so rather than pretending they are current.
///
/// **Two rules this file exists to enforce.**
///
///  1. **Never another person's data.** A caretaker reads a patient's medicines
///     through a link the patient can revoke at any moment; a copy on the
///     caretaker's disk would outlive the permission that justified it.
///     `front/components/medicine-manager.tsx` skips its cache whenever
///     `patientId` is set, and [scopedIsNeverCached] is the same rule with a
///     name. Ask for a scoped cache here and you get a no-op, not a file.
///  2. **One owner per entry.** Every envelope records the user id it was
///     written for. Sign out, sign in as somebody else, and their read finds a
///     foreign owner and deletes the file instead of rendering it.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/session_controller.dart';
import '../storage/local_store.dart';

/// What came back from the cache, and when it was true.
class CachedRows {
  const CachedRows({required this.rows, required this.savedAt});

  final List<Map<String, dynamic>> rows;
  final DateTime savedAt;
}

/// Documented as a constant so the reason survives a refactor that moves the
/// check: scoping a cache entry to a patient is not supported, at all.
const scopedIsNeverCached = true;

class OfflineCache {
  const OfflineCache(this._store, {required this.owner});

  final LocalStore _store;

  /// The signed-in user's id. Null means nobody is, and the cache is inert.
  final String? owner;

  bool get enabled => owner != null;

  /// Saved rows for [name], or null when there are none, they belong to
  /// somebody else, or the file is unreadable.
  Future<CachedRows?> read(String name) async {
    if (owner == null) return null;

    final envelope = decodeJsonObject(await _store.read(_file(name)));
    if (envelope == null) return null;

    // A file written for a different account is not a cache miss to shrug at —
    // it is somebody else's health data sitting on this disk. Delete it.
    if (envelope['owner'] != owner) {
      await _store.delete(_file(name));
      return null;
    }

    final rows = envelope['rows'];
    final savedAt = DateTime.tryParse('${envelope['saved_at']}');
    if (rows is! List || savedAt == null) return null;

    return CachedRows(
      rows: [
        for (final row in rows)
          if (row is Map<String, dynamic>) row,
      ],
      savedAt: savedAt.toLocal(),
    );
  }

  /// Replaces the saved rows for [name]. Silently does nothing when nobody is
  /// signed in, so a write racing a sign-out cannot leave a file behind.
  Future<void> write(String name, List<Map<String, dynamic>> rows) async {
    final id = owner;
    if (id == null) return;
    await _store.write(
      _file(name),
      jsonEncode({
        'owner': id,
        'saved_at': DateTime.now().toUtc().toIso8601String(),
        'rows': rows,
      }),
    );
  }

  Future<void> forget(String name) => _store.delete(_file(name));

  /// Every cache entry, on sign-out. The next account starts with an empty
  /// disk rather than relying on the owner check alone.
  ///
  /// Only entries under [filePrefix] — the language and theme a person chose
  /// are not theirs to lose because they signed out.
  Future<void> clear() => _store.clearPrefix(filePrefix);

  /// Marks a key as belonging to this cache. Public because the session
  /// controller clears the cache on sign-out and cannot read
  /// [offlineCacheProvider] to do it: that provider watches the session, and
  /// the dependency would be a cycle.
  static const filePrefix = 'cache.';

  /// Versioned: a shape change bumps the suffix rather than trying to migrate
  /// rows whose only value is that they save one request.
  static String _file(String name) => '$filePrefix$name.v1';
}

/// The cache, bound to whoever is signed in right now.
///
/// Watching the session is what makes rule 2 hold without any screen having to
/// remember it: sign out and this rebuilds with a null owner, so every read
/// misses and every write is dropped.
final offlineCacheProvider = Provider<OfflineCache>((ref) {
  final user = ref.watch(currentUserProvider);
  return OfflineCache(ref.watch(localStoreProvider), owner: user?.id);
});

/// Named cache entries. A screen never invents a string.
abstract final class CacheKeys {
  /// The signed-in user's own medicines. There is deliberately no key that
  /// takes a patient id — see [scopedIsNeverCached].
  static const medicines = 'medicines';

  static const vitals = 'vitals';
}

/// Whether a screen is currently showing saved rows because the network could
/// not be reached, and how old they are.
class CacheStatus {
  const CacheStatus({this.savedAt, this.error});

  /// When the rows on screen were fetched. Null means they are live.
  final DateTime? savedAt;

  /// Why the revalidation failed, when it did.
  final Object? error;

  bool get isStale => savedAt != null && error != null;

  static const live = CacheStatus();
}

/// Keyed by [CacheKeys]. Written by the controllers, read by a screen that
/// wants to admit it is showing yesterday's answer.
final cacheStatusProvider =
    NotifierProvider.family<CacheStatusController, CacheStatus, String>(
  CacheStatusController.new,
);

class CacheStatusController extends FamilyNotifier<CacheStatus, String> {
  @override
  CacheStatus build(String key) => CacheStatus.live;

  void servedFromCache(DateTime savedAt, Object error) {
    state = CacheStatus(savedAt: savedAt, error: error);
  }

  void live() => state = CacheStatus.live;
}
