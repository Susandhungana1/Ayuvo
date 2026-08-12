/// `GET /api/timeline`, and the only place its URL appears.
///
/// The server builds the whole timeline in Python — four unbounded selects,
/// concatenated, sorted, then sliced — so `limit` bounds what crosses the wire
/// but not what the database reads. Keep the page modest and do not treat this
/// as a cheap call.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/network/scoped_url.dart';
import '../domain/timeline_event.dart';

final timelineRepositoryProvider = Provider<TimelineRepository>(
  (ref) => TimelineRepository(ref.watch(apiClientProvider)),
);

class TimelineRepository {
  const TimelineRepository(this._client);

  final ApiClient _client;

  /// `limit` is capped at 200 server-side (`le=200`); anything larger is a 422,
  /// so the caller's page size is clamped here rather than trusted.
  Future<TimelinePage> page({int limit = 50, int offset = 0}) async {
    final json = await _client.get<Map<String, dynamic>>(
      ScopedUrl.build(
        '/api/timeline',
        query: {'limit': limit.clamp(1, 200), 'offset': offset},
      ),
    );
    return TimelinePage.fromJson(json);
  }
}
