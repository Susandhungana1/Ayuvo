// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'emergency_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EmergencyProfile _$EmergencyProfileFromJson(Map<String, dynamic> json) =>
    _EmergencyProfile(
      bloodType: json['blood_type'] as String?,
      allergies: json['allergies'] as String?,
      medicalConditions: json['medical_conditions'] as String?,
      contacts:
          (json['emergency_contacts'] as List<dynamic>?)
              ?.map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <EmergencyContact>[],
    );

Map<String, dynamic> _$EmergencyProfileToJson(_EmergencyProfile instance) =>
    <String, dynamic>{
      'blood_type': instance.bloodType,
      'allergies': instance.allergies,
      'medical_conditions': instance.medicalConditions,
      'emergency_contacts': instance.contacts,
    };

_EmergencyContact _$EmergencyContactFromJson(Map<String, dynamic> json) =>
    _EmergencyContact(
      id: json['id'] as String,
      name: json['name'] as String,
      relationship: json['relationship'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String?,
    );

Map<String, dynamic> _$EmergencyContactToJson(_EmergencyContact instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'relationship': instance.relationship,
      'phone': instance.phone,
      'email': instance.email,
    };
