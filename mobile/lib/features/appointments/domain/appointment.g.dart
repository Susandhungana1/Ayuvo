// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'appointment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Appointment _$AppointmentFromJson(Map<String, dynamic> json) => _Appointment(
  id: json['id'] as String,
  title: json['title'] as String,
  description: json['description'] as String?,
  doctorId: json['doctor_id'] as String?,
  doctorName: json['doctor_name'] as String?,
  hospital: json['hospital'] as String?,
  appointmentDate: json['appointment_date'] as String,
  durationMinutes: (json['duration_minutes'] as num).toInt(),
  status: json['status'] as String,
  reason: json['reason'] as String?,
  reminderSent: json['reminder_sent'] as bool? ?? false,
);

Map<String, dynamic> _$AppointmentToJson(_Appointment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'doctor_id': instance.doctorId,
      'doctor_name': instance.doctorName,
      'hospital': instance.hospital,
      'appointment_date': instance.appointmentDate,
      'duration_minutes': instance.durationMinutes,
      'status': instance.status,
      'reason': instance.reason,
      'reminder_sent': instance.reminderSent,
    };

_AppointmentSlot _$AppointmentSlotFromJson(Map<String, dynamic> json) =>
    _AppointmentSlot(
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
    );

Map<String, dynamic> _$AppointmentSlotToJson(_AppointmentSlot instance) =>
    <String, dynamic>{
      'start_time': instance.startTime,
      'end_time': instance.endTime,
    };
