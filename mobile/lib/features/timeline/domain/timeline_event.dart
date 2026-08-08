/// `GET /api/timeline` in Dart.
///
/// The server hands over rows that are already sentences: `"Report: bloods.pdf"`,
/// `"BP: 120/80, HR: 72"`. That is a display decision made in Python, and the
/// app cannot undo it — but it can stop repeating itself. [headline] strips the
/// `"Report: "` prefix so the row does not say "Report" twice, once in the badge
/// and once in the title.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/time/medi_time.dart';

part 'timeline_event.freezed.dart';
part 'timeline_event.g.dart';

/// What a row is. Unknown kinds are kept and shown plainly rather than dropped:
/// a future server that adds `document` should add a row here, not a hole.
enum TimelineKind { report, medicine, appointment, vital, other }

@freezed
abstract class TimelineEvent with _$TimelineEvent {
  const factory TimelineEvent({
    required String type,
    required String id,
    required String title,
    String? description,

    /// Naive UTC — `str(datetime)` with no marker. Read through [when].
    required String date,
  }) = _TimelineEvent;

  const TimelineEvent._();

  factory TimelineEvent.fromJson(Map<String, dynamic> json) =>
      _$TimelineEventFromJson(json);

  DateTime? get when => MediTime.parseUtc(date);

  TimelineKind get kind => switch (type) {
        'report' => TimelineKind.report,
        'medicine' => TimelineKind.medicine,
        'appointment' => TimelineKind.appointment,
        'vital' => TimelineKind.vital,
        _ => TimelineKind.other,
      };

  /// The title with the server's redundant type prefix removed.
  ///
  /// Only the exact prefixes `timeline.py` writes are stripped, and only when
  /// something is left afterwards — a report genuinely called "Medicine:" keeps
  /// its name.
  String get headline {
    for (final prefix in const ['Report: ', 'Medicine: ', 'Appointment: ']) {
      if (title.startsWith(prefix) && title.length > prefix.length) {
        return title.substring(prefix.length);
      }
    }
    return title;
  }

  /// A stable key for a list row. `id` alone is not enough: ids are unique per
  /// table, not across them.
  String get rowKey => '$type-$id';
}

/// One page of the timeline, plus how many rows exist in total.
///
/// [total] is what makes "Show older" honest — the server counts every row
/// before slicing, so the app knows when it has reached the end instead of
/// guessing from a short page.
@freezed
abstract class TimelinePage with _$TimelinePage {
  const factory TimelinePage({
    required List<TimelineEvent> events,
    required int total,
  }) = _TimelinePage;

  const TimelinePage._();

  factory TimelinePage.fromJson(Map<String, dynamic> json) =>
      _$TimelinePageFromJson(json);

  bool get hasMore => events.length < total;
}
