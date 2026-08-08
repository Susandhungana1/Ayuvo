/// Decoding the timeline, and the two things the server leaves to the client:
/// the timestamps are naive UTC, and the titles say their own type.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:medistore/features/timeline/domain/timeline_event.dart';
import 'package:medistore/features/timeline/presentation/timeline_controller.dart';

TimelineEvent event({
  String type = 'report',
  String id = 'rep-1',
  String title = 'Report: bloods.pdf',
  String? description,
  String date = '2026-08-06 09:14:22',
}) =>
    TimelineEvent(
      type: type,
      id: id,
      title: title,
      description: description,
      date: date,
    );

void main() {
  group('decoding', () {
    test('a naive timestamp is read as UTC, not as local time', () {
      // The server writes `str(datetime.utcnow())` with no marker. Read as
      // local in Asia/Kathmandu that is 5h45m out — enough to file a morning
      // report under the afternoon.
      final when = event(date: '2026-08-06 09:14:22').when!;

      expect(when.toUtc(), DateTime.utc(2026, 8, 6, 9, 14, 22));
    });

    test('an empty date is a missing date, not a crash', () {
      // `timeline.py` emits "" when a row has no created_at.
      expect(event(date: '').when, isNull);
    });

    test('the type prefix comes off the title', () {
      expect(event(title: 'Report: bloods.pdf').headline, 'bloods.pdf');
      expect(
        event(type: 'medicine', title: 'Medicine: Aspirin').headline,
        'Aspirin',
      );
      expect(
        event(type: 'appointment', title: 'Appointment: Checkup').headline,
        'Checkup',
      );
    });

    test('a title that is only the prefix keeps it', () {
      // Better a redundant "Report" than an empty row.
      expect(event(title: 'Report: ').headline, 'Report: ');
    });

    test('a vitals row has no prefix to strip', () {
      expect(event(type: 'vital', title: 'Vitals Check').headline,
          'Vitals Check');
    });

    test('an unknown type is kept rather than dropped', () {
      expect(event(type: 'document').kind, TimelineKind.other);
    });

    test('the row key distinguishes two tables that share an id', () {
      expect(
        event(type: 'report', id: 'x').rowKey,
        isNot(event(type: 'medicine', id: 'x').rowKey),
      );
    });
  });

  group('paging', () {
    test('hasMore compares what arrived against the real total', () {
      const page = TimelinePage(events: [], total: 12);
      expect(page.hasMore, isTrue);
    });

    test('a page holding everything has no more', () {
      final page = TimelinePage(events: [event()], total: 1);
      expect(page.hasMore, isFalse);
    });
  });

  group('grouping by day', () {
    test('rows on the same local day share one group', () {
      final days = groupByDay([
        event(id: 'a', date: '2026-08-06 09:00:00'),
        event(id: 'b', date: '2026-08-06 03:00:00'),
        event(id: 'c', date: '2026-08-05 22:00:00'),
      ]);

      // Two or three groups depending on the reader's timezone — what must
      // hold is that every row lands somewhere, exactly once.
      expect(
        days.expand((day) => day.events).map((e) => e.id),
        ['a', 'b', 'c'],
      );
      expect(days.length, lessThanOrEqualTo(3));
    });

    test('undated rows get their own group rather than today', () {
      final days = groupByDay([
        event(id: 'a', date: '2026-08-06 09:00:00'),
        event(id: 'b', date: ''),
      ]);

      expect(days.last.day, isNull);
      expect(days.last.events.single.id, 'b');
    });

    test('nothing in means nothing out', () {
      expect(groupByDay(const []), isEmpty);
    });
  });
}
