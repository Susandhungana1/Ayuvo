/// `/api/appointments` in Dart.
///
/// One field here behaves unlike every other timestamp in the API.
/// `appointment_date` is stored exactly as the client sent it and returned
/// exactly as stored, so its digits *are* the wall-clock time of the
/// appointment. It goes through [MediTime.parseWallClock], never `parseUtc` —
/// shifting it would move a 9 am appointment to 3:15 pm in Kathmandu.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/time/medi_time.dart';

part 'appointment.freezed.dart';
part 'appointment.g.dart';

/// `AppointmentStatus`, from `server/app/models/models.py`.
///
/// Booking against a listed doctor yields `CONFIRMED` immediately; a free-text
/// doctor yields `PENDING`, because there is nobody on the other end to accept
/// it. That asymmetry is the server's, and both screens have to explain it.
enum AppointmentStatus {
  pending('PENDING', 'Awaiting confirmation'),
  confirmed('CONFIRMED', 'Confirmed'),
  cancelled('CANCELLED', 'Cancelled'),
  completed('COMPLETED', 'Completed');

  const AppointmentStatus(this.wire, this.label);

  final String wire;
  final String label;

  /// An unrecognised status shows its raw value rather than being relabelled.
  /// Nothing writes one today, but a status is the one field on this screen a
  /// patient acts on, and inventing a label for a value we do not understand
  /// is worse than showing the value.
  static String labelFor(String wire) => tryParse(wire)?.label ?? wire;

  static AppointmentStatus? tryParse(String wire) {
    for (final status in values) {
      if (status.wire == wire) return status;
    }
    return null;
  }
}

@freezed
abstract class Appointment with _$Appointment {
  const factory Appointment({
    required String id,
    required String title,
    String? description,

    /// `Doctor.id` — a UUID, and **not** the doctor's user id. Present only
    /// when the appointment was booked against a listed doctor.
    @JsonKey(name: 'doctor_id') String? doctorId,
    @JsonKey(name: 'doctor_name') String? doctorName,
    String? hospital,

    /// Naive *local* wall clock. See the library comment.
    @JsonKey(name: 'appointment_date') required String appointmentDate,
    @JsonKey(name: 'duration_minutes') required int durationMinutes,
    required String status,
    String? reason,

    /// Whether the server's reminder job has already emailed about this one.
    /// Read so the app never claims a reminder it did not send.
    @JsonKey(name: 'reminder_sent') @Default(false) bool reminderSent,
  }) = _Appointment;

  const Appointment._();

  factory Appointment.fromJson(Map<String, dynamic> json) =>
      _$AppointmentFromJson(json);

  DateTime? get startsAt => MediTime.parseWallClock(appointmentDate);

  DateTime? get endsAt =>
      startsAt?.add(Duration(minutes: durationMinutes));

  AppointmentStatus? get state => AppointmentStatus.tryParse(status);

  String get statusLabel => AppointmentStatus.labelFor(status);

  /// A booking nobody is going to attend. Kept in the list — a cancelled visit
  /// is part of the record — but sorted below and never counted as upcoming.
  bool get isClosed =>
      state == AppointmentStatus.cancelled ||
      state == AppointmentStatus.completed;

  bool isUpcoming({DateTime? now}) {
    final start = startsAt;
    if (start == null || isClosed) return false;
    return start.isAfter(now ?? DateTime.now());
  }

  /// Doctor, then hospital — whichever the booking actually carries.
  String get who => [
        if (doctorName?.trim().isNotEmpty ?? false) doctorName!.trim(),
        if (hospital?.trim().isNotEmpty ?? false) hospital!.trim(),
      ].join(' · ');
}

/// One bookable window from `GET /api/appointments/available-slots/{id}`.
///
/// Both ends are naive local wall clock: the server builds them with
/// `datetime.combine(date, availability.start_time)`, so they carry the
/// doctor's posted hours and no zone at all.
@freezed
abstract class AppointmentSlot with _$AppointmentSlot {
  const factory AppointmentSlot({
    @JsonKey(name: 'start_time') required String startTime,
    @JsonKey(name: 'end_time') required String endTime,
  }) = _AppointmentSlot;

  const AppointmentSlot._();

  factory AppointmentSlot.fromJson(Map<String, dynamic> json) =>
      _$AppointmentSlotFromJson(json);

  DateTime? get start => MediTime.parseWallClock(startTime);
  DateTime? get end => MediTime.parseWallClock(endTime);

  int get minutes {
    final from = start;
    final to = end;
    if (from == null || to == null) return 0;
    return to.difference(from).inMinutes;
  }
}
