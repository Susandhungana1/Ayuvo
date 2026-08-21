// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'emergency_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EmergencyProfile _$EmergencyProfileFromJson(Map<String, dynamic> json) =>
    _EmergencyProfile(
      name: json['name'] as String?,
      bloodType: json['blood_type'] as String?,
      contacts:
          (json['emergency_contacts'] as List<dynamic>?)
              ?.map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <EmergencyContact>[],
    );

Map<String, dynamic> _$EmergencyProfileToJson(_EmergencyProfile instance) =>
    <String, dynamic>{
      'name': instance.name,
      'blood_type': instance.bloodType,
      'emergency_contacts': instance.contacts,
    };

_EmergencyContact _$EmergencyContactFromJson(Map<String, dynamic> json) =>
    _EmergencyContact(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
    );

Map<String, dynamic> _$EmergencyContactToJson(_EmergencyContact instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'phone': instance.phone,
    };
