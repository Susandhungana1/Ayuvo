/// The timestamp trap, pinned.
///
/// These tests are the reason `MediTime` exists. If someone replaces a call
/// with `DateTime.parse`, the third test fails by exactly the local offset.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ayuvo/core/time/medi_time.dart';

void main() {
  group('parseUtc', () {
    test('reads a space-separated naive timestamp as UTC', () {
      final parsed = MediTime.parseUtc('2026-08-06 09:14:22.841913');
      expect(parsed, isNotNull);
      expect(parsed!.toUtc().hour, 9);
      expect(parsed.toUtc().minute, 14);
    });

    test('reads the T-separated variant the same way', () {
      // share.expires_at uses this shape; medicines.created_at uses the other.
      // They mean the same thing and must decode the same.
      final space = MediTime.parseUtc('2026-08-07 09:14:22');
      final tee = MediTime.parseUtc('2026-08-07T09:14:22');
      expect(space, tee);
    });

    test('does not double-shift a timestamp that already carries Z', () {
      // care_links.created_at and medicine_audit.created_at go through
      // `utc_iso` and arrive with a marker. Appending another would be wrong.
      final marked = MediTime.parseUtc('2026-08-06T09:14:22Z');
      expect(marked!.toUtc().hour, 9);
    });

    test('honours an explicit offset instead of overwriting it', () {
      final offset = MediTime.parseUtc('2026-08-06T09:14:22+05:45');
      expect(offset!.toUtc().hour, 3);
      expect(offset.toUtc().minute, 29);
    });

    test('a malformed timestamp is a missing timestamp, not a crash', () {
      // A medicine row with a bad created_at must still render.
      expect(MediTime.parseUtc('not a date'), isNull);
      expect(MediTime.parseUtc(''), isNull);
      expect(MediTime.parseUtc(null), isNull);
    });
  });

  group('parseWallClock', () {
    test('leaves an appointment time exactly as the server stored it', () {
      // The client sent naive local and the server kept it verbatim, so the
      // digits are already the time to show. Shifting them would move every
      // appointment by the UTC offset.
      final parsed = MediTime.parseWallClock('2026-08-12T10:30:00');
      expect(parsed!.hour, 10);
      expect(parsed.minute, 30);
      expect(parsed.isUtc, isFalse);
    });
  });

  group('parseDate', () {
    test('keeps the day for a date-only value', () {
      final parsed = MediTime.parseDate('2026-08-06');
      expect(parsed, DateTime(2026, 8, 6));
    });

    test('throws away the time rather than converting it', () {
      // report_date arrives as a whole datetime at midnight. Converting it to
      // local moves the date backwards a day for anyone west of UTC.
      final parsed = MediTime.parseDate('2026-08-06T00:00:00');
      expect(parsed, DateTime(2026, 8, 6));
    });
  });

  group('sending', () {
    test('naiveUtc emits no zone marker', () {
      final moment = DateTime.utc(2026, 8, 6, 9, 14, 22);
      expect(MediTime.naiveUtc(moment), '2026-08-06T09:14:22');
    });

    test('naiveLocal emits the wall clock with no zone marker', () {
      // An aware datetime makes AppointmentCreate's validator raise — a 500,
      // not a 422. The absence of an offset here is load-bearing.
      final moment = DateTime(2026, 8, 12, 10, 30);
      expect(MediTime.naiveLocal(moment), '2026-08-12T10:30:00');
      expect(MediTime.naiveLocal(moment), isNot(contains('+')));
      expect(MediTime.naiveLocal(moment), isNot(endsWith('Z')));
    });

    test('dateOnly round-trips a medicine start date', () {
      expect(MediTime.dateOnly(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('clock pads both halves', () {
      expect(MediTime.clock(8, 5), '08:05');
      expect(MediTime.clock(20, 0), '20:00');
    });
  });

  group('display', () {
    final now = DateTime(2026, 8, 6, 15, 0);

    test('day names today and yesterday', () {
      expect(MediTime.day(DateTime(2026, 8, 6, 9), now: now), 'Today');
      expect(MediTime.day(DateTime(2026, 8, 5, 23), now: now), 'Yesterday');
    });

    test('day drops the year within the current year and keeps it otherwise',
        () {
      expect(MediTime.day(DateTime(2026, 3, 2), now: now), isNot(contains('2026')));
      expect(MediTime.day(DateTime(2025, 3, 2), now: now), contains('2025'));
    });

    test('ago gets coarser as it gets older', () {
      expect(MediTime.ago(now.subtract(const Duration(seconds: 20)), now: now),
          'just now');
      expect(MediTime.ago(now.subtract(const Duration(minutes: 12)), now: now),
          '12 min ago');
      expect(MediTime.ago(now.subtract(const Duration(hours: 3)), now: now),
          '3 h ago');
      expect(MediTime.ago(now.subtract(const Duration(days: 3)), now: now),
          '3 d ago');
    });

    test('until reads as a countdown and never as a negative one', () {
      expect(MediTime.until(const Duration(minutes: 12)), 'in 12 min');
      expect(MediTime.until(const Duration(hours: 4, minutes: 20)), 'in 4 h 20 m');
      expect(MediTime.until(const Duration(hours: 2)), 'in 2 h');
      expect(MediTime.until(const Duration(seconds: -30)), 'now');
    });

    test('clockLabel turns 24-hour storage into the reader\'s convention', () {
      // Whatever the locale renders, it must not be the raw stored string.
      expect(MediTime.clockLabel('20:00'), isNot('20:00'));
      // And an unparseable value survives rather than disappearing.
      expect(MediTime.clockLabel('whenever'), 'whenever');
    });
  });
}
