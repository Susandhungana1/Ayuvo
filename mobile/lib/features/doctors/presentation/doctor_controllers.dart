/// Doctor state: the directory patients book from, my own profile, and my
/// posted hours.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/session/session_controller.dart';
import '../data/doctor_repository.dart';
import '../domain/doctor.dart';

/// Verified doctors, for the booking flow. Read once per visit to the sheet
/// rather than kept alive: the directory changes when an operator verifies
/// somebody, which this app has no way to hear about.
final verifiedDoctorsProvider =
    FutureProvider.autoDispose<List<Doctor>>((ref) async {
  if (ref.watch(currentUserProvider) == null) return const [];
  return ref.watch(doctorRepositoryProvider).list();
});

/// One doctor's posted hours, for showing what a diary looks like before a
/// date is even chosen.
final doctorAvailabilityProvider =
    FutureProvider.autoDispose.family<List<AvailabilityWindow>, String>(
  (ref, doctorId) =>
      ref.watch(doctorRepositoryProvider).availabilityFor(doctorId),
);

/// What `GET /api/doctors/doctors/me` says about the signed-in doctor.
///
/// A 404 is not a failure: it is a doctor whose account has been elevated but
/// who has never filled in their registration. Modelling it as a value rather
/// than an error is what lets the screen offer the form instead of a Retry
/// button that will never help.
sealed class DoctorProfileState {
  const DoctorProfileState();
}

class HasDoctorProfile extends DoctorProfileState {
  const HasDoctorProfile(this.doctor);
  final Doctor doctor;
}

/// Elevated to DOCTOR, no profile row yet. [DoctorRepository.createProfile]
/// fixes it, and only the doctor can do it.
class NoDoctorProfile extends DoctorProfileState {
  const NoDoctorProfile();
}

/// The account is not a doctor account at all. Only reachable if the router
/// ever put a patient here, which it does not — kept so this type is total.
class NotADoctor extends DoctorProfileState {
  const NotADoctor();
}

final doctorProfileProvider =
    AsyncNotifierProvider<DoctorProfileController, DoctorProfileState>(
  DoctorProfileController.new,
);

class DoctorProfileController extends AsyncNotifier<DoctorProfileState> {
  DoctorRepository get _repository => ref.read(doctorRepositoryProvider);

  @override
  Future<DoctorProfileState> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null || !user.isDoctor) return const NotADoctor();
    return _read();
  }

  Future<DoctorProfileState> _read() async {
    try {
      return HasDoctorProfile(await _repository.me());
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.notFound) return const NoDoctorProfile();
      if (error.kind == ApiErrorKind.forbidden) return const NotADoctor();
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_read);
  }

  Future<Doctor> createProfile({
    required String nmid,
    required String degree,
    String? specialty,
  }) async {
    final doctor = await _repository.createProfile(
      nmid: nmid,
      degree: degree,
      specialty: specialty,
    );
    state = AsyncData(HasDoctorProfile(doctor));
    return doctor;
  }
}

/// My own availability windows, switched-off ones included.
final myAvailabilityProvider =
    AsyncNotifierProvider<AvailabilityController, List<AvailabilityWindow>>(
  AvailabilityController.new,
);

class AvailabilityController
    extends AsyncNotifier<List<AvailabilityWindow>> {
  DoctorRepository get _repository => ref.read(doctorRepositoryProvider);

  @override
  Future<List<AvailabilityWindow>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null || !user.isDoctor) return const [];
    return _repository.mine();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repository.mine);
  }

  Future<AvailabilityWindow> add({
    required Weekday day,
    required String startTime,
    required String endTime,
    required int slotDurationMinutes,
  }) async {
    final created = await _repository.addWindow(
      day: day,
      startTime: startTime,
      endTime: endTime,
      slotDurationMinutes: slotDurationMinutes,
    );
    state = AsyncData([...state.valueOrNull ?? const [], created]);
    return created;
  }

  /// Named `edit` rather than `update`: `AsyncNotifier` already has an
  /// `update`, and shadowing it with a different signature is a compile error.
  Future<AvailabilityWindow> edit(
    String id, {
    String? startTime,
    String? endTime,
    int? slotDurationMinutes,
    bool? isAvailable,
  }) async {
    final saved = await _repository.updateWindow(
      id,
      startTime: startTime,
      endTime: endTime,
      slotDurationMinutes: slotDurationMinutes,
      isAvailable: isAvailable,
    );
    state = AsyncData([
      for (final window in state.valueOrNull ?? const <AvailabilityWindow>[])
        if (window.id == saved.id) saved else window,
    ]);
    return saved;
  }

  Future<void> remove(String id) async {
    await _repository.removeWindow(id);
    state = AsyncData([
      for (final window in state.valueOrNull ?? const <AvailabilityWindow>[])
        if (window.id != id) window,
    ]);
  }
}

/// Windows grouped by weekday, Monday first, each day's windows in clock order.
/// Every day is present — a day with no hours is a thing the editor has to
/// show, because "add hours here" is the whole point of the empty row.
Map<Weekday, List<AvailabilityWindow>> byWeekday(
  List<AvailabilityWindow> windows,
) {
  final grouped = {for (final day in Weekday.values) day: <AvailabilityWindow>[]};
  for (final window in windows) {
    grouped[window.day]?.add(window);
  }
  for (final list in grouped.values) {
    list.sort((a, b) => a.startsAtMinute.compareTo(b.startsAtMinute));
  }
  return grouped;
}
