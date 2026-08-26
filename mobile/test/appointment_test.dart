/// The appointment domain, where the traps are.
///
/// `appointment_date` is the one timestamp in this API that must **not** be
/// shifted, and the slot filter is the only place the patient's real clock is
/// known. Both are pinned here rather than in a widget test, because both are
/// arithmetic.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ayuvo/features/appointments/domain/appointment.dart';
import 'package:ayuvo/features/appointments/domain/calendar_invite.dart';
import 'package:ayuvo/features/appointments/presentation/appointments_controller.dart';

Appointment _appointment({
  String id = 'apt-1',
  String title = 'Cardiology follow-up',
  String date = '2030-08-12T09:00:00',
  int minutes = 30,
  String status = 'CONFIRMED',
  String? doctorName = 'Dr Asha Rai',
  String? hospital,
  String? reason,
}) =>
    Appointment(
      id: id,
      title: title,
      appointmentDate: date,
      durationMinutes: minutes,
      status: status,
      doctorName: doctorName,
      hospital: hospital,
      reason: reason,
    );

void main() {
  group('appointment_date is wall clock', () {
    test('9 am reads as 9 am, whatever the device zone', () {
      final start = _appointment(date: '2030-08-12T09:00:00').startsAt!;
      expect(start.hour, 9);
      expect(start.minute, 0);
      expect(start.day, 12);
    });

    test('a space separator parses the same as a T', () {
      expect(
        _appointment(date: '2030-08-12 09:00:00').startsAt,
        DateTime(2030, 8, 12, 9),
      );
    });

    test('the end is the start plus the duration', () {
      final appointment = _appointment(minutes: 45);
      expect(appointment.endsAt, DateTime(2030, 8, 12, 9, 45));
    });

    test('an unreadable date is null, not a crash', () {
      expect(_appointment(date: 'not a date').startsAt, isNull);
    });
  });

  group('status', () {
    test('a known status gets its own words', () {
      expect(_appointment(status: 'PENDING').statusLabel,
          'Awaiting confirmation');
      expect(_appointment(status: 'COMPLETED').statusLabel, 'Completed');
    });

    test('an unknown status shows its raw value rather than a guess', () {
      expect(_appointment(status: 'RESCHEDULED').statusLabel, 'RESCHEDULED');
      expect(_appointment(status: 'RESCHEDULED').state, isNull);
    });

    test('cancelled and completed are closed; the other two are not', () {
      expect(_appointment(status: 'CANCELLED').isClosed, isTrue);
      expect(_appointment(status: 'COMPLETED').isClosed, isTrue);
      expect(_appointment(status: 'PENDING').isClosed, isFalse);
      expect(_appointment(status: 'CONFIRMED').isClosed, isFalse);
    });

    test('a cancelled future appointment is not upcoming', () {
      final now = DateTime(2030, 8, 1);
      expect(_appointment(status: 'CANCELLED').isUpcoming(now: now), isFalse);
      expect(_appointment(status: 'CONFIRMED').isUpcoming(now: now), isTrue);
    });
  });

  test('who joins doctor and hospital, skipping the blanks', () {
    expect(_appointment(hospital: 'Bir Hospital').who,
        'Dr Asha Rai · Bir Hospital');
    expect(_appointment(doctorName: null, hospital: 'Bir Hospital').who,
        'Bir Hospital');
    expect(_appointment(doctorName: null).who, isEmpty);
  });

  group('splitAppointments', () {
    final now = DateTime(2030, 8, 10, 12);
    final soon = _appointment(id: 'soon', date: '2030-08-12T09:00:00');
    final later = _appointment(id: 'later', date: '2030-09-01T09:00:00');
    final lastWeek = _appointment(id: 'old', date: '2030-08-03T09:00:00');
    final older = _appointment(id: 'older', date: '2030-07-01T09:00:00');

    test('upcoming keeps the server order, soonest first', () {
      final split = splitAppointments([soon, later], now: now);
      expect(split.upcoming.map((a) => a.id), ['soon', 'later']);
      expect(split.past, isEmpty);
    });

    test('past reads backwards — the most recent visit first', () {
      final split = splitAppointments([older, lastWeek], now: now);
      expect(split.past.map((a) => a.id), ['old', 'older']);
    });

    test('a cancelled future booking lands in past, not upcoming', () {
      final cancelled = _appointment(
        id: 'off',
        date: '2030-08-20T09:00:00',
        status: 'CANCELLED',
      );
      final split = splitAppointments([soon, cancelled], now: now);
      expect(split.upcoming.map((a) => a.id), ['soon']);
      expect(split.past.map((a) => a.id), ['off']);
    });
  });

  group('bookableSlots', () {
    AppointmentSlot slot(String start, String end) =>
        AppointmentSlot(startTime: start, endTime: end);

    test('drops slots that have already started', () {
      final slots = [
        slot('2030-08-12T09:00:00', '2030-08-12T09:30:00'),
        slot('2030-08-12T14:00:00', '2030-08-12T14:30:00'),
      ];
      final left = bookableSlots(slots, now: DateTime(2030, 8, 12, 10));
      expect(left.single.start, DateTime(2030, 8, 12, 14));
    });

    test('keeps everything on a future day', () {
      final slots = [slot('2030-08-13T09:00:00', '2030-08-13T09:30:00')];
      expect(
        bookableSlots(slots, now: DateTime(2030, 8, 12, 23)).length,
        1,
      );
    });

    test('a slot starting exactly now is gone', () {
      final slots = [slot('2030-08-12T10:00:00', '2030-08-12T10:30:00')];
      expect(bookableSlots(slots, now: DateTime(2030, 8, 12, 10)), isEmpty);
    });

    test('minutes comes off the two ends', () {
      expect(slot('2030-08-12T09:00:00', '2030-08-12T09:45:00').minutes, 45);
    });
  });

  group('CalendarInvite', () {
    test('DTSTART is floating — no Z, no TZID', () {
      final ics = CalendarInvite.of(_appointment());
      expect(ics, contains('DTSTART:20300812T090000\r\n'));
      expect(ics, contains('DTEND:20300812T093000\r\n'));
      expect(ics, isNot(contains('DTSTART:20300812T090000Z')));
      expect(ics, isNot(contains('TZID')));
    });

    test('the UID is stable, so re-sharing updates one entry', () {
      final ics = CalendarInvite.of(_appointment(id: 'apt-9'));
      expect(ics, contains('UID:apt-9@ayuvo\r\n'));
    });

    test('commas in a name are escaped, not left to truncate the field', () {
      final ics = CalendarInvite.of(
        _appointment(doctorName: 'Rai, Asha', hospital: 'Bir; Kathmandu'),
      );
      expect(ics, contains(r'LOCATION:Rai\, Asha · Bir\; Kathmandu'));
    });

    test('a cancelled appointment says so, so the calendar greys it out', () {
      expect(
        CalendarInvite.of(_appointment(status: 'CANCELLED')),
        contains('STATUS:CANCELLED'),
      );
    });

    test('the reason becomes the description; absent, no line at all', () {
      expect(
        CalendarInvite.of(_appointment(reason: 'Six-month review')),
        contains('DESCRIPTION:Six-month review'),
      );
      expect(
        CalendarInvite.of(_appointment()),
        isNot(contains('DESCRIPTION:')),
      );
    });

    test('the file name carries the date and time', () {
      expect(
        CalendarInvite.fileName(_appointment()),
        'appointment-2030-08-12-0900.ics',
      );
    });

    test('an unreadable date throws rather than emitting a broken file', () {
      expect(
        () => CalendarInvite.of(_appointment(date: 'nonsense')),
        throwsArgumentError,
      );
    });
  });
}
