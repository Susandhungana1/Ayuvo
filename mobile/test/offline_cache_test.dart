/// The offline cache, and the two rules it exists to keep: one owner per
/// entry, and never another person's medicines.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ayuvo/core/cache/cached_list.dart';
import 'package:ayuvo/core/cache/offline_cache.dart';
import 'package:ayuvo/core/storage/local_store.dart';

const _me = '#hos014';
const _someoneElse = '#hos099';

Map<String, dynamic> row(String id) => {'id': id};

void main() {
  group('ownership', () {
    test('rows written by one account are unreadable by another', () async {
      final store = InMemoryLocalStore();
      await OfflineCache(store, owner: _me).write('medicines', [row('a')]);

      final theirs = await OfflineCache(store, owner: _someoneElse)
          .read('medicines');

      expect(theirs, isNull);
    });

    test('a foreign entry is deleted, not just ignored', () async {
      // Refusing to render it is not enough: it is somebody else's health data
      // sitting on this disk.
      final store = InMemoryLocalStore();
      await OfflineCache(store, owner: _me).write('medicines', [row('a')]);

      await OfflineCache(store, owner: _someoneElse).read('medicines');

      expect(store.contents, isEmpty);
    });

    test('nobody signed in means the cache is inert', () async {
      final store = InMemoryLocalStore();
      final anonymous = OfflineCache(store, owner: null);
      await anonymous.write('medicines', [row('a')]);

      expect(anonymous.enabled, isFalse);
      expect(store.contents, isEmpty);
      expect(await anonymous.read('medicines'), isNull);
    });
  });

  group('reading', () {
    test('rows come back with the moment they were saved', () async {
      final cache = OfflineCache(InMemoryLocalStore(), owner: _me);
      await cache.write('medicines', [row('a'), row('b')]);

      final saved = (await cache.read('medicines'))!;

      expect(saved.rows.map((r) => r['id']), ['a', 'b']);
      expect(
        DateTime.now().difference(saved.savedAt).inSeconds,
        lessThan(5),
      );
    });

    test('a truncated file is a cache miss, not a crash', () async {
      // Half a JSON document is what a crash mid-write leaves behind.
      final store = InMemoryLocalStore({'cache.medicines.v1': '{"owner":'});

      expect(await OfflineCache(store, owner: _me).read('medicines'), isNull);
    });

    test('an envelope with no timestamp is refused', () async {
      final store = InMemoryLocalStore({
        'cache.medicines.v1': jsonEncode({'owner': _me, 'rows': [row('a')]}),
      });

      expect(await OfflineCache(store, owner: _me).read('medicines'), isNull);
    });
  });

  group('clearing', () {
    test('signing out drops the record but not the language', () async {
      final store = InMemoryLocalStore({'settings.v1': '{"locale":"ne"}'});
      final cache = OfflineCache(store, owner: _me);
      await cache.write('medicines', [row('a')]);

      await cache.clear();

      expect(store.contents.keys, ['settings.v1']);
    });
  });

  group('stale-while-revalidate', () {
    test('saved rows are returned before the network answers', () async {
      final store = InMemoryLocalStore();
      final cache = OfflineCache(store, owner: _me);
      await cache.write('medicines', [row('saved')]);

      final published = <List<String>>[];
      final first = await loadWithCache<String>(
        cache: cache,
        status: _NullStatus(),
        name: 'medicines',
        fetch: () async => ['fresh'],
        decode: (json) => json['id'] as String,
        encode: (id) => {'id': id},
        publish: published.add,
        alive: () => true,
      );

      expect(first, ['saved']);
      // The revalidation lands afterwards and corrects the screen.
      await Future<void>.delayed(Duration.zero);
      expect(published, [
        ['fresh'],
      ]);
      expect((await cache.read('medicines'))!.rows.single['id'], 'fresh');
    });

    test('with nothing saved it waits for the network like any other screen',
        () async {
      final cache = OfflineCache(InMemoryLocalStore(), owner: _me);

      final rows = await loadWithCache<String>(
        cache: cache,
        status: _NullStatus(),
        name: 'medicines',
        fetch: () async => ['fresh'],
        decode: (json) => json['id'] as String,
        encode: (id) => {'id': id},
        publish: (_) {},
        alive: () => true,
      );

      expect(rows, ['fresh']);
    });

    test('a failed first load is a real error — there is nothing to show',
        () async {
      final cache = OfflineCache(InMemoryLocalStore(), owner: _me);

      await expectLater(
        loadWithCache<String>(
          cache: cache,
          status: _NullStatus(),
          name: 'medicines',
          fetch: () async => throw StateError('offline'),
          decode: (json) => json['id'] as String,
          encode: (id) => {'id': id},
          publish: (_) {},
          alive: () => true,
        ),
        throwsStateError,
      );
    });

    test('a failed revalidation keeps the saved rows and records why',
        () async {
      final cache = OfflineCache(InMemoryLocalStore(), owner: _me);
      await cache.write('medicines', [row('saved')]);
      final status = _RecordingStatus();

      final rows = await loadWithCache<String>(
        cache: cache,
        status: status,
        name: 'medicines',
        fetch: () async => throw StateError('offline'),
        decode: (json) => json['id'] as String,
        encode: (id) => {'id': id},
        publish: (_) => fail('a failed refresh must not replace the list'),
        alive: () => true,
      );

      expect(rows, ['saved']);
      await Future<void>.delayed(Duration.zero);
      expect(status.staleAt, isNotNull);
    });

    test('a controller disposed mid-flight is never written to', () async {
      final cache = OfflineCache(InMemoryLocalStore(), owner: _me);
      await cache.write('medicines', [row('saved')]);

      await loadWithCache<String>(
        cache: cache,
        status: _NullStatus(),
        name: 'medicines',
        fetch: () async => ['fresh'],
        decode: (json) => json['id'] as String,
        encode: (id) => {'id': id},
        publish: (_) => fail('signed out — nobody is listening'),
        alive: () => false,
      );
      await Future<void>.delayed(Duration.zero);
    });

    test('rows the current models cannot read are ignored, not thrown',
        () async {
      // The cache is written by whatever version was installed last.
      final store = InMemoryLocalStore();
      final cache = OfflineCache(store, owner: _me);
      await cache.write('medicines', [
        {'renamed_field': 'a'},
      ]);

      final rows = await loadWithCache<String>(
        cache: cache,
        status: _NullStatus(),
        name: 'medicines',
        fetch: () async => ['fresh'],
        decode: (json) => json['id'] as String? ?? (throw const FormatException()),
        encode: (id) => {'id': id},
        publish: (_) {},
        alive: () => true,
      );

      expect(rows, ['fresh']);
    });
  });
}

class _NullStatus implements CacheStatusController {
  @override
  void live() {}

  @override
  void servedFromCache(DateTime savedAt, Object error) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _RecordingStatus extends _NullStatus {
  DateTime? staleAt;

  @override
  void servedFromCache(DateTime savedAt, Object error) => staleAt = savedAt;
}
