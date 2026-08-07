/// The vitals list as state.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../data/vital_repository.dart';
import '../domain/vital_sign.dart';

/// How many readings the app holds. 200 is the server's ceiling, and asking for
/// all of them once beats paging a list this small — a person records a handful
/// of readings a week, not thousands.
const vitalsPageSize = 200;

final vitalsProvider =
    AsyncNotifierProvider<VitalsController, List<VitalSign>>(
  VitalsController.new,
);

class VitalsController extends AsyncNotifier<List<VitalSign>> {
  VitalRepository get _repository => ref.read(vitalRepositoryProvider);

  @override
  Future<List<VitalSign>> build() async {
    if (ref.watch(currentUserProvider) == null) return const [];
    return _repository.list(limit: vitalsPageSize);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => _repository.list(limit: vitalsPageSize),
    );
  }

  Future<VitalSign> add({
    int? systolic,
    int? diastolic,
    int? heartRate,
    double? weight,
    double? bloodSugar,
    double? temperature,
    int? oxygenSaturation,
    String? notes,
    required DateTime measuredAt,
  }) async {
    final created = await _repository.create(
      systolic: systolic,
      diastolic: diastolic,
      heartRate: heartRate,
      weight: weight,
      bloodSugar: bloodSugar,
      temperature: temperature,
      oxygenSaturation: oxygenSaturation,
      notes: notes,
      measuredAt: measuredAt,
    );
    // Ordered by `measured_at` descending, and a reading can be backdated — so
    // insert by date rather than assuming the newest entry is the latest one.
    final list = [...state.valueOrNull ?? const <VitalSign>[], created]
      ..sort((a, b) {
        final left = a.measured;
        final right = b.measured;
        if (left == null || right == null) return 0;
        return right.compareTo(left);
      });
    state = AsyncData(list);
    return created;
  }

  /// Hard delete — there is no restore route for a vital sign.
  Future<void> remove(String id) async {
    await _repository.remove(id);
    state = AsyncData([
      for (final reading in state.valueOrNull ?? const <VitalSign>[])
        if (reading.id != id) reading,
    ]);
  }
}

/// The most recent reading, or null. What the dashboard tiles read.
final latestVitalProvider = Provider<VitalSign?>((ref) {
  final list = ref.watch(vitalsProvider).valueOrNull;
  if (list == null) return null;
  // The newest row that actually measured something. `POST /api/vitals`
  // accepts a body where every field is null and the web app's form will send
  // one, so "the latest reading" and "the latest row" are not the same thing —
  // and a dashboard that treats an empty row as data shows a patient nothing
  // while also hiding the prompt to record something.
  for (final reading in list) {
    if (!reading.isEmpty) return reading;
  }
  return null;
});
