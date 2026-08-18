// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'share_link.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ShareLink _$ShareLinkFromJson(Map<String, dynamic> json) => _ShareLink(
  token: json['token'] as String,
  reportId: json['report_id'] as String,
  expiresAt: json['expires_at'] as String,
  pin: json['pin'] as String?,
);

Map<String, dynamic> _$ShareLinkToJson(_ShareLink instance) =>
    <String, dynamic>{
      'token': instance.token,
      'report_id': instance.reportId,
      'expires_at': instance.expiresAt,
      'pin': instance.pin,
    };

_ShareGrant _$ShareGrantFromJson(Map<String, dynamic> json) => _ShareGrant(
  token: json['token'] as String,
  expiresAt: json['expires_at'] as String,
  pin: json['pin'] as String?,
);

Map<String, dynamic> _$ShareGrantToJson(_ShareGrant instance) =>
    <String, dynamic>{
      'token': instance.token,
      'expires_at': instance.expiresAt,
      'pin': instance.pin,
    };
