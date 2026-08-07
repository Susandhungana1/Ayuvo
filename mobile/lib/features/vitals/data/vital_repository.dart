/// Every `/api/vitals` call. Self-only — vitals are never in caretaker scope,
/// so nothing here takes a `patient_id` and nothing here may grow one.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/time/medi_time.dart';
import '../domain/vital_sign.dart';

final vitalRepositoryProvider = Provider<VitalRepository>(
  (ref) => VitalRepository(ref.watch(apiClientProvider)),
);

class VitalRepository {
  const VitalRepository(this._client);

  final ApiClient _client;

  static const _base = '/api/vitals';

  /// `GET /api/vitals` — newest first by `measured_at`. The server caps `limit`
  /// at 200 and rejects anything larger with a 422, so the cap is applied here
  /// rather than trusted to callers.
  Future<List<VitalSign>> list({int limit = 50, int offset = 0}) async {
    final json = await _client.get<Map<String, dynamic>>(
      '$_base?limit=${limit.clamp(1, 200)}&offset=${offset < 0 ? 0 : offset}',
    );
    final rows = json['vitals'] as List<dynamic>? ?? const [];
    return [
      for (final row in rows) VitalSign.fromJson(row as Map<String, dynamic>),
    ];
  }

  /// `POST /api/vitals`.
  ///
  /// [measuredAt] is serialised as **naive UTC**, matching the column. Sending
  /// an offset-bearing string here is the mistake that 500s the appointment
  /// route; vitals tolerate it, but there is no reason to send two shapes.
  ///
  /// Omitting it lets the server stamp `utcnow()`, which is right for a reading
  /// taken just now and wrong for one entered later — so the form always sends
  /// a value.
  Future<VitalSign> create({
    int? systolic,
    int? diastolic,
    int? heartRate,
    double? weight,
    double? bloodSugar,
    double? temperature,
    int? oxygenSaturation,
    String? notes,
    DateTime? measuredAt,
  }) async {
    final json = await _client.post<Map<String, dynamic>>(
      _base,
      body: {
        'blood_pressure_systolic': ?systolic,
        'blood_pressure_diastolic': ?diastolic,
        'heart_rate': ?heartRate,
        'weight': ?weight,
        'blood_sugar': ?bloodSugar,
        'temperature': ?temperature,
        'oxygen_saturation': ?oxygenSaturation,
        'notes': ?notes,
        if (measuredAt != null) 'measured_at': MediTime.naiveUtc(measuredAt),
      },
    );
    return VitalSign.fromJson(json);
  }

  /// `DELETE /api/vitals/{id}` — a hard delete, unlike medicines. There is no
  /// restore, which is why the UI confirms first.
  Future<void> remove(String id) => _client.delete<void>('$_base/$id');
}
