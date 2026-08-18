// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MedicalReport _$MedicalReportFromJson(Map<String, dynamic> json) =>
    _MedicalReport(
      id: json['id'] as String,
      reportType: json['report_type'] as String,
      reportDate: json['report_date'] as String?,
      fileName: json['file_name'] as String,
      notes: json['notes'] as String?,
      extractedText: json['extracted_text'] as String?,
      documentId: json['document_id'] as String?,
      doctorName: json['doctor_name'] as String?,
      hospital: json['hospital'] as String?,
    );

Map<String, dynamic> _$MedicalReportToJson(_MedicalReport instance) =>
    <String, dynamic>{
      'id': instance.id,
      'report_type': instance.reportType,
      'report_date': instance.reportDate,
      'file_name': instance.fileName,
      'notes': instance.notes,
      'extracted_text': instance.extractedText,
      'document_id': instance.documentId,
      'doctor_name': instance.doctorName,
      'hospital': instance.hospital,
    };

_LabFinding _$LabFindingFromJson(Map<String, dynamic> json) => _LabFinding(
  name: json['name'] as String,
  value: (json['value'] as num).toDouble(),
  unit: json['unit'] as String,
  status: json['status'] as String,
  referenceRange: json['reference_range'] as String,
  category: json['category'] as String,
);

Map<String, dynamic> _$LabFindingToJson(_LabFinding instance) =>
    <String, dynamic>{
      'name': instance.name,
      'value': instance.value,
      'unit': instance.unit,
      'status': instance.status,
      'reference_range': instance.referenceRange,
      'category': instance.category,
    };

_LabAnalysis _$LabAnalysisFromJson(Map<String, dynamic> json) => _LabAnalysis(
  overall: json['overall'] as String,
  total: (json['total'] as num).toInt(),
  abnormalCount: (json['abnormal_count'] as num).toInt(),
  findings: (json['findings'] as List<dynamic>)
      .map((e) => LabFinding.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$LabAnalysisToJson(_LabAnalysis instance) =>
    <String, dynamic>{
      'overall': instance.overall,
      'total': instance.total,
      'abnormal_count': instance.abnormalCount,
      'findings': instance.findings,
    };

_TrendPoint _$TrendPointFromJson(Map<String, dynamic> json) => _TrendPoint(
  date: json['date'] as String,
  value: (json['value'] as num).toDouble(),
  status: json['status'] as String?,
);

Map<String, dynamic> _$TrendPointToJson(_TrendPoint instance) =>
    <String, dynamic>{
      'date': instance.date,
      'value': instance.value,
      'status': instance.status,
    };

_TrendSeries _$TrendSeriesFromJson(Map<String, dynamic> json) => _TrendSeries(
  name: json['name'] as String,
  unit: json['unit'] as String,
  referenceRange: json['reference_range'] as String,
  points: (json['points'] as List<dynamic>)
      .map((e) => TrendPoint.fromJson(e as Map<String, dynamic>))
      .toList(),
  firstValue: (json['first_value'] as num).toDouble(),
  lastValue: (json['last_value'] as num).toDouble(),
  change: (json['change'] as num).toDouble(),
  percentChange: (json['percent_change'] as num?)?.toDouble(),
  direction: json['direction'] as String,
  latestStatus: json['latest_status'] as String,
);

Map<String, dynamic> _$TrendSeriesToJson(_TrendSeries instance) =>
    <String, dynamic>{
      'name': instance.name,
      'unit': instance.unit,
      'reference_range': instance.referenceRange,
      'points': instance.points,
      'first_value': instance.firstValue,
      'last_value': instance.lastValue,
      'change': instance.change,
      'percent_change': instance.percentChange,
      'direction': instance.direction,
      'latest_status': instance.latestStatus,
    };
