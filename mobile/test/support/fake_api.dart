/// A scripted backend for widget tests.
///
/// It overrides the *adapter*, not the repositories, so a test exercises the
/// real `ApiClient`, the real `ScopedUrl`, the real JSON decoding and the real
/// controllers — everything except the socket. That matters here: most of what
/// went wrong in phase 4 lived in decoding, not in widgets.
///
/// A route nobody scripted answers 404 and is recorded in [unmatched], so a
/// screen that quietly fires a request the test did not expect shows up as a
/// failed assertion rather than as an error card nobody reads.
library;

import 'package:dio/dio.dart';
import 'package:medistore/core/network/api_client.dart';

import 'fake_http.dart';

/// Answers one route. Return a plain object for 200 JSON, or a [ResponseBody]
/// when the status code or headers matter.
typedef FakeRoute = Object? Function(RecordedRequest request);

class FakeApi {
  final _routes = <String, FakeRoute>{};

  /// Every request that reached the adapter, in order, as `METHOD /path`.
  final calls = <String>[];

  /// Requests no route claimed. A test asserting on a screen should find this
  /// empty.
  final unmatched = <String>[];

  late final FakeAdapter adapter = FakeAdapter(_respond);

  /// Scripts `METHOD /path`, e.g. `on('GET /api/medicines', ...)`. The query
  /// string is not part of the key — assert on it through [requestFor].
  void on(String route, FakeRoute respond) => _routes[route] = respond;

  /// Scripts a route that always answers the same 200 JSON body.
  void json(String route, Object? body) => on(route, (_) => body);

  /// Scripts a failure, in the shape FastAPI actually returns.
  void fails(String route, int statusCode, String detail) => on(
        route,
        (_) => jsonResponse({'detail': detail}, statusCode: statusCode),
      );

  /// The last request that hit [route], for asserting on query and body.
  RecordedRequest? requestFor(String route) {
    for (final request in adapter.requests.reversed) {
      if (_key(request) == route) return request;
    }
    return null;
  }

  ApiClient client() {
    final dio = Dio()..httpClientAdapter = adapter;
    return ApiClient(baseUrl: 'http://127.0.0.1:3001', dio: dio);
  }

  String _key(RecordedRequest request) =>
      '${request.options.method} ${request.options.uri.path}';

  ResponseBody _respond(RecordedRequest request) {
    final key = _key(request);
    calls.add(key);

    final route = _routes[key];
    if (route == null) {
      unmatched.add(key);
      return jsonResponse(
        {'detail': 'No route scripted for $key'},
        statusCode: 404,
      );
    }

    final answer = route(request);
    return answer is ResponseBody ? answer : jsonResponse(answer);
  }
}

// ── Sample rows ────────────────────────────────────────────────────────────
//
// Shaped exactly as the server sends them, naive-UTC timestamps and all, so a
// decoder regression fails a widget test too.

Map<String, Object?> medicineRow({
  String id = 'med-1',
  String name = 'Amlodipine',
  String dosage = '5 mg',
  String frequency = 'Once daily',
  String startDate = '2020-01-01',
  String? endDate,
  String? takingTimes = '["08:00","20:00"]',
  String? notes,
}) =>
    {
      'id': id,
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'start_date': startDate,
      'end_date': endDate,
      'taking_times': takingTimes,
      'notes': notes,
      'created_at': '2026-08-06 09:00:00',
    };

Map<String, Object?> vitalRow({
  String id = 'vit-1',
  int? systolic = 118,
  int? diastolic = 76,
  int? heartRate = 72,
  double? bloodSugar,
  double? temperature,
  int? oxygen,
  double? weight,
  String measuredAt = '2026-08-06 03:15:00',
}) =>
    {
      'id': id,
      'blood_pressure_systolic': systolic,
      'blood_pressure_diastolic': diastolic,
      'heart_rate': heartRate,
      'blood_sugar': bloodSugar,
      'temperature': temperature,
      'oxygen_saturation': oxygen,
      'weight': weight,
      'notes': null,
      'measured_at': measuredAt,
      'created_at': measuredAt,
    };

Map<String, Object?> reportRow({
  String id = 'rep-1',
  String reportType = 'BLOOD_TEST',
  String fileName = 'cbc-june.pdf',
  String? reportDate = '2026-06-14T00:00:00',
  String? summary = 'Haemoglobin slightly below range; everything else normal.',
  String? extractedText = 'HAEMOGLOBIN 11.2 g/dL',
  String? aiReportText,
  String? documentId,
}) =>
    {
      'id': id,
      'report_type': reportType,
      'file_name': fileName,
      'report_date': reportDate,
      'doctor_name': 'Dr Asha Rai',
      'hospital': 'Bir Hospital',
      'notes': null,
      'result_summary': summary,
      'extracted_text': extractedText,
      'ai_report_text': aiReportText,
      'document_id': documentId,
    };

/// `appointment_date` is naive **local** wall clock, unlike everything above —
/// the server stores what the client sent and hands it straight back.
Map<String, Object?> appointmentRow({
  String id = 'apt-1',
  String title = 'Cardiology follow-up',
  String? doctorId = 'doc-uuid-1',
  String? doctorName = 'Dr Asha Rai',
  String? hospital,
  String appointmentDate = '2030-08-12T09:00:00',
  int durationMinutes = 30,
  String status = 'CONFIRMED',
  String? reason = 'Six-month review',
}) =>
    {
      'id': id,
      'title': title,
      'description': null,
      'doctor_id': doctorId,
      'doctor_name': doctorName,
      'hospital': hospital,
      'appointment_date': appointmentDate,
      'duration_minutes': durationMinutes,
      'status': status,
      'reason': reason,
      'reminder_sent': false,
    };

Map<String, Object?> doctorRow({
  String id = 'doc-uuid-1',
  String name = 'Dr Asha Rai',
  String nmid = 'NMC-12345',
  String degree = 'MBBS',
  String? specialty = 'Cardiology',
  bool verified = true,
  String userId = '#doc002',
}) =>
    {
      'id': id,
      'nmid': nmid,
      'degree': degree,
      'specialty': specialty,
      'verified': verified,
      'user_id': userId,
      'name': name,
    };

/// Times arrive as `"09:00:00"` — a clock with no date.
Map<String, Object?> availabilityRow({
  String id = 'avail-1',
  String dayOfWeek = 'MONDAY',
  String startTime = '09:00:00',
  String endTime = '12:00:00',
  int slotDurationMinutes = 30,
  bool isAvailable = true,
}) =>
    {
      'id': id,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'slot_duration_minutes': slotDurationMinutes,
      'is_available': isAvailable,
    };

/// `expires_at` is naive UTC, and `report_id` is the `__ALL_REPORTS__`
/// sentinel for a whole-record link.
Map<String, Object?> shareLinkRow({
  String token = 'tok-1',
  String reportId = 'rep-1',
  String expiresAt = '2030-08-08T09:14:22',
}) =>
    {'token': token, 'report_id': reportId, 'expires_at': expiresAt};

Map<String, Object?> emergencyProfileRow({
  String? bloodType = 'O+',
  String? allergies = 'Penicillin',
  String? conditions = 'Type 2 diabetes',
  List<Map<String, Object?>> contacts = const [],
}) =>
    {
      'blood_type': bloodType,
      'allergies': allergies,
      'medical_conditions': conditions,
      'emergency_contacts': contacts,
    };

Map<String, Object?> emergencyContactRow({
  String id = 'con-1',
  String name = 'Sita Bahadur',
  String relationship = 'Wife',
  String phone = '+977 98 1234 5678',
  String? email,
}) =>
    {
      'id': id,
      'name': name,
      'relationship': relationship,
      'phone': phone,
      'email': email,
    };

Map<String, Object?> documentRow({
  String id = 'doc-1',
  String hospital = 'Bir Hospital',
  String? department = 'Cardiology',
  String? doctorName = 'Dr Asha Rai',
  String? location = 'Kathmandu',
  String? description = 'Six-month follow-up.',
  String checkupDate = '2026-05-02T00:00:00',
}) =>
    {
      'id': id,
      'hospital': hospital,
      'location': location,
      'doctor_name': doctorName,
      'department': department,
      'description': description,
      'checkup_date': checkupDate,
    };
