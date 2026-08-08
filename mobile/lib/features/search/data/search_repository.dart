/// `GET /api/search`.
///
/// `q` has `min_length=1`, so an empty query is a 422 rather than an empty
/// result. The repository answers it locally instead of asking — a screen with
/// a cleared search box should show its prompt, not an error.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/network/scoped_url.dart';
import '../domain/search_hit.dart';

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SearchRepository(ref.watch(apiClientProvider)),
);

class SearchRepository {
  const SearchRepository(this._client);

  final ApiClient _client;

  Future<SearchResults> find(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return SearchResults.empty;

    final json = await _client.get<Map<String, dynamic>>(
      // Through ScopedUrl for the encoding, not for the scoping: a query can
      // contain `#`, `&` or a space, and interpolating one raw truncates the
      // search silently.
      ScopedUrl.build('/api/search', query: {'q': trimmed}),
    );
    return SearchResults.fromJson(json);
  }
}
