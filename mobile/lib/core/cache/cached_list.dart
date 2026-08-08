/// The stale-while-revalidate read, written once.
///
/// Two controllers use it, and the sequencing is fiddly enough that having two
/// copies would mean having two behaviours:
///
///   * saved rows exist → return them **now**, fetch in the background, and
///     replace the state when the answer lands;
///   * no saved rows → wait for the fetch, like any other screen;
///   * the background fetch fails → keep the saved rows and record *why*, so
///     the screen can say "this is from an hour ago" instead of quietly
///     showing stale data as though it were current.
///
/// Nothing here writes to another provider during a build: the only calls into
/// [CacheStatusController] happen in the revalidation continuation, which by
/// definition runs after the notifier has finished building.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'offline_cache.dart';

/// Loads [name], preferring saved rows and correcting them behind the user.
///
/// [publish] is how the corrected list reaches the notifier's `state`; it is
/// only called when [alive] still returns true, because a controller disposed
/// mid-flight (sign-out, a tab thrown away) must not be written to.
Future<List<T>> loadWithCache<T>({
  required OfflineCache cache,
  required CacheStatusController status,
  required String name,
  required Future<List<T>> Function() fetch,
  required T Function(Map<String, dynamic>) decode,
  required Map<String, dynamic> Function(T) encode,
  required void Function(List<T>) publish,
  required bool Function() alive,
}) async {
  if (!cache.enabled) return fetch();

  final saved = await cache.read(name);
  final rows = saved == null ? null : _decodeAll(saved.rows, decode, name);

  if (rows == null || rows.isEmpty) {
    // Nothing usable saved. This is the ordinary path, and a failure here is a
    // real error the screen should show — there is nothing to fall back to.
    final fresh = await fetch();
    unawaited(_save(cache, name, fresh, encode));
    return fresh;
  }

  unawaited(() async {
    try {
      final fresh = await fetch();
      await _save(cache, name, fresh, encode);
      if (alive()) {
        status.live();
        publish(fresh);
      }
    } catch (error) {
      // The saved rows stay on screen. Recording the failure is what turns
      // "silently out of date" into "out of date, and it says so".
      debugPrint('Revalidating $name failed: $error');
      if (alive()) status.servedFromCache(saved!.savedAt, error);
    }
  }());

  return rows;
}

Future<void> _save<T>(
  OfflineCache cache,
  String name,
  List<T> items,
  Map<String, dynamic> Function(T) encode,
) =>
    cache.write(name, [for (final item in items) encode(item)]);

/// A row the current models cannot read is dropped, not thrown. The cache is
/// written by whatever version of the app was installed last; an upgrade that
/// renamed a field should cost a network round trip, not a crash on launch.
List<T>? _decodeAll<T>(
  List<Map<String, dynamic>> rows,
  T Function(Map<String, dynamic>) decode,
  String name,
) {
  try {
    return [for (final row in rows) decode(row)];
  } catch (error) {
    debugPrint('Cached $name could not be decoded ($error); ignoring it.');
    return null;
  }
}
