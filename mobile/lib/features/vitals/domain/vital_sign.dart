/// `/api/vitals` in Dart.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/time/medi_time.dart';

part 'vital_sign.freezed.dart';
part 'vital_sign.g.dart';

@freezed
abstract class VitalSign with _$VitalSign {
  const factory VitalSign({
    required String id,
    @JsonKey(name: 'blood_pressure_systolic') int? systolic,
    @JsonKey(name: 'blood_pressure_diastolic') int? diastolic,
    @JsonKey(name: 'heart_rate') int? heartRate,
    double? weight,
    @JsonKey(name: 'blood_sugar') double? bloodSugar,
    double? temperature,
    @JsonKey(name: 'oxygen_saturation') int? oxygenSaturation,
    String? notes,

    /// Naive UTC. Read it through [measured], never with `DateTime.parse`.
    @JsonKey(name: 'measured_at') required String measuredAt,
    @JsonKey(name: 'created_at') required String createdAt,
  }) = _VitalSign;

  const VitalSign._();

  factory VitalSign.fromJson(Map<String, dynamic> json) =>
      _$VitalSignFromJson(json);

  /// When the reading was taken, in the reader's own timezone.
  DateTime? get measured => MediTime.parseUtc(measuredAt);

  /// When the row was written — usually the same moment, but not for a reading
  /// entered after the fact.
  DateTime? get created => MediTime.parseUtc(createdAt);

  /// `POST /api/vitals` accepts a body with every metric null and stores an
  /// empty row. Nothing server-side prevents it, so the form checks this before
  /// submitting and the list can tell if a legacy blank row exists.
  bool get isEmpty =>
      systolic == null &&
      diastolic == null &&
      heartRate == null &&
      weight == null &&
      bloodSugar == null &&
      temperature == null &&
      oxygenSaturation == null;

  /// A blood pressure needs both halves; one without the other is not a
  /// reading, and the web app's own analyser skips it for the same reason.
  bool get hasBloodPressure => systolic != null && diastolic != null;
}
