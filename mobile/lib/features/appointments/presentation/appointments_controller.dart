/// Appointments as state — the patient's list, the doctor's inbox, and the
/// slot lookup the booking flow runs on.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../data/appointment_repository.dart';
import '../domain/appointment.dart';

final appointmentsProvider =
    AsyncNotifierProvider<AppointmentsController, List<Appointment>>(
  AppointmentsController.new,
);

class AppointmentsController extends AsyncNotifier<List<Appointment>> {
  AppointmentRepository get _repository =>
      ref.read(appointmentRepositoryProvider);

  @override
  Future<List<Appointment>> build() async {
    if (ref.watch(currentUserProvider) == null) return const [];
    return _repository.list();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repository.list);
  }

  Future<Appointment> book({
    required String title,
    required DateTime startsAt,
    required int durationMinutes,
    String? doctorId,
    String? doctorName,
    String? hospital,
    String? reason,
  }) async {
    final created = await _repository.create(
      title: title,
      startsAt: startsAt,
      durationMinutes: durationMinutes,
      doctorId: doctorId,
      doctorName: doctorName,
      hospital: hospital,
      reason: reason,
    );
    state = AsyncData(_sorted([...state.valueOrNull ?? const [], created]));
    return created;
  }

  /// A full replace. The caller passes the whole appointment because the server
  /// nulls whatever the body omits.
  Future<Appointment> reschedule(
    String id, {
    required String title,
    required DateTime startsAt,
    required int durationMinutes,
    String? doctorId,
    String? doctorName,
    String? hospital,
    String? reason,
  }) async {
    final saved = await _repository.replace(
      id,
      title: title,
      startsAt: startsAt,
      durationMinutes: durationMinutes,
      doctorId: doctorId,
      doctorName: doctorName,
      hospital: hospital,
      reason: reason,
    );
    return _replaceInList(saved);
  }

  /// Cancel keeps the row. A patient who cancels is not trying to erase the
  /// fact that they had an appointment, and the doctor's inbox needs to see it.
  Future<Appointment> cancel(String id) async {
    final saved =
        await _repository.setStatus(id, AppointmentStatus.cancelled);
    return _replaceInList(saved);
  }

  /// Remove it from the record entirely. Hard delete server-side.
  Future<void> remove(String id) async {
    await _repository.remove(id);
    state = AsyncData([
      for (final appointment in state.valueOrNull ?? const <Appointment>[])
        if (appointment.id != id) appointment,
    ]);
  }

  Appointment _replaceInList(Appointment saved) {
    state = AsyncData(_sorted([
      for (final appointment in state.valueOrNull ?? const <Appointment>[])
        if (appointment.id == saved.id) saved else appointment,
    ]));
    return saved;
  }

  /// Soonest first, matching the server's own ordering — a rescheduled
  /// appointment has to move in the list, not stay where it was.
  static List<Appointment> _sorted(List<Appointment> list) => [...list]..sort(
      (a, b) {
        final left = a.startsAt;
        final right = b.startsAt;
        if (left == null || right == null) return 0;
        return left.compareTo(right);
      },
    );
}

/// The patient's list split the way the screen shows it: what is still coming,
/// and everything else. Computed here so both halves come from one fetch.
typedef SplitAppointments = ({
  List<Appointment> upcoming,
  List<Appointment> past,
});

SplitAppointments splitAppointments(
  List<Appointment> all, {
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final upcoming = <Appointment>[];
  final past = <Appointment>[];
  for (final appointment in all) {
    (appointment.isUpcoming(now: at) ? upcoming : past).add(appointment);
  }
  // Past reads backwards: the most recent visit is the one worth seeing first.
  past.sort((a, b) {
    final left = a.startsAt;
    final right = b.startsAt;
    if (left == null || right == null) return 0;
    return right.compareTo(left);
  });
  return (upcoming: upcoming, past: past);
}

/// The doctor's inbox. A separate provider rather than a flag on the patient
/// one: they are different endpoints with different authorisation, and a
/// patient must never fetch the doctor route on the chance it works.
final doctorInboxProvider =
    AsyncNotifierProvider<DoctorInboxController, List<Appointment>>(
  DoctorInboxController.new,
);

class DoctorInboxController extends AsyncNotifier<List<Appointment>> {
  AppointmentRepository get _repository =>
      ref.read(appointmentRepositoryProvider);

  @override
  Future<List<Appointment>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null || !user.isDoctor) return const [];
    return _repository.inbox();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repository.inbox);
  }

  Future<Appointment> setStatus(String id, AppointmentStatus status) async {
    final saved = await _repository.setStatusAsDoctor(id, status);
    state = AsyncData([
      for (final appointment in state.valueOrNull ?? const <Appointment>[])
        if (appointment.id == saved.id) saved else appointment,
    ]);
    return saved;
  }
}

/// Which day of which doctor's diary to look at.
typedef SlotQuery = ({String doctorId, DateTime day, int durationMinutes});

/// `available-slots` for one doctor on one day.
///
/// `autoDispose` because the booking sheet asks about a different day on every
/// tap of the date picker, and a diary read five minutes ago is not something
/// anyone should book against.
final availableSlotsProvider =
    FutureProvider.autoDispose.family<List<AppointmentSlot>, SlotQuery>(
  (ref, query) => ref.watch(appointmentRepositoryProvider).slots(
        doctorId: query.doctorId,
        day: query.day,
        durationMinutes: query.durationMinutes,
      ),
);

/// Slots that have not already gone by.
///
/// The server generates every slot in the window regardless of the clock, and
/// its own future check runs against `datetime.now()` in the *server's* zone —
/// on Render that is UTC, 5h45m behind Kathmandu, so a 9 am slot this morning
/// is still "in the future" there long after it has passed here. Filtering on
/// the device is the only place the patient's actual clock is known.
List<AppointmentSlot> bookableSlots(
  List<AppointmentSlot> slots, {
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  return [
    for (final slot in slots)
      if (slot.start?.isAfter(at) ?? false) slot,
  ];
}
