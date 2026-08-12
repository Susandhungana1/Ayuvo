/// The timeline as state: one page at a time, appended.
///
/// Paged rather than loaded whole because `timeline.py` reads every report,
/// medicine, appointment and vital the account owns before it slices — a
/// five-year record is one query away from being slow, and asking for all of it
/// on screen open would make the tab feel broken.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../data/timeline_repository.dart';
import '../domain/timeline_event.dart';

/// One screenful and a bit. Small enough that the first page is quick, large
/// enough that most people never press "Show older".
const timelinePageSize = 40;

@immutable
class TimelineState {
  const TimelineState({
    this.events = const [],
    this.total = 0,
    this.loadingMore = false,
    this.moreFailed,
  });

  final List<TimelineEvent> events;

  /// Every row the account has, not just the ones fetched.
  final int total;

  final bool loadingMore;

  /// Why the last "Show older" failed. Kept separate from the screen's own
  /// error state: a failed *next* page must not blank out the rows already on
  /// screen.
  final Object? moreFailed;

  bool get hasMore => events.length < total;

  TimelineState copyWith({
    List<TimelineEvent>? events,
    int? total,
    bool? loadingMore,
    Object? moreFailed,
    bool clearFailure = false,
  }) =>
      TimelineState(
        events: events ?? this.events,
        total: total ?? this.total,
        loadingMore: loadingMore ?? this.loadingMore,
        moreFailed: clearFailure ? null : (moreFailed ?? this.moreFailed),
      );
}

/// Events grouped into the local days they happened on, newest day first.
///
/// Grouping happens here rather than in the widget so the day boundaries are
/// computed once per load instead of once per rebuild, and so a row with an
/// unparseable date has one defined home.
@immutable
class TimelineDay {
  const TimelineDay({required this.day, required this.events});

  /// Null for rows whose `date` would not parse — the server writes `""` when a
  /// `created_at` is missing, and those are real rows worth showing.
  final DateTime? day;
  final List<TimelineEvent> events;
}

final timelineProvider =
    AsyncNotifierProvider<TimelineController, TimelineState>(
  TimelineController.new,
);

class TimelineController extends AsyncNotifier<TimelineState> {
  TimelineRepository get _repository => ref.read(timelineRepositoryProvider);

  @override
  Future<TimelineState> build() async {
    if (ref.watch(currentUserProvider) == null) return const TimelineState();
    final page = await _repository.page(limit: timelinePageSize);
    return TimelineState(events: page.events, total: page.total);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() async {
      final page = await _repository.page(limit: timelinePageSize);
      return TimelineState(events: page.events, total: page.total);
    });
  }

  /// Appends the next page. Never replaces the state with an error — the rows
  /// already on screen are still true.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) return;

    state = AsyncData(current.copyWith(loadingMore: true, clearFailure: true));
    try {
      final page = await _repository.page(
        limit: timelinePageSize,
        offset: current.events.length,
      );
      state = AsyncData(
        TimelineState(
          events: [...current.events, ...page.events],
          // The total can move between pages — a report uploaded on another
          // device lands mid-scroll — so it is taken from the newest answer.
          total: page.total,
        ),
      );
    } catch (error) {
      state = AsyncData(current.copyWith(loadingMore: false, moreFailed: error));
    }
  }
}

/// [TimelineState.events] grouped by local day.
final timelineDaysProvider = Provider<List<TimelineDay>>((ref) {
  final events = ref.watch(timelineProvider).valueOrNull?.events ?? const [];
  return groupByDay(events);
});

@visibleForTesting
List<TimelineDay> groupByDay(List<TimelineEvent> events) {
  final days = <TimelineDay>[];
  DateTime? currentKey;
  var bucket = <TimelineEvent>[];
  var started = false;

  void flush() {
    if (bucket.isNotEmpty) {
      days.add(TimelineDay(day: currentKey, events: bucket));
    }
  }

  for (final event in events) {
    final when = event.when;
    final key = when == null ? null : DateTime(when.year, when.month, when.day);
    // The list arrives sorted, so a change of day ends the current group. No
    // map, no re-sort — and two runs of the same date stay separate only if the
    // server ever sends them unsorted, which it does not.
    if (!started || key != currentKey) {
      flush();
      currentKey = key;
      bucket = <TimelineEvent>[];
      started = true;
    }
    bucket.add(event);
  }
  flush();
  return days;
}
