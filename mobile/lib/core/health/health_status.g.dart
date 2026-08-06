// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_HealthStatus _$HealthStatusFromJson(Map<String, dynamic> json) =>
    _HealthStatus(
      status: json['status'] as String,
      database: json['database'] as bool,
      email: json['email'] as String,
      caretaker: json['caretaker'] as bool,
    );

Map<String, dynamic> _$HealthStatusToJson(_HealthStatus instance) =>
    <String, dynamic>{
      'status': instance.status,
      'database': instance.database,
      'email': instance.email,
      'caretaker': instance.caretaker,
    };
