/// Every `/api/reports*` call. Self-only — reports are never in caretaker
/// scope, so nothing here takes a `patient_id`.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/network_providers.dart';
import '../domain/report.dart';

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => ReportRepository(ref.watch(apiClientProvider)),
);

class ReportRepository {
  const ReportRepository(this._client);

  final ApiClient _client;

  static const _base = '/api/reports';

  /// How long to wait on an upload before giving up.
  ///
  /// `create_report` runs OCR and writes the file; the default 30 seconds can
  /// abandon work the server is still doing, and the report lands anyway with
  /// the user believing it failed.
  static const uploadTimeout = Duration(minutes: 4);

  /// `GET /api/reports` — newest first.
  ///
  /// Carries `extracted_text` in full for **every** report, which is why the
  /// list is fetched once and cached rather than on every visit to the tab.
  Future<({List<MedicalReport> reports, int total})> list({
    int offset = 0,
    int limit = 20,
  }) async {
    final json = await _client.get<Map<String, dynamic>>(
      '$_base?offset=$offset&limit=$limit',
    );
    final rows = json['reports'] as List<dynamic>? ?? const [];
    return (
      reports: [
        for (final row in rows)
          MedicalReport.fromJson(row as Map<String, dynamic>),
      ],
      total: (json['total'] as num?)?.toInt() ?? rows.length,
    );
  }

  /// `POST /api/reports` — multipart, 10 MB cap, synchronous OCR.
  ///
  /// [onProgress] reports bytes sent, which covers the upload but not the
  /// processing that follows it. The screen has to say so; a bar that sits at
  /// 100% for two minutes looks broken.
  Future<MedicalReport> upload({
    required String filePath,
    required String fileName,
    required ReportType type,
    String? notes,
    String? reportDate,
    String? hospital,
    String? doctorName,
    void Function(int sent, int total)? onProgress,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
      'report_type': type.wire,
      'notes': ?notes,
      // Date-only. `datetime.fromisoformat` accepts "2026-08-06" and the column
      // keeps midnight, which is what a report date means.
      'report_date': ?reportDate,
      'hospital': ?hospital,
      'doctor_name': ?doctorName,
    });

    final json = await _client.postMultipart<Map<String, dynamic>>(
      _base,
      form,
      onSendProgress: onProgress,
      receiveTimeout: uploadTimeout,
    );
    return MedicalReport.fromJson(json);
  }

  /// `DELETE /api/reports/{id}` — hard, and it takes the stored file and any
  /// share links with it.
  Future<void> remove(String id) => _client.delete<void>('$_base/$id');

  /// `GET /api/reports/{id}/lab-analysis` — analytes parsed out of the OCR
  /// text. Returns `NO_DATA` rather than failing when nothing was recognised.
  Future<LabAnalysis> labAnalysis(String id) async {
    final json = await _client.get<Map<String, dynamic>>(
      '$_base/$id/lab-analysis',
    );
    return LabAnalysis.fromJson(json);
  }

  /// `PUT /api/reports/{id}/lab-values` — correct a mis-OCR'd reading by hand.
  ///
  /// `overrides` maps an analyte name (as the server reports it) to its new
  /// `value` and optional `unit`. The response is the corrected analysis.
  Future<LabAnalysis> correctValues(
    String id,
    Map<String, Map<String, dynamic>> overrides,
  ) async {
    final json = await _client.put<Map<String, dynamic>>(
      '$_base/$id/lab-values',
      body: {'overrides': overrides},
    );
    return LabAnalysis.fromJson(json);
  }

  /// `POST /api/reports/{id}/explain` was removed with the AI features.

  /// `GET /api/reports/trends` — analytes tracked across reports, two points
  /// minimum, abnormal series first.
  Future<List<TrendSeries>> trends() async {
    final json = await _client.get<Map<String, dynamic>>('$_base/trends');
    final rows = json['series'] as List<dynamic>? ?? const [];
    return [
      for (final row in rows) TrendSeries.fromJson(row as Map<String, dynamic>),
    ];
  }

  /// The path the report's own file is served from. Bytes are fetched through
  /// `fileBytesProvider`, which sends the bearer token this route requires.
  static String filePath(String id) => '$_base/$id/file';
}
