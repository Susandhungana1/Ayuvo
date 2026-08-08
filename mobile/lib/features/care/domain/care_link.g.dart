// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'care_link.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CareLink _$CareLinkFromJson(Map<String, dynamic> json) => _CareLink(
  id: json['id'] as String,
  userId: json['user_id'] as String,
  name: json['name'] as String,
  createdAt: json['created_at'] as String,
  notify: json['notify'] as bool,
  medicineCount: (json['medicine_count'] as num?)?.toInt(),
  nextDoseName: json['next_dose_name'] as String?,
  nextDoseLocal: json['next_dose_local'] as String?,
  nextDoseIsToday: json['next_dose_is_today'] as bool?,
  nextDoseTimezone: json['next_dose_timezone'] as String?,
);

Map<String, dynamic> _$CareLinkToJson(_CareLink instance) => <String, dynamic>{
  'id': instance.id,
  'user_id': instance.userId,
  'name': instance.name,
  'created_at': instance.createdAt,
  'notify': instance.notify,
  'medicine_count': instance.medicineCount,
  'next_dose_name': instance.nextDoseName,
  'next_dose_local': instance.nextDoseLocal,
  'next_dose_is_today': instance.nextDoseIsToday,
  'next_dose_timezone': instance.nextDoseTimezone,
};

_CareInvite _$CareInviteFromJson(Map<String, dynamic> json) => _CareInvite(
  code: json['code'] as String,
  expiresAt: json['expires_at'] as String,
);

Map<String, dynamic> _$CareInviteToJson(_CareInvite instance) =>
    <String, dynamic>{'code': instance.code, 'expires_at': instance.expiresAt};
