/// Search as you type, without a request per keystroke.
///
/// `GET /api/search` scans three tables in Python with no index behind it, so
/// firing one off per character would be both slow and rude. The query is
/// debounced and the in-flight result for a stale query is discarded — typing
/// "asp" then "aspirin" must never end up showing the answer to "asp" because
/// it came back second.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../data/search_repository.dart';
import '../domain/search_hit.dart';

/// Long enough to cover ordinary typing, short enough not to feel laggy.
const searchDebounce = Duration(milliseconds: 350);

/// What is in the box right now. Separate from the results so the field never
/// waits on a request to render what was typed.
final searchQueryProvider = NotifierProvider<SearchQuery, String>(SearchQuery.new);

class SearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;

  void clear() => state = '';
}

final searchResultsProvider =
    AsyncNotifierProvider<SearchResultsController, SearchResults>(
  SearchResultsController.new,
);

class SearchResultsController extends AsyncNotifier<SearchResults> {
  /// Bumped on every query change. The completion of an older request finds a
  /// stale token and drops its own answer on the floor.
  int _generation = 0;

  @override
  Future<SearchResults> build() async {
    final query = ref.watch(searchQueryProvider).trim();
    if (ref.watch(currentUserProvider) == null || query.isEmpty) {
      return SearchResults.empty;
    }

    final token = ++_generation;

    // `ref.watch` rebuilds this on the very next keystroke, and the debounce
    // means the abandoned build never reaches the network. A Timer would need
    // cancelling; a plain delay plus the generation check does not.
    await Future<void>.delayed(searchDebounce);
    if (token != _generation) return state.valueOrNull ?? SearchResults.empty;

    final results = await ref.read(searchRepositoryProvider).find(query);
    if (token != _generation) return state.valueOrNull ?? SearchResults.empty;
    return results;
  }

  /// Re-runs the current query after a failure.
  Future<void> retry() async {
    ref.invalidateSelf();
    await future;
  }
}
