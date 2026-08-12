/// Every timestamp in this API, decoded in one place.
///
/// The server stores with `datetime.utcnow()` and serialises with `str(dt)` or
/// bare Pydantic ISO, so most timestamps arrive as **naive UTC** — the right
/// instant with no marker saying so:
///
///     "2026-08-06 09:14:22.841913"   medicines.created_at, vitals.measured_at,
///                                    intake.recorded_at, timeline.date
///     "2026-08-07T09:14:22"          share.expires_at
///
/// `DateTime.parse` reads those as **local**, which in Asia/Kathmandu is 5h45m
/// wrong in the direction that makes a reading taken this morning look like it
/// happened this afternoon. Every one of them must go through [parseUtc].
///
/// Three fields already carry `Z` because they pass through
/// `app/core/care.py::utc_iso` — `care_links.created_at`,
/// `care_invites.expires_at`, `medicine_audit.created_at`. [parseUtc] handles
/// those too: an explicit marker is honoured rather than overwritten.
///
/// Two lookalikes must **not** be shifted:
///   * `appointment_date` — the client sends naive *local* and the server keeps
///     it verbatim, so it comes back as the wall-clock time it was booked for.
///     Use [parseWallClock].
///   * `report_date` / `checkup_date` — dates wearing a datetime's clothes.
///     Use [parseDate], which throws the time away rather than rounding it.
///
/// Sending is the mirror image, and getting it wrong is worse than getting
/// reading wrong: `AppointmentCreate` compares a submitted datetime against
/// `datetime.now()`, and an aware datetime makes that comparison raise — a 500,
/// not a validation error. [naiveUtc] and [naiveLocal] both emit naive strings.
library;

import 'package:intl/intl.dart';

abstract final class MediTime {
  /// A naive-UTC (or explicitly-UTC) timestamp, as a **local** [DateTime].
  ///
  /// Returns null for null, empty, or unparseable input. A malformed timestamp
  /// is a missing timestamp — a list of medicines must not fail to render
  /// because one row has a bad `created_at`.
  static DateTime? parseUtc(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return null;

    // "2026-08-06 09:14:22" → "2026-08-06T09:14:22"
    var normalised = text.replaceFirst(' ', 'T');
    if (!_hasZone.hasMatch(normalised)) normalised = '${normalised}Z';

    return DateTime.tryParse(normalised)?.toLocal();
  }

  /// A timestamp the server stored exactly as the client sent it, so its digits
  /// are already the wall-clock time to display. No shift.
  static DateTime? parseWallClock(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return null;
    return DateTime.tryParse(text.replaceFirst(' ', 'T'));
  }

  /// A date-only value that may arrive as `"2026-08-06"` or as a whole
  /// datetime. The time part is discarded rather than converted: shifting
  /// `2026-08-06T00:00:00` into local time moves the *date* backwards a day for
  /// anyone west of UTC, which is how a report dated the 6th ends up filed
  /// under the 5th.
  static DateTime? parseDate(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return null;
    final parsed = DateTime.tryParse(text.replaceFirst(' ', 'T'));
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  /// For `measured_at`: the instant, expressed as naive UTC, which is what the
  /// column holds.
  static String naiveUtc(DateTime moment) =>
      _isoSeconds.format(moment.toUtc());

  /// For `appointment_date`: the wall-clock time the user picked, with no zone
  /// attached. Sending `Z` or `+05:45` here 500s the server (§1.2).
  static String naiveLocal(DateTime moment) =>
      _isoSeconds.format(moment.toLocal());

  /// `"2026-08-06"` — for `start_date` / `end_date`, which the server compares
  /// as strings and must therefore never round-trip through a timezone.
  static String dateOnly(DateTime day) => _isoDate.format(day);

  /// `"08:00"` — the shape `taking_times` and `scheduled_time` use. Takes the
  /// two numbers rather than a `TimeOfDay` so this file never imports Flutter.
  static String clock(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  // ── Display ──────────────────────────────────────────────────────────────
  // Formats are looked up per call rather than cached in a static, so a change
  // of locale takes effect without a restart.

  /// `6 Aug 2026`
  static String date(DateTime when) => DateFormat.yMMMd().format(when);

  /// `6 Aug 2026, 2:59 pm`
  static String dateTime(DateTime when) =>
      '${DateFormat.yMMMd().format(when)}, ${DateFormat.jm().format(when)}';

  /// `2:59 pm`
  static String time(DateTime when) => DateFormat.jm().format(when);

  /// `2:59 pm` from an `"14:59"` string, or the string itself if it isn't one.
  /// Dose times are stored as 24-hour text; showing them in the user's own
  /// clock convention is worth the parse.
  static String clockLabel(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return hhmm;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return hhmm;
    return DateFormat.jm().format(DateTime(2000, 1, 1, hour, minute));
  }

  /// `Today` · `Yesterday` · `6 Aug` · `6 Aug 2025` — for list rows, where the
  /// year is noise until it isn't this year.
  static String day(DateTime when, {DateTime? now}) {
    final today = _midnight(now ?? DateTime.now());
    final that = _midnight(when);
    final days = today.difference(that).inDays;
    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (that.year == today.year) return DateFormat.MMMd().format(when);
    return DateFormat.yMMMd().format(when);
  }

  /// `just now` · `12 min ago` · `3 h ago` · `6 Aug` — for "when was this
  /// recorded", where precision stops mattering after a few hours.
  static String ago(DateTime when, {DateTime? now}) {
    final gap = (now ?? DateTime.now()).difference(when);
    if (gap.isNegative) return day(when, now: now);
    if (gap.inMinutes < 1) return 'just now';
    if (gap.inMinutes < 60) return '${gap.inMinutes} min ago';
    if (gap.inHours < 24) return '${gap.inHours} h ago';
    if (gap.inDays < 7) return '${gap.inDays} d ago';
    return day(when, now: now);
  }

  /// `in 4 h 20 m` · `in 12 min` — the next-dose countdown on the dashboard.
  /// Deliberately coarse above an hour: a countdown to the minute invites
  /// watching it.
  static String until(Duration gap) {
    if (gap.isNegative || gap.inMinutes < 1) return 'now';
    if (gap.inMinutes < 60) return 'in ${gap.inMinutes} min';
    final hours = gap.inHours;
    final minutes = gap.inMinutes % 60;
    if (hours < 24) {
      return minutes == 0 ? 'in $hours h' : 'in $hours h $minutes m';
    }
    return 'in ${gap.inDays} d';
  }

  static DateTime _midnight(DateTime when) =>
      DateTime(when.year, when.month, when.day);

  /// `Z`, `+05:45` or `-0800` at the end of the string.
  static final _hasZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');
  static final _isoSeconds = DateFormat("yyyy-MM-dd'T'HH:mm:ss");
  static final _isoDate = DateFormat('yyyy-MM-dd');
}
