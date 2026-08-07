// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'doctor.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Doctor _$DoctorFromJson(Map<String, dynamic> json) => _Doctor(
  id: json['id'] as String,
  nmid: json['nmid'] as String,
  degree: json['degree'] as String,
  specialty: json['specialty'] as String?,
  verified: json['verified'] as bool,
  userId: json['user_id'] as String,
  name: json['name'] as String,
);

Map<String, dynamic> _$DoctorToJson(_Doctor instance) => <String, dynamic>{
  'id': instance.id,
  'nmid': instance.nmid,
  'degree': instance.degree,
  'specialty': instance.specialty,
  'verified': instance.verified,
  'user_id': instance.userId,
  'name': instance.name,
};

_AvailabilityWindow _$AvailabilityWindowFromJson(Map<String, dynamic> json) =>
    _AvailabilityWindow(
      id: json['id'] as String,
      dayOfWeek: json['day_of_week'] as String,
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      slotDurationMinutes: (json['slot_duration_minutes'] as num).toInt(),
      isAvailable: json['is_available'] as bool,
    );

Map<String, dynamic> _$AvailabilityWindowToJson(_AvailabilityWindow instance) =>
    <String, dynamic>{
      'id': instance.id,
      'day_of_week': instance.dayOfWeek,
      'start_time': instance.startTime,
      'end_time': instance.endTime,
      'slot_duration_minutes': instance.slotDurationMinutes,
      'is_available': instance.isAvailable,
    };
