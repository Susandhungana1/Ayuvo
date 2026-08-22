/// Every `/api/medicines*` call, and the only place their URLs appear.
///
/// **Caretaker scope lives here.** Nine of these ten routes take an optional
/// `patient_id`; supplying one means "act on that patient's list", and the
/// server resolves it through `resolve_medicine_scope` — the single
/// authorisation point. Two rules this file exists to keep:
///
///   1. every scoped URL is built by [ScopedUrl], because a patient id contains
///      `#` and interpolating one raw drops it — silently returning the
///      *caller's* medicines instead of the patient's;
///   2. [recordIntake] and [intakeLog] take no `patient_id` at all. The server
///      refuses one, and it is right to: a caretaker edits the list, but only
///      the patient can say a dose was actually swallowed.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/network/scoped_url.dart';
import '../domain/dose_times.dart';
import '../domain/medicine.dart';

final medicineRepositoryProvider = Provider<MedicineRepository>(
  (ref) => MedicineRepository(ref.watch(apiClientProvider)),
);

class MedicineRepository {
  const MedicineRepository(this._client);

  final ApiClient _client;

  static const _base = '/api/medicines';

  /// `GET /api/medicines` — newest first, soft-deleted rows excluded.
  Future<({List<Medicine> medicines, int total})> list({
    String? patientId,
    int offset = 0,
    int limit = 20,
  }) async {
    final url = ScopedUrl.build(
      _base,
      patientId: patientId,
      query: {'offset': offset, 'limit': limit},
    );
    final json = await _client.get<Map<String, dynamic>>(url);
    return (
      medicines: _medicines(json),
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }

  /// `POST /api/medicines`.
  ///
  /// [times] is encoded here rather than by the caller so the string-encoded
  /// JSON array never has to be assembled twice.
  Future<Medicine> create({
    required String name,
    required String dosage,
    required String frequency,
    required String startDate,
    String? endDate,
    List<String> times = const [],
    String? notes,
    String? patientId,
  }) async {
    final json = await _client.post<Map<String, dynamic>>(
      ScopedUrl.build(_base, patientId: patientId),
      body: {
        'name': name,
        'dosage': dosage,
        'frequency': frequency,
        'start_date': startDate,
        'end_date': _orNull(endDate),
        'taking_times': DoseTimes.encode(times),
        'notes': _orNull(notes),
      },
    );
    return Medicine.fromJson(json);
  }

  /// `PUT /api/medicines/{id}` — **null means "leave unchanged"**.
  ///
  /// That is the server's rule, not a convention here: `update_medicine` skips
  /// every field that arrives as null, so there is no way to clear `notes` or
  /// `end_date` through this route. Passing `''` writes an empty string, which
  /// is the closest thing to clearing available and is what the edit form does
  /// when a user empties a field.
  Future<Medicine> update(
    String id, {
    String? name,
    String? dosage,
    String? frequency,
    String? startDate,
    String? endDate,
    List<String>? times,
    String? notes,
    String? patientId,
  }) async {
    final json = await _client.put<Map<String, dynamic>>(
      ScopedUrl.build('$_base/$id', patientId: patientId),
      body: {
        // `?value` omits the key entirely when the argument is null, which is
        // the same thing the server means by "leave unchanged".
        'name': ?name,
        'dosage': ?dosage,
        'frequency': ?frequency,
        'start_date': ?startDate,
        'end_date': ?endDate,
        // An empty list encodes to null, which this route reads as "unchanged" —
        // so send "[]" explicitly to mean "no dose times any more".
        if (times != null) 'taking_times': DoseTimes.encode(times) ?? '[]',
        'notes': ?notes,
      },
    );
    return Medicine.fromJson(json);
  }

  /// `DELETE /api/medicines/{id}` — soft. The row is retired, not dropped, so
  /// [restore] can bring it back.
  Future<void> remove(String id, {String? patientId}) => _client.delete<void>(
        ScopedUrl.build('$_base/$id', patientId: patientId),
      );

  /// `POST /api/medicines/{id}/restore` — 400 if the medicine isn't deleted.
  Future<Medicine> restore(String id, {String? patientId}) async {
    final json = await _client.post<Map<String, dynamic>>(
      ScopedUrl.build('$_base/$id/restore', patientId: patientId),
    );
    return Medicine.fromJson(json);
  }

  /// `GET /api/medicines/interactions` — offline dataset, **active medicines
  /// only**. A course that has ended is not checked, which is why the banner
  /// says how many were.
  Future<InteractionCheck> interactions({String? patientId}) async {
    final json = await _client.get<Map<String, dynamic>>(
      ScopedUrl.build('$_base/interactions', patientId: patientId),
    );
    return InteractionCheck.fromJson(json);
  }

  /// `GET /api/medicines/audit` — who changed what. A patient sees every change
  /// to their list; a caretaker sees only their own.
  Future<List<MedicineAuditEntry>> audit({
    String? patientId,
    int limit = 50,
  }) async {
    final json = await _client.get<Map<String, dynamic>>(
      ScopedUrl.build(
        '$_base/audit',
        patientId: patientId,
        query: {'limit': limit},
      ),
    );
    final entries = json['entries'] as List<dynamic>? ?? const [];
    return [
      for (final entry in entries)
        MedicineAuditEntry.fromJson(entry as Map<String, dynamic>),
    ];
  }

  /// `POST /api/medicines/{id}/intake` — **self only, no `patient_id`.**
  Future<MedicineIntake> recordIntake(
    String medicineId, {
    required String scheduledTime,
    String status = 'taken',
  }) async {
    final json = await _client.post<Map<String, dynamic>>(
      '$_base/$medicineId/intake',
      body: {'scheduled_time': scheduledTime, 'status': status},
    );
    return MedicineIntake.fromJson(json);
  }

  /// `GET /api/medicines/intake/log` — **self only.** Newest first, capped at
  /// 500 server-side. The web app never calls this; the adherence view is the
  /// first thing that has.
  Future<List<MedicineIntake>> intakeLog({int limit = 100}) async {
    final json = await _client.get<Map<String, dynamic>>(
      '$_base/intake/log?limit=$limit',
    );
    final intakes = json['intakes'] as List<dynamic>? ?? const [];
    return [
      for (final intake in intakes)
        MedicineIntake.fromJson(intake as Map<String, dynamic>),
    ];
  }

  static List<Medicine> _medicines(Map<String, dynamic> json) {
    final rows = json['medicines'] as List<dynamic>? ?? const [];
    return [
      for (final row in rows) Medicine.fromJson(row as Map<String, dynamic>),
    ];
  }

  /// Blank is the same as absent for an optional field on create.
  static String? _orNull(String? value) {
    final text = value?.trim();
    return (text == null || text.isEmpty) ? null : text;
  }
}
