/// `/api/emergency` in Dart — the handful of facts someone needs about you
/// when you cannot tell them yourself.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'emergency_profile.freezed.dart';
part 'emergency_profile.g.dart';

/// The eight groups, in the order a form should offer them.
const bloodTypes = <String>['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

@freezed
abstract class EmergencyProfile with _$EmergencyProfile {
  const factory EmergencyProfile({
    @JsonKey(name: 'blood_type') String? bloodType,
    String? allergies,
    @JsonKey(name: 'medical_conditions') String? medicalConditions,
    @JsonKey(name: 'emergency_contacts')
    @Default(<EmergencyContact>[])
    List<EmergencyContact> contacts,
  }) = _EmergencyProfile;

  const EmergencyProfile._();

  factory EmergencyProfile.fromJson(Map<String, dynamic> json) =>
      _$EmergencyProfileFromJson(json);

  bool get hasBloodType => bloodType?.trim().isNotEmpty ?? false;
  bool get hasAllergies => allergies?.trim().isNotEmpty ?? false;
  bool get hasConditions => medicalConditions?.trim().isNotEmpty ?? false;

  /// Whether the card would say anything at all. An empty emergency ID is
  /// worse than none: it is a QR that promises information and delivers a
  /// blank page to whoever scans it.
  bool get isEmpty =>
      !hasBloodType && !hasAllergies && !hasConditions && contacts.isEmpty;
}

@freezed
abstract class EmergencyContact with _$EmergencyContact {
  const factory EmergencyContact({
    required String id,
    required String name,

    /// Free text — "Wife", "Son", "Neighbour". Not an enum server-side.
    required String relationship,
    required String phone,
    String? email,
  }) = _EmergencyContact;

  const EmergencyContact._();

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      _$EmergencyContactFromJson(json);
}
