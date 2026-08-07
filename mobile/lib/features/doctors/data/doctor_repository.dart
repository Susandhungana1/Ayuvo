/// Every `/api/doctors*` call — the directory patients book from, and the
/// profile and hours a doctor owns.
///
/// The role gate lives on the server: everything except [list] and
/// [availabilityFor] answers 403 unless the caller is a DOCTOR or ADMIN, and
/// 404 until that doctor has a profile row. Both are ordinary states here, not
/// errors — a newly elevated doctor sees the 404 before they see anything else.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/network_providers.dart';
import '../domain/doctor.dart';

final doctorRepositoryProvider = Provider<DoctorRepository>(
  (ref) => DoctorRepository(ref.watch(apiClientProvider)),
);

class DoctorRepository {
  const DoctorRepository(this._client);

  final ApiClient _client;

  static const _base = '/api/doctors';

  /// `GET /api/doctors/doctors` — **verified doctors only**. An unverified
  /// profile is invisible here, so a doctor who has just registered will not
  /// find themselves in the list, and neither will their patients.
  Future<List<Doctor>> list() async {
    final json = await _client.get<Map<String, dynamic>>('$_base/doctors');
    final rows = json['doctors'] as List<dynamic>? ?? const [];
    return [
      for (final row in rows) Doctor.fromJson(row as Map<String, dynamic>),
    ];
  }

  /// `GET /api/doctors/doctors/me` — 404 when no profile exists yet, which is
  /// the signal to offer [createProfile] rather than an error.
  Future<Doctor> me() async {
    final json = await _client.get<Map<String, dynamic>>('$_base/doctors/me');
    return Doctor.fromJson(json);
  }

  /// `POST /api/doctors/doctors`.
  ///
  /// This is step 4 of `ADD_DOCTOR_GUIDE.txt` and the only step that should be
  /// self-service. Role elevation and verification stay operator actions: a
  /// doctor who could verify themselves is not a verified doctor.
  Future<Doctor> createProfile({
    required String nmid,
    required String degree,
    String? specialty,
  }) async {
    final json = await _client.post<Map<String, dynamic>>(
      '$_base/doctors',
      body: {'nmid': nmid, 'degree': degree, 'specialty': ?specialty},
    );
    return Doctor.fromJson(json);
  }

  /// `GET /api/doctors/availability` — my own windows, switched-off ones
  /// included. The doctor resolves from the token; there is no id in the path.
  Future<List<AvailabilityWindow>> mine() => _windows('$_base/availability');

  /// `GET /api/doctors/availability/{doctor_id}` — someone else's, filtered
  /// server-side to the windows that are switched on. Takes `Doctor.id`, the
  /// UUID: passing a user id is the bug the web editor shipped with, and the
  /// `#` in it truncates the path before the server ever sees the rest.
  Future<List<AvailabilityWindow>> availabilityFor(String doctorId) =>
      _windows('$_base/availability/$doctorId');

  Future<List<AvailabilityWindow>> _windows(String path) async {
    final json = await _client.get<Map<String, dynamic>>(path);
    final rows = json['availability'] as List<dynamic>? ?? const [];
    return [
      for (final row in rows)
        AvailabilityWindow.fromJson(row as Map<String, dynamic>),
    ];
  }

  /// `POST /api/doctors/availability` — 400 when it overlaps a window that
  /// already exists on that weekday.
  Future<AvailabilityWindow> addWindow({
    required Weekday day,
    required String startTime,
    required String endTime,
    int slotDurationMinutes = 30,
    bool isAvailable = true,
  }) async {
    final json = await _client.post<Map<String, dynamic>>(
      '$_base/availability',
      body: {
        'day_of_week': day.wire,
        'start_time': startTime,
        'end_time': endTime,
        'slot_duration_minutes': slotDurationMinutes,
        'is_available': isAvailable,
      },
    );
    return AvailabilityWindow.fromJson(json);
  }

  /// `PUT /api/doctors/availability/{id}` — partial, and null means "leave it".
  /// The weekday is not updatable: moving a window to another day means
  /// deleting it and adding it back, which is also what the overlap check
  /// expects.
  ///
  /// Note the server does **not** re-run the overlap check on update, so two
  /// windows can be made to overlap this way. Recorded in `BACKEND_NOTES.md`.
  Future<AvailabilityWindow> updateWindow(
    String id, {
    String? startTime,
    String? endTime,
    int? slotDurationMinutes,
    bool? isAvailable,
  }) async {
    final json = await _client.put<Map<String, dynamic>>(
      '$_base/availability/$id',
      body: {
        'start_time': ?startTime,
        'end_time': ?endTime,
        'slot_duration_minutes': ?slotDurationMinutes,
        'is_available': ?isAvailable,
      },
    );
    return AvailabilityWindow.fromJson(json);
  }

  /// `DELETE /api/doctors/availability/{id}`. Bookings already made against
  /// the window survive it — the server never looks back at appointments.
  Future<void> removeWindow(String id) =>
      _client.delete<void>('$_base/availability/$id');
}
