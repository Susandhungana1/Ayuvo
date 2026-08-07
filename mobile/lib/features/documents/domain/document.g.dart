// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MedicalDocument _$MedicalDocumentFromJson(Map<String, dynamic> json) =>
    _MedicalDocument(
      id: json['id'] as String,
      hospital: json['hospital'] as String,
      location: json['location'] as String?,
      doctorName: json['doctor_name'] as String?,
      department: json['department'] as String?,
      description: json['description'] as String?,
      checkupDate: json['checkup_date'] as String,
    );

Map<String, dynamic> _$MedicalDocumentToJson(_MedicalDocument instance) =>
    <String, dynamic>{
      'id': instance.id,
      'hospital': instance.hospital,
      'location': instance.location,
      'doctor_name': instance.doctorName,
      'department': instance.department,
      'description': instance.description,
      'checkup_date': instance.checkupDate,
    };

_DocumentFile _$DocumentFileFromJson(Map<String, dynamic> json) =>
    _DocumentFile(
      id: json['id'] as String,
      name: json['name'] as String,
      fileType: json['file_type'] as String,
    );

Map<String, dynamic> _$DocumentFileToJson(_DocumentFile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'file_type': instance.fileType,
    };
