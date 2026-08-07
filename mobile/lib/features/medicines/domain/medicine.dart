/// `/api/medicines` in Dart. Field names are the server's, verbatim.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/time/medi_time.dart';
import 'dose_times.dart';

part 'medicine.freezed.dart';
part 'medicine.g.dart';

@freezed
abstract class Medicine with _$Medicine {
  const factory Medicine({
    required String id,
    required String name,
    required String dosage,
    required String frequency,

    /// `"YYYY-MM-DD"`, and it stays a string. The server compares these
    /// lexically, so round-tripping one through a `DateTime` would risk
    /// shifting the day and silently changing which medicines count as active.
    @JsonKey(name: 'start_date') required String startDate,
    @JsonKey(name: 'end_date') String? endDate,

    /// A JSON array **encoded as a string**: `"[\"08:00\",\"20:00\"]"`.
    /// Read it through [times]; never parse it at a call site.
    @JsonKey(name: 'taking_times') String? takingTimes,
    String? notes,
    @JsonKey(name: 'created_at') String? createdAt,
  }) = _Medicine;

  const Medicine._();

  factory Medicine.fromJson(Map<String, dynamic> json) =>
      _$MedicineFromJson(json);

  /// The dose times, sorted, with anything malformed dropped.
  ///
  /// `app/core/doses.py::parse_times` degrades to `[]` rather than raising, and
  /// so does this: a medicine row with a corrupt `taking_times` must still
  /// appear in the list, minus its chips.
  List<String> get times => DoseTimes.decode(takingTimes);

  DateTime? get created => MediTime.parseUtc(createdAt);

  /// Whether the course covers [day] — the same `start <= day <= end` string
  /// comparison the server does, for the same reason.
  bool coversDay(DateTime day) {
    final today = MediTime.dateOnly(day);
    if (startDate.compareTo(today) > 0) return false;
    final end = endDate;
    if (end == null || end.isEmpty) return true;
    return end.compareTo(today) >= 0;
  }

  /// A course that has finished. `GET /interactions` ignores these, so the UI
  /// should visibly separate them rather than imply they were checked.
  bool get hasEnded {
    final end = endDate;
    if (end == null || end.isEmpty) return false;
    return end.compareTo(MediTime.dateOnly(DateTime.now())) < 0;
  }
}

/// One row of `{interactions:[…]}` from `GET /api/medicines/interactions`.
@freezed
abstract class DrugInteraction with _$DrugInteraction {
  const factory DrugInteraction({
    @JsonKey(name: 'drug_a') required String drugA,
    @JsonKey(name: 'drug_b') required String drugB,

    /// `severe` · `moderate` · `minor`, lowercase from the offline dataset.
    required String severity,
    required String description,
  }) = _DrugInteraction;

  const DrugInteraction._();

  factory DrugInteraction.fromJson(Map<String, dynamic> json) =>
      _$DrugInteractionFromJson(json);

  /// Ranked so the list can sort worst-first without the widget knowing the
  /// vocabulary.
  int get rank => switch (severity.toLowerCase()) {
        'severe' => 0,
        'moderate' => 1,
        _ => 2,
      };
}

@freezed
abstract class InteractionCheck with _$InteractionCheck {
  const factory InteractionCheck({
    required List<DrugInteraction> interactions,

    /// How many medicines were considered — active ones only. Shown so "no
    /// interactions found" can say what it looked at.
    @JsonKey(name: 'checked_count') required int checkedCount,
  }) = _InteractionCheck;

  factory InteractionCheck.fromJson(Map<String, dynamic> json) =>
      _$InteractionCheckFromJson(json);
}

/// A dose the patient marked. Self-only — a caretaker manages the list, but
/// whether a tablet was actually swallowed is the patient's own account.
@freezed
abstract class MedicineIntake with _$MedicineIntake {
  const factory MedicineIntake({
    required String id,
    @JsonKey(name: 'medicine_id') required String medicineId,

    /// The `"08:00"` slot this refers to, not the moment it was recorded.
    @JsonKey(name: 'scheduled_time') required String scheduledTime,

    /// `taken` · `snoozed` · `skipped`.
    required String status,
    @JsonKey(name: 'recorded_at') required String recordedAt,
  }) = _MedicineIntake;

  const MedicineIntake._();

  factory MedicineIntake.fromJson(Map<String, dynamic> json) =>
      _$MedicineIntakeFromJson(json);

  DateTime? get recorded => MediTime.parseUtc(recordedAt);
}

/// A row of `GET /api/medicines/audit`. Its `created_at` is one of the three
/// fields that already carries `Z`.
@freezed
abstract class MedicineAuditEntry with _$MedicineAuditEntry {
  const factory MedicineAuditEntry({
    required int id,
    @JsonKey(name: 'actor_id') required String actorId,
    @JsonKey(name: 'actor_name') required String actorName,
    @JsonKey(name: 'medicine_id') String? medicineId,
    @JsonKey(name: 'medicine_name') String? medicineName,

    /// `create` · `update` · `delete` · `restore`.
    required String action,
    @JsonKey(name: 'created_at') required String createdAt,
    @JsonKey(name: 'by_caretaker') required bool byCaretaker,
  }) = _MedicineAuditEntry;

  const MedicineAuditEntry._();

  factory MedicineAuditEntry.fromJson(Map<String, dynamic> json) =>
      _$MedicineAuditEntryFromJson(json);

  DateTime? get created => MediTime.parseUtc(createdAt);
}
