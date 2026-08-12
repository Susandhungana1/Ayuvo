// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medicine.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Medicine _$MedicineFromJson(Map<String, dynamic> json) => _Medicine(
  id: json['id'] as String,
  name: json['name'] as String,
  dosage: json['dosage'] as String,
  frequency: json['frequency'] as String,
  startDate: json['start_date'] as String,
  endDate: json['end_date'] as String?,
  takingTimes: json['taking_times'] as String?,
  notes: json['notes'] as String?,
  createdAt: json['created_at'] as String?,
);

Map<String, dynamic> _$MedicineToJson(_Medicine instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'dosage': instance.dosage,
  'frequency': instance.frequency,
  'start_date': instance.startDate,
  'end_date': instance.endDate,
  'taking_times': instance.takingTimes,
  'notes': instance.notes,
  'created_at': instance.createdAt,
};

_DrugInteraction _$DrugInteractionFromJson(Map<String, dynamic> json) =>
    _DrugInteraction(
      drugA: json['drug_a'] as String,
      drugB: json['drug_b'] as String,
      severity: json['severity'] as String,
      description: json['description'] as String,
    );

Map<String, dynamic> _$DrugInteractionToJson(_DrugInteraction instance) =>
    <String, dynamic>{
      'drug_a': instance.drugA,
      'drug_b': instance.drugB,
      'severity': instance.severity,
      'description': instance.description,
    };

_InteractionCheck _$InteractionCheckFromJson(Map<String, dynamic> json) =>
    _InteractionCheck(
      interactions: (json['interactions'] as List<dynamic>)
          .map((e) => DrugInteraction.fromJson(e as Map<String, dynamic>))
          .toList(),
      checkedCount: (json['checked_count'] as num).toInt(),
    );

Map<String, dynamic> _$InteractionCheckToJson(_InteractionCheck instance) =>
    <String, dynamic>{
      'interactions': instance.interactions,
      'checked_count': instance.checkedCount,
    };

_MedicineIntake _$MedicineIntakeFromJson(Map<String, dynamic> json) =>
    _MedicineIntake(
      id: json['id'] as String,
      medicineId: json['medicine_id'] as String,
      scheduledTime: json['scheduled_time'] as String,
      status: json['status'] as String,
      recordedAt: json['recorded_at'] as String,
    );

Map<String, dynamic> _$MedicineIntakeToJson(_MedicineIntake instance) =>
    <String, dynamic>{
      'id': instance.id,
      'medicine_id': instance.medicineId,
      'scheduled_time': instance.scheduledTime,
      'status': instance.status,
      'recorded_at': instance.recordedAt,
    };

_MedicineAuditEntry _$MedicineAuditEntryFromJson(Map<String, dynamic> json) =>
    _MedicineAuditEntry(
      id: (json['id'] as num).toInt(),
      actorId: json['actor_id'] as String,
      actorName: json['actor_name'] as String,
      medicineId: json['medicine_id'] as String?,
      medicineName: json['medicine_name'] as String?,
      action: json['action'] as String,
      createdAt: json['created_at'] as String,
      byCaretaker: json['by_caretaker'] as bool,
    );

Map<String, dynamic> _$MedicineAuditEntryToJson(_MedicineAuditEntry instance) =>
    <String, dynamic>{
      'id': instance.id,
      'actor_id': instance.actorId,
      'actor_name': instance.actorName,
      'medicine_id': instance.medicineId,
      'medicine_name': instance.medicineName,
      'action': instance.action,
      'created_at': instance.createdAt,
      'by_caretaker': instance.byCaretaker,
    };
