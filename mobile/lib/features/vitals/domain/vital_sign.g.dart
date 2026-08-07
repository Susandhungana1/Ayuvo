// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vital_sign.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VitalSign _$VitalSignFromJson(Map<String, dynamic> json) => _VitalSign(
  id: json['id'] as String,
  systolic: (json['blood_pressure_systolic'] as num?)?.toInt(),
  diastolic: (json['blood_pressure_diastolic'] as num?)?.toInt(),
  heartRate: (json['heart_rate'] as num?)?.toInt(),
  weight: (json['weight'] as num?)?.toDouble(),
  bloodSugar: (json['blood_sugar'] as num?)?.toDouble(),
  temperature: (json['temperature'] as num?)?.toDouble(),
  oxygenSaturation: (json['oxygen_saturation'] as num?)?.toInt(),
  notes: json['notes'] as String?,
  measuredAt: json['measured_at'] as String,
  createdAt: json['created_at'] as String,
);

Map<String, dynamic> _$VitalSignToJson(_VitalSign instance) =>
    <String, dynamic>{
      'id': instance.id,
      'blood_pressure_systolic': instance.systolic,
      'blood_pressure_diastolic': instance.diastolic,
      'heart_rate': instance.heartRate,
      'weight': instance.weight,
      'blood_sugar': instance.bloodSugar,
      'temperature': instance.temperature,
      'oxygen_saturation': instance.oxygenSaturation,
      'notes': instance.notes,
      'measured_at': instance.measuredAt,
      'created_at': instance.createdAt,
    };
