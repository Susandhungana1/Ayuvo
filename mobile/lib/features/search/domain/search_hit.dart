/// `GET /api/search` in Dart.
///
/// The server does a case-insensitive substring scan over three tables and
/// returns them grouped by kind, in scan order. There is no ranking and no
/// pagination, so what arrives is the whole answer — which is why the screen
/// groups rather than paginates.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/time/medi_time.dart';

part 'search_hit.freezed.dart';
part 'search_hit.g.dart';

enum SearchKind { report, medicine, document, other }

@freezed
abstract class SearchHit with _$SearchHit {
  const factory SearchHit({
    required String type,
    required String id,
    required String title,

    /// Truncated to 200 characters server-side, with no ellipsis and no regard
    /// for word boundaries — so it can stop mid-word. Rendered as-is: adding
    /// an ellipsis the server did not send would imply the app knows there is
    /// more, and for a summary exactly 200 characters long it would be wrong.
    String? snippet,

    /// Naive UTC, or absent.
    String? date,
  }) = _SearchHit;

  const SearchHit._();

  factory SearchHit.fromJson(Map<String, dynamic> json) =>
      _$SearchHitFromJson(json);

  DateTime? get when => MediTime.parseUtc(date);

  SearchKind get kind => switch (type) {
        'report' => SearchKind.report,
        'medicine' => SearchKind.medicine,
        'document' => SearchKind.document,
        _ => SearchKind.other,
      };

  String get rowKey => '$type-$id';
}

@freezed
abstract class SearchResults with _$SearchResults {
  const factory SearchResults({
    required String query,
    required List<SearchHit> results,
    required int total,
  }) = _SearchResults;

  const SearchResults._();

  factory SearchResults.fromJson(Map<String, dynamic> json) =>
      _$SearchResultsFromJson(json);

  static const empty = SearchResults(query: '', results: [], total: 0);

  List<SearchHit> of(SearchKind kind) =>
      [for (final hit in results) if (hit.kind == kind) hit];
}
