/// `/api/doctors/*` in Dart — a practitioner, and the hours they post.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'doctor.freezed.dart';
part 'doctor.g.dart';

@freezed
abstract class Doctor with _$Doctor {
  const factory Doctor({
    /// The `Doctor` row's UUID. Every availability and booking route wants
    /// **this**, never [userId] — passing the user id is the mistake the web
    /// availability editor shipped with (`FEATURE_MAP.md` §7.2).
    required String id,

    /// Nepal Medical Council registration number.
    required String nmid,
    required String degree,
    String? specialty,

    /// Set by an operator with a `psql` update, never by this app. An
    /// unverified doctor is invisible to `GET /api/doctors/doctors`.
    required bool verified,
    @JsonKey(name: 'user_id') required String userId,

    /// The `User.name` behind the profile, joined server-side.
    required String name,
  }) = _Doctor;

  const Doctor._();

  factory Doctor.fromJson(Map<String, dynamic> json) => _$DoctorFromJson(json);

  /// `MBBS · Cardiology` — what a patient picks a doctor by.
  String get credentials => [
        if (degree.trim().isNotEmpty) degree.trim(),
        if (specialty?.trim().isNotEmpty ?? false) specialty!.trim(),
      ].join(' · ');
}

/// The seven weekdays, in the server's spelling and the week's order.
enum Weekday {
  monday('MONDAY', 'Monday', 'Mon'),
  tuesday('TUESDAY', 'Tuesday', 'Tue'),
  wednesday('WEDNESDAY', 'Wednesday', 'Wed'),
  thursday('THURSDAY', 'Thursday', 'Thu'),
  friday('FRIDAY', 'Friday', 'Fri'),
  saturday('SATURDAY', 'Saturday', 'Sat'),
  sunday('SUNDAY', 'Sunday', 'Sun');

  const Weekday(this.wire, this.label, this.shortLabel);

  final String wire;
  final String label;
  final String shortLabel;

  /// The weekday a `DateTime` falls on. `DateTime.weekday` is 1 = Monday, and
  /// so is this list — the server derives the same value from
  /// `datetime.weekday()`, so a date resolves to the same window on both sides.
  static Weekday of(DateTime day) => values[day.weekday - 1];

  static Weekday? tryParse(String wire) {
    for (final day in values) {
      if (day.wire == wire) return day;
    }
    return null;
  }
}

/// One posted window, from `GET /api/doctors/availability`.
///
/// `start_time` and `end_time` arrive as `"09:00:00"` — a clock time with no
/// date, which is exactly what they mean. They are kept as strings rather than
/// parsed into a `DateTime` on some arbitrary day, because the only operations
/// that matter are comparing and displaying them.
@freezed
abstract class AvailabilityWindow with _$AvailabilityWindow {
  const factory AvailabilityWindow({
    required String id,
    @JsonKey(name: 'day_of_week') required String dayOfWeek,
    @JsonKey(name: 'start_time') required String startTime,
    @JsonKey(name: 'end_time') required String endTime,

    /// How far apart the generated slots sit. Drives `available-slots`, and the
    /// web editor never exposed it — so every window created there is on the
    /// 30-minute default whether the doctor wanted that or not.
    @JsonKey(name: 'slot_duration_minutes') required int slotDurationMinutes,

    /// A window switched off still exists; it just generates no slots. That is
    /// how a doctor takes a Tuesday off without losing their Tuesday hours.
    @JsonKey(name: 'is_available') required bool isAvailable,
  }) = _AvailabilityWindow;

  const AvailabilityWindow._();

  factory AvailabilityWindow.fromJson(Map<String, dynamic> json) =>
      _$AvailabilityWindowFromJson(json);

  Weekday? get day => Weekday.tryParse(dayOfWeek);

  /// Minutes past midnight, for sorting windows within a day.
  int get startsAtMinute => _minutes(startTime);
  int get endsAtMinute => _minutes(endTime);

  static int _minutes(String clock) {
    final parts = clock.split(':');
    if (parts.length < 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }
}
