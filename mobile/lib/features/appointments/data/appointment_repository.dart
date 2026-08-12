/// Every `/api/appointments*` call. Self-only — there is no caretaker scope
/// here, and the doctor's view is a separate route rather than a parameter.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/time/medi_time.dart';
import '../domain/appointment.dart';

final appointmentRepositoryProvider = Provider<AppointmentRepository>(
  (ref) => AppointmentRepository(ref.watch(apiClientProvider)),
);

class AppointmentRepository {
  const AppointmentRepository(this._client);

  final ApiClient _client;

  static const _base = '/api/appointments';

  /// `GET /api/appointments` — mine, soonest first.
  Future<List<Appointment>> list() => _listFrom(_base);

  /// `GET /api/appointments/doctor/my-appointments` — the bookings made
  /// against my doctor profile. 403 without the DOCTOR role, 404 without a
  /// doctor profile, and both are states the inbox has to explain rather than
  /// render as a failure.
  Future<List<Appointment>> inbox() => _listFrom('$_base/doctor/my-appointments');

  Future<List<Appointment>> _listFrom(String path) async {
    final json = await _client.get<Map<String, dynamic>>(path);
    final rows = json['appointments'] as List<dynamic>? ?? const [];
    return [
      for (final row in rows) Appointment.fromJson(row as Map<String, dynamic>),
    ];
  }

  /// `POST /api/appointments`.
  ///
  /// [startsAt] goes out as **naive local** — the wall-clock time the patient
  /// picked, with no zone. This is not a style choice: `AppointmentCreate`
  /// validates with `v <= datetime.now()`, and comparing an aware datetime to a
  /// naive one raises inside Pydantic, which surfaces as a 500 rather than a
  /// validation error (`FEATURE_MAP.md` §1.2).
  Future<Appointment> create({
    required String title,
    required DateTime startsAt,
    required int durationMinutes,
    String? doctorId,
    String? doctorName,
    String? hospital,
    String? reason,
    String? description,
  }) async {
    final json = await _client.post<Map<String, dynamic>>(
      _base,
      body: _body(
        title: title,
        startsAt: startsAt,
        durationMinutes: durationMinutes,
        doctorId: doctorId,
        doctorName: doctorName,
        hospital: hospital,
        reason: reason,
        description: description,
      ),
    );
    return Appointment.fromJson(json);
  }

  /// `PUT /api/appointments/{id}` — a **full replace** with the create body,
  /// including the must-be-in-the-future rule. Every field the caller omits is
  /// written as null, so the caller sends the whole appointment or loses parts
  /// of it. The status is not in that body and is left alone by the server.
  Future<Appointment> replace(
    String id, {
    required String title,
    required DateTime startsAt,
    required int durationMinutes,
    String? doctorId,
    String? doctorName,
    String? hospital,
    String? reason,
    String? description,
  }) async {
    final json = await _client.put<Map<String, dynamic>>(
      '$_base/$id',
      body: _body(
        title: title,
        startsAt: startsAt,
        durationMinutes: durationMinutes,
        doctorId: doctorId,
        doctorName: doctorName,
        hospital: hospital,
        reason: reason,
        description: description,
      ),
    );
    return Appointment.fromJson(json);
  }

  static Map<String, Object?> _body({
    required String title,
    required DateTime startsAt,
    required int durationMinutes,
    String? doctorId,
    String? doctorName,
    String? hospital,
    String? reason,
    String? description,
  }) =>
      {
        'title': title,
        'appointment_date': MediTime.naiveLocal(startsAt),
        'duration_minutes': durationMinutes,
        'doctor_id': ?doctorId,
        'doctor_name': ?doctorName,
        'hospital': ?hospital,
        'reason': ?reason,
        'description': ?description,
      };

  /// `PATCH /api/appointments/{id}/status?status=` — the **patient's** side.
  /// The status is a query parameter, not a body: `AppointmentStatus` is a bare
  /// enum in the signature, so FastAPI reads it from the query string and a
  /// JSON body 422s before the route is even reached.
  Future<Appointment> setStatus(String id, AppointmentStatus status) =>
      _patchStatus('$_base/$id/status', status);

  /// `PATCH /api/appointments/{id}/status/by-doctor?status=` — the doctor's.
  ///
  /// A separate route because the plain one authorises against
  /// `Appointment.user_id`, which is the patient who booked; a doctor is never
  /// that user and always got a 404 (`FEATURE_MAP.md` §7.1).
  Future<Appointment> setStatusAsDoctor(String id, AppointmentStatus status) =>
      _patchStatus('$_base/$id/status/by-doctor', status);

  Future<Appointment> _patchStatus(String path, AppointmentStatus status) async {
    final json = await _client.patch<Map<String, dynamic>>(
      '$path?status=${status.wire}',
    );
    return Appointment.fromJson(json);
  }

  /// `DELETE /api/appointments/{id}` — **hard**. Unlike a medicine, nothing is
  /// recoverable, which is why the UI offers Cancel first and Delete second.
  Future<void> remove(String id) => _client.delete<void>('$_base/$id');

  /// `GET /api/appointments/available-slots/{doctor_id}?date=&duration_minutes=`
  ///
  /// [day] is sent as a naive local midnight. The server takes `.date()` off it
  /// and builds every slot from the doctor's posted clock times, so the reply
  /// is a list of wall-clock windows for that calendar day.
  Future<List<AppointmentSlot>> slots({
    required String doctorId,
    required DateTime day,
    int durationMinutes = 30,
  }) async {
    final at = MediTime.naiveLocal(DateTime(day.year, day.month, day.day));
    final json = await _client.get<Map<String, dynamic>>(
      '$_base/available-slots/$doctorId'
      '?date=${Uri.encodeQueryComponent(at)}'
      '&duration_minutes=$durationMinutes',
    );
    final rows = json['available_slots'] as List<dynamic>? ?? const [];
    return [
      for (final row in rows)
        AppointmentSlot.fromJson(row as Map<String, dynamic>),
    ];
  }
}
