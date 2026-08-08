// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_hit.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SearchHit _$SearchHitFromJson(Map<String, dynamic> json) => _SearchHit(
  type: json['type'] as String,
  id: json['id'] as String,
  title: json['title'] as String,
  snippet: json['snippet'] as String?,
  date: json['date'] as String?,
);

Map<String, dynamic> _$SearchHitToJson(_SearchHit instance) =>
    <String, dynamic>{
      'type': instance.type,
      'id': instance.id,
      'title': instance.title,
      'snippet': instance.snippet,
      'date': instance.date,
    };

_SearchResults _$SearchResultsFromJson(Map<String, dynamic> json) =>
    _SearchResults(
      query: json['query'] as String,
      results: (json['results'] as List<dynamic>)
          .map((e) => SearchHit.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
    );

Map<String, dynamic> _$SearchResultsToJson(_SearchResults instance) =>
    <String, dynamic>{
      'query': instance.query,
      'results': instance.results,
      'total': instance.total,
    };
