/// Weekday mapping and window grouping.
///
/// The weekday is the join between a doctor's posted hours and a patient's
/// chosen date. The server derives it from `datetime.weekday()`; this derives
/// it from `DateTime.weekday`. If the two ever disagreed, a patient would be
/// shown Tuesday's slots for a Wednesday and the booking would 400.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ayuvo/features/doctors/domain/doctor.dart';
import 'package:ayuvo/features/doctors/presentation/doctor_controllers.dart';

AvailabilityWindow _window({
  String id = 'a-1',
  String day = 'MONDAY',
  String start = '09:00:00',
  String end = '12:00:00',
  int slot = 30,
  bool available = true,
}) =>
    AvailabilityWindow(
      id: id,
      dayOfWeek: day,
      startTime: start,
      endTime: end,
      slotDurationMinutes: slot,
      isAvailable: available,
    );

void main() {
  group('Weekday', () {
    test('agrees with DateTime.weekday, Monday through Sunday', () {
      // 3 August 2026 is a Monday.
      expect(Weekday.of(DateTime(2026, 8, 3)), Weekday.monday);
      expect(Weekday.of(DateTime(2026, 8, 8)), Weekday.saturday);
      expect(Weekday.of(DateTime(2026, 8, 9)), Weekday.sunday);
    });

    test('parses the server spelling, and refuses anything else', () {
      expect(Weekday.tryParse('WEDNESDAY'), Weekday.wednesday);
      expect(Weekday.tryParse('Wednesday'), isNull);
      expect(Weekday.tryParse(''), isNull);
    });

    test('values are in week order, so a seven-card list reads right', () {
      expect(
        Weekday.values.map((d) => d.shortLabel),
        ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      );
    });
  });

  group('AvailabilityWindow', () {
    test('a clock time becomes minutes past midnight', () {
      final window = _window(start: '09:30:00', end: '17:00:00');
      expect(window.startsAtMinute, 570);
      expect(window.endsAtMinute, 1020);
    });

    test('an unparseable clock is zero rather than an exception', () {
      expect(_window(start: 'noon').startsAtMinute, 0);
    });
  });

  group('byWeekday', () {
    test('every day is present, even the empty ones', () {
      final grouped = byWeekday([_window()]);
      expect(grouped.keys.length, 7);
      expect(grouped[Weekday.tuesday], isEmpty);
    });

    test('a day with two windows keeps them in clock order', () {
      final grouped = byWeekday([
        _window(id: 'pm', start: '14:00:00', end: '17:00:00'),
        _window(id: 'am', start: '09:00:00', end: '12:00:00'),
      ]);
      expect(grouped[Weekday.monday]!.map((w) => w.id), ['am', 'pm']);
    });

    test('a switched-off window still appears — it is paused, not gone', () {
      final grouped = byWeekday([_window(available: false)]);
      expect(grouped[Weekday.monday]!.single.isAvailable, isFalse);
    });

    test('a window with an unreadable weekday is dropped, not crashed on', () {
      final grouped = byWeekday([_window(day: 'FUNDAY'), _window()]);
      expect(grouped.values.expand((w) => w).length, 1);
    });
  });

  group('Doctor', () {
    test('credentials join degree and specialty', () {
      const doctor = Doctor(
        id: 'd-1',
        nmid: 'NMC-1',
        degree: 'MBBS',
        specialty: 'Cardiology',
        verified: true,
        userId: '#doc002',
        name: 'Dr Asha Rai',
      );
      expect(doctor.credentials, 'MBBS · Cardiology');
    });

    test('no specialty leaves just the degree, with no stray separator', () {
      const doctor = Doctor(
        id: 'd-1',
        nmid: 'NMC-1',
        degree: 'MBBS',
        verified: false,
        userId: '#doc002',
        name: 'Dr Asha Rai',
      );
      expect(doctor.credentials, 'MBBS');
    });
  });
}
