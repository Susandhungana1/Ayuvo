/// An appointment as an `.ics` file, so it can leave this app and land in the
/// calendar the person actually uses.
///
/// The web app does the same thing with `front/lib/ics.ts`; this is the same
/// output, built for a share sheet rather than a download.
///
/// **Floating times, deliberately.** `DTSTART` carries no `Z` and no `TZID`,
/// which in RFC 5545 means "this wall-clock time, wherever the calendar is".
/// That is exactly what `appointment_date` stores — a clinic at 9 am is at 9 am
/// — and stamping a zone onto it would move the entry for anyone who travels
/// between booking it and attending it.
library;

import '../../../core/time/medi_time.dart';
import 'appointment.dart';

abstract final class CalendarInvite {
  /// The whole file, CRLF-delimited as the spec requires. Calendar apps are
  /// forgiving about it; some parsers are not.
  static String of(Appointment appointment) {
    final start = appointment.startsAt;
    if (start == null) {
      throw ArgumentError.value(
        appointment.appointmentDate,
        'appointment_date',
        'not a datetime this app can read',
      );
    }
    final end = start.add(Duration(minutes: appointment.durationMinutes));

    final lines = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Ayuvo//Appointments//EN',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'BEGIN:VEVENT',
      // Stable per appointment, so re-sharing updates the entry rather than
      // creating a second one.
      'UID:${appointment.id}@ayuvo',
      'DTSTAMP:${_utcStamp(DateTime.now())}',
      'DTSTART:${_floating(start)}',
      'DTEND:${_floating(end)}',
      'SUMMARY:${_escape(appointment.title)}',
      if (appointment.who.isNotEmpty)
        'LOCATION:${_escape(appointment.who)}',
      if (appointment.reason?.trim().isNotEmpty ?? false)
        'DESCRIPTION:${_escape(appointment.reason!.trim())}',
      'STATUS:${_icsStatus(appointment)}',
      'END:VEVENT',
      'END:VCALENDAR',
    ];
    return '${lines.join('\r\n')}\r\n';
  }

  /// `appointment-2026-08-12-0900.ics` — a name that sorts and reads.
  static String fileName(Appointment appointment) {
    final start = appointment.startsAt;
    if (start == null) return 'appointment.ics';
    return 'appointment-${MediTime.dateOnly(start)}'
        '-${_two(start.hour)}${_two(start.minute)}.ics';
  }

  /// `CANCELLED` is the only status worth carrying: a calendar that knows an
  /// entry is cancelled greys it out instead of ringing about it.
  static String _icsStatus(Appointment appointment) =>
      appointment.state == AppointmentStatus.cancelled
          ? 'CANCELLED'
          : 'CONFIRMED';

  static String _floating(DateTime when) =>
      '${when.year.toString().padLeft(4, '0')}${_two(when.month)}'
      '${_two(when.day)}T${_two(when.hour)}${_two(when.minute)}'
      '${_two(when.second)}';

  static String _utcStamp(DateTime when) => '${_floating(when.toUtc())}Z';

  static String _two(int value) => value.toString().padLeft(2, '0');

  /// RFC 5545 §3.3.11: backslash, semicolon and comma are delimiters inside a
  /// text value, and a newline is written as `\n`. A doctor's name with a comma
  /// in it silently truncates the field otherwise.
  static String _escape(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll(';', r'\;')
      .replaceAll(',', r'\,')
      .replaceAll('\r\n', r'\n')
      .replaceAll('\n', r'\n');
}
