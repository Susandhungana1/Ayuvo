/// `/api/reports` in Dart.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/time/medi_time.dart';

part 'report.freezed.dart';
part 'report.g.dart';

/// `MedicalReportType`, from `server/app/models/models.py`.
///
/// The web app's dropdown offers eight of these and posts the literal
/// `"OTHER"` — which is not a member. The server accepts it because
/// `report_type` arrives as a `Form(str)` and is never validated against the
/// enum, so bad values are already in the database. This client sends real
/// values and reads unknown ones without failing.
enum ReportType {
  bloodTest('BLOOD_TEST', 'Blood test'),
  urineTest('URINE_TEST', 'Urine test'),
  stoolTest('STOOL_TEST', 'Stool test'),
  xray('XRAY', 'X-ray'),
  mri('MRI', 'MRI'),
  ctScan('CT_SCAN', 'CT scan'),
  ecg('ECG', 'ECG'),
  ultrasound('ULTRASOUND', 'Ultrasound'),
  labReport('LAB_REPORT', 'Lab report'),
  others('OTHERS', 'Something else');

  const ReportType(this.wire, this.label);

  /// What goes on the wire. Never send [label].
  final String wire;
  final String label;

  /// Turns a stored value into a label without losing anything: a row written
  /// by the web app as `"OTHER"` — or as anything else — shows the raw value
  /// rather than being silently relabelled or dropped.
  static String labelFor(String wire) {
    for (final type in values) {
      if (type.wire == wire) return type.label;
    }
    return wire;
  }

  static ReportType? tryParse(String wire) {
    for (final type in values) {
      if (type.wire == wire) return type;
    }
    return null;
  }
}

@freezed
abstract class MedicalReport with _$MedicalReport {
  const factory MedicalReport({
    required String id,
    @JsonKey(name: 'report_type') required String reportType,

    /// Date-only in meaning, datetime in transport. Never shift it.
    @JsonKey(name: 'report_date') String? reportDate,
    @JsonKey(name: 'file_name') required String fileName,
    String? notes,

    /// The OCR output. **Every list response carries this in full** for every
    /// report — see `BACKEND_NOTES.md` §3.
    @JsonKey(name: 'extracted_text') String? extractedText,

    /// `PENDING` while the server's background OCR runs after an upload;
    /// `DONE`/`FAILED` once it has. The detail screen uses it to wait for
    /// lab values instead of showing "none found".
    @JsonKey(name: 'ocr_status') String? ocrStatus,
    @JsonKey(name: 'document_id') String? documentId,

    /// Falls back to the linked document's values when unset server-side.
    @JsonKey(name: 'doctor_name') String? doctorName,
    String? hospital,
  }) = _MedicalReport;

  const MedicalReport._();

  factory MedicalReport.fromJson(Map<String, dynamic> json) =>
      _$MedicalReportFromJson(json);

  String get typeLabel => ReportType.labelFor(reportType);

  DateTime? get dated => MediTime.parseDate(reportDate);

  /// Whether OCR read anything. The lab analyser has nothing to parse without
  /// it, so the actions that depend on it are hidden rather than offered and
  /// then refused.
  bool get hasText => extractedText?.trim().isNotEmpty ?? false;

  /// Whether the server is still reading the file in the background.
  bool get isOcrPending => ocrStatus?.toUpperCase() == 'PENDING';
}

/// One analyte from `GET /api/reports/{id}/lab-analysis`.
@freezed
abstract class LabFinding with _$LabFinding {
  const factory LabFinding({
    required String name,
    required double value,
    required String unit,

    /// `HIGH` · `LOW` · `NORMAL`.
    required String status,
    @JsonKey(name: 'reference_range') required String referenceRange,

    /// Blood Count · Metabolic · Lipids · Kidney · Electrolytes · Liver ·
    /// Thyroid · Vitamins.
    required String category,
  }) = _LabFinding;

  const LabFinding._();

  factory LabFinding.fromJson(Map<String, dynamic> json) =>
      _$LabFindingFromJson(json);

  bool get isNormal => status.toUpperCase() == 'NORMAL';
  bool get isHigh => status.toUpperCase() == 'HIGH';
}

@freezed
abstract class LabAnalysis with _$LabAnalysis {
  const factory LabAnalysis({
    /// `NORMAL` · `ABNORMAL` · `NO_DATA`.
    required String overall,
    required int total,
    @JsonKey(name: 'abnormal_count') required int abnormalCount,
    required List<LabFinding> findings,
  }) = _LabAnalysis;

  const LabAnalysis._();

  factory LabAnalysis.fromJson(Map<String, dynamic> json) =>
      _$LabAnalysisFromJson(json);

  bool get hasData => overall.toUpperCase() != 'NO_DATA' && findings.isNotEmpty;

  /// Findings grouped by category, in the order they arrive — the server sorts
  /// them, and re-sorting here would discard that.
  Map<String, List<LabFinding>> get byCategory {
    final grouped = <String, List<LabFinding>>{};
    for (final finding in findings) {
      grouped.putIfAbsent(finding.category, () => []).add(finding);
    }
    return grouped;
  }
}

/// One point of a cross-report lab trend.
@freezed
abstract class TrendPoint with _$TrendPoint {
  const factory TrendPoint({
    required String date,
    required double value,
    String? status,
  }) = _TrendPoint;

  const TrendPoint._();

  factory TrendPoint.fromJson(Map<String, dynamic> json) =>
      _$TrendPointFromJson(json);

  DateTime? get at => MediTime.parseDate(date) ?? MediTime.parseUtc(date);
}

/// One analyte tracked across reports, from `GET /api/reports/trends`. Only
/// tests with two or more data points appear, and abnormal series sort first.
@freezed
abstract class TrendSeries with _$TrendSeries {
  const factory TrendSeries({
    required String name,
    required String unit,
    @JsonKey(name: 'reference_range') required String referenceRange,
    required List<TrendPoint> points,
    @JsonKey(name: 'first_value') required double firstValue,
    @JsonKey(name: 'last_value') required double lastValue,
    required double change,
    @JsonKey(name: 'percent_change') double? percentChange,

    /// `up` · `down` · `flat`.
    required String direction,

    /// `HIGH` · `LOW` · `NORMAL`.
    @JsonKey(name: 'latest_status') required String latestStatus,
  }) = _TrendSeries;

  const TrendSeries._();

  factory TrendSeries.fromJson(Map<String, dynamic> json) =>
      _$TrendSeriesFromJson(json);

  bool get isNormal => latestStatus.toUpperCase() == 'NORMAL';
}
