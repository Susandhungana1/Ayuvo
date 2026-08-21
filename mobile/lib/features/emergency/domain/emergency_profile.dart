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
    String? name,
    @JsonKey(name: 'blood_type') String? bloodType,
    @JsonKey(name: 'emergency_contacts')
    @Default(<EmergencyContact>[])
    List<EmergencyContact> contacts,
  }) = _EmergencyProfile;

  const EmergencyProfile._();

  factory EmergencyProfile.fromJson(Map<String, dynamic> json) =>
      _$EmergencyProfileFromJson(json);

  bool get hasBloodType => bloodType?.trim().isNotEmpty ?? false;

  /// Whether the card would say anything at all. An empty emergency ID is
  /// worse than none: the all-reports share QR would promise information and
  /// deliver a blank card to whoever scans it.
  bool get isEmpty => !hasBloodType && contacts.isEmpty;
}

@freezed
abstract class EmergencyContact with _$EmergencyContact {
  const factory EmergencyContact({
    required String id,
    required String name,
    required String phone,
  }) = _EmergencyContact;

  const EmergencyContact._();

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      _$EmergencyContactFromJson(json);
}
