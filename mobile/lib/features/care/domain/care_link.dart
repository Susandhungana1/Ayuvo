/// `/api/care/*` in Dart.
///
/// A care link is a relationship, not a permission list: the permission it
/// grants — medicines, and only medicines — is enforced by
/// `resolve_medicine_scope` on the server. Nothing in this file widens it.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/time/medi_time.dart';

part 'care_link.freezed.dart';
part 'care_link.g.dart';

@freezed
abstract class CareLink with _$CareLink {
  const factory CareLink({
    required String id,

    /// The **other** party's account id: the caretaker when listing as a
    /// patient, the patient when listing as a caretaker. This is the value that
    /// becomes `?patient_id=` — and it contains a `#`, so it only ever reaches
    /// a URL through `ScopedUrl`.
    @JsonKey(name: 'user_id') required String userId,
    required String name,

    /// Carries a real `Z` — it goes through `app/core/care.py::utc_iso`.
    @JsonKey(name: 'created_at') required String createdAt,
    required bool notify,

    // Populated for role=caretaker only.
    @JsonKey(name: 'medicine_count') int? medicineCount,
    @JsonKey(name: 'next_dose_name') String? nextDoseName,

    /// **The patient's own wall clock**, e.g. `"08:00"`. Deliberately not an
    /// instant. Parsing it into a `DateTime` would re-express it in the
    /// caretaker's zone and show a time neither party acts on — which is why
    /// there is no getter here that returns one.
    @JsonKey(name: 'next_dose_local') String? nextDoseLocal,
    @JsonKey(name: 'next_dose_is_today') bool? nextDoseIsToday,

    /// The patient's IANA zone. Compared against the device's to decide
    /// whether the time needs "(their time)" after it.
    @JsonKey(name: 'next_dose_timezone') String? nextDoseTimezone,
  }) = _CareLink;

  const CareLink._();

  factory CareLink.fromJson(Map<String, dynamic> json) =>
      _$CareLinkFromJson(json);

  DateTime? get created => MediTime.parseUtc(createdAt);

  bool get hasNextDose =>
      (nextDoseName?.isNotEmpty ?? false) && (nextDoseLocal?.isNotEmpty ?? false);
}

/// The one-time code, returned once and never again — only its SHA-256 hash is
/// stored. There is nothing to fetch it back from, which is the whole reason
/// the UI has to hold on to it.
@freezed
abstract class CareInvite with _$CareInvite {
  const factory CareInvite({
    required String code,

    /// UTC with a marker, via `utc_iso`. 15 minutes out.
    @JsonKey(name: 'expires_at') required String expiresAt,
  }) = _CareInvite;

  const CareInvite._();

  factory CareInvite.fromJson(Map<String, dynamic> json) =>
      _$CareInviteFromJson(json);

  DateTime? get expires => MediTime.parseUtc(expiresAt);

  Duration remaining(DateTime now) {
    final end = expires;
    if (end == null) return Duration.zero;
    final left = end.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  bool isDead(DateTime now) => remaining(now) == Duration.zero;
}
