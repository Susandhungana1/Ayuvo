/// Reports as state, plus the two per-report calls that are made on demand
/// rather than with the list.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../data/report_repository.dart';
import '../domain/report.dart';

const _pageSize = 20;

final reportsProvider =
    AsyncNotifierProvider<ReportsController, List<MedicalReport>>(
      ReportsController.new,
    );

final reportsTotalProvider = StateProvider<int>((ref) => 0);
final reportsOffsetProvider = StateProvider<int>((ref) => 0);
final reportsLoadingMoreProvider = StateProvider<bool>((ref) => false);

class ReportsController extends AsyncNotifier<List<MedicalReport>> {
  ReportRepository get _repository => ref.read(reportRepositoryProvider);

  @override
  Future<List<MedicalReport>> build() async {
    if (ref.watch(currentUserProvider) == null) return const [];
    final result = await _repository.list(limit: _pageSize);
    ref.read(reportsTotalProvider.notifier).state = result.total;
    ref.read(reportsOffsetProvider.notifier).state = result.reports.length;
    return result.reports;
  }

  Future<void> refresh() async {
    final result = await _repository.list(limit: _pageSize);
    ref.read(reportsTotalProvider.notifier).state = result.total;
    ref.read(reportsOffsetProvider.notifier).state = result.reports.length;
    state = AsyncData(result.reports);
  }

  Future<void> loadMore() async {
    final currentOffset = ref.read(reportsOffsetProvider);
    ref.read(reportsLoadingMoreProvider.notifier).state = true;
    try {
      final result = await _repository.list(
        offset: currentOffset,
        limit: _pageSize,
      );
      final prev = state.valueOrNull ?? const <MedicalReport>[];
      state = AsyncData([...prev, ...result.reports]);
      ref.read(reportsOffsetProvider.notifier).state =
          currentOffset + result.reports.length;
      ref.read(reportsTotalProvider.notifier).state = result.total;
    } finally {
      ref.read(reportsLoadingMoreProvider.notifier).state = false;
    }
  }

  /// Adds an already-uploaded report to the list. Upload itself lives in the
  /// upload controller, which needs progress and this does not.
  void remember(MedicalReport report) {
    state = AsyncData([report, ...state.valueOrNull ?? const []]);
    ref.read(reportsTotalProvider.notifier).state++;
    ref.read(reportsOffsetProvider.notifier).state++;
    ref.invalidate(reportTrendsProvider);
  }

  Future<void> remove(String id) async {
    await _repository.remove(id);
    state = AsyncData([
      for (final report in state.valueOrNull ?? const <MedicalReport>[])
        if (report.id != id) report,
    ]);
    ref.read(reportsTotalProvider.notifier).state--;
    ref.read(reportsOffsetProvider.notifier).state--;
    ref.invalidate(reportTrendsProvider);
  }
}

/// `GET /api/reports/trends`.
final reportTrendsProvider = FutureProvider<List<TrendSeries>>((ref) async {
  if (ref.watch(currentUserProvider) == null) return const [];
  return ref.watch(reportRepositoryProvider).trends();
});

/// `GET /api/reports/{id}/lab-analysis`, fetched when the screen is opened.
final labAnalysisProvider = FutureProvider.autoDispose
    .family<LabAnalysis, String>(
      (ref, id) => ref.watch(reportRepositoryProvider).labAnalysis(id),
    );

/// How many of a report's values are out of range, and which — the chip shown
/// on the list card. Skipped entirely for reports OCR read nothing from.
final labSummaryProvider = FutureProvider.autoDispose
    .family<LabSummary?, String>((ref, id) async {
      final reports = ref.watch(reportsProvider).valueOrNull ?? const [];
      MedicalReport? report;
      for (final candidate in reports) {
        if (candidate.id == id) {
          report = candidate;
          break;
        }
      }
      if (report == null || !report.hasText) return null;
      final analysis = await ref
          .watch(reportRepositoryProvider)
          .labAnalysis(id);
      if (!analysis.hasData) return null;
      return LabSummary.from(analysis);
    });

/// The abnormal readings of one report, for the list card chip.
@immutable
class LabSummary {
  const LabSummary({required this.abnormal, required this.names});

  final int abnormal;
  final List<String> names;

  factory LabSummary.from(LabAnalysis analysis) => LabSummary(
    abnormal: analysis.findings.where((f) => !f.isNormal).length,
    names: [
      for (final f in analysis.findings)
        if (!f.isNormal) f.name,
    ],
  );

  bool get isNotEmpty => abnormal > 0;
}
