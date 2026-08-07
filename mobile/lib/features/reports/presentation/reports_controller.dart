/// Reports as state, plus the two per-report calls that are made on demand
/// rather than with the list.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../data/report_repository.dart';
import '../domain/report.dart';

final reportsProvider =
    AsyncNotifierProvider<ReportsController, List<MedicalReport>>(
  ReportsController.new,
);

class ReportsController extends AsyncNotifier<List<MedicalReport>> {
  ReportRepository get _repository => ref.read(reportRepositoryProvider);

  @override
  Future<List<MedicalReport>> build() async {
    if (ref.watch(currentUserProvider) == null) return const [];
    return _repository.list();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repository.list);
  }

  /// Adds an already-uploaded report to the list. Upload itself lives in the
  /// upload controller, which needs progress and this does not.
  void remember(MedicalReport report) {
    state = AsyncData([report, ...state.valueOrNull ?? const []]);
    // The new report may add points to a lab series, so the trends the screen
    // is showing are now out of date.
    ref.invalidate(reportTrendsProvider);
  }

  Future<void> remove(String id) async {
    await _repository.remove(id);
    state = AsyncData([
      for (final report in state.valueOrNull ?? const <MedicalReport>[])
        if (report.id != id) report,
    ]);
    ref.invalidate(reportTrendsProvider);
  }
}

/// `GET /api/reports/trends`.
final reportTrendsProvider = FutureProvider<List<TrendSeries>>((ref) async {
  if (ref.watch(currentUserProvider) == null) return const [];
  return ref.watch(reportRepositoryProvider).trends();
});

/// `GET /api/reports/{id}/lab-analysis`, fetched when the screen is opened.
final labAnalysisProvider =
    FutureProvider.autoDispose.family<LabAnalysis, String>(
  (ref, id) => ref.watch(reportRepositoryProvider).labAnalysis(id),
);

/// `POST /api/reports/{id}/explain`.
///
/// A POST behind a provider, so it runs once per screen rather than on every
/// rebuild — and auto-disposes, because the explanation is regenerated each
/// time and there is nothing worth caching between visits.
final explanationProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, id) => ref.watch(reportRepositoryProvider).explain(id),
);
