/// The medicine list as state: one fetch, and mutations that fold the server's
/// answer back in rather than refetching the whole list.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cached_list.dart';
import '../../../core/cache/offline_cache.dart';
import '../../../core/session/session_controller.dart';
import '../data/medicine_repository.dart';
import '../domain/medicine.dart';

/// Keyed by `patient_id`: null is "my own medicines", a real id is a patient a
/// caretaker is acting for. Phase 6 supplies the second case; the plumbing is
/// here from the start so the caretaker screen adds no new code path — and so
/// the two lists can never share a cache entry.
final medicinesProvider =
    AsyncNotifierProvider.family<MedicinesController, List<Medicine>, String?>(
  MedicinesController.new,
);

class MedicinesController
    extends FamilyAsyncNotifier<List<Medicine>, String?> {
  MedicineRepository get _repository => ref.read(medicineRepositoryProvider);

  String? get _patientId => arg;

  /// False once this controller has been thrown away. The offline read
  /// publishes its result asynchronously, and by then a sign-out may have
  /// disposed the notifier underneath it.
  bool _alive = true;

  @override
  Future<List<Medicine>> build(String? patientId) async {
    // A medicine list belongs to an account, so it is derived from who is
    // signed in. Sign out and it empties; sign in as someone else and it
    // refetches — instead of one person's prescriptions sitting in a cache
    // while another reads the screen.
    if (ref.watch(currentUserProvider) == null) return const [];

    _alive = true;
    ref.onDispose(() => _alive = false);

    // A caretaker's view of somebody else's medicines is never written to
    // disk — the link that authorises it can be revoked at any moment, and a
    // cached copy would outlive the permission. `offline_cache.dart` has the
    // full reasoning; this is the only place the rule is applied.
    if (patientId != null) return _repository.list(patientId: patientId);

    return loadWithCache<Medicine>(
      cache: ref.watch(offlineCacheProvider),
      status: ref.read(cacheStatusProvider(CacheKeys.medicines).notifier),
      name: CacheKeys.medicines,
      fetch: () => _repository.list(),
      decode: Medicine.fromJson,
      encode: (medicine) => medicine.toJson(),
      publish: (fresh) => state = AsyncData(fresh),
      alive: () => _alive,
    );
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _repository.list(patientId: _patientId));
    if (state.hasValue && _patientId == null) {
      // A successful manual refresh is the moment the "showing a saved copy"
      // banner should go away, and the moment the saved copy should be the one
      // just fetched.
      ref.read(cacheStatusProvider(CacheKeys.medicines).notifier).live();
      await ref.read(offlineCacheProvider).write(
            CacheKeys.medicines,
            [for (final medicine in state.value!) medicine.toJson()],
          );
    }
  }

  Future<Medicine> add({
    required String name,
    required String dosage,
    required String frequency,
    required String startDate,
    String? endDate,
    List<String> times = const [],
    String? notes,
  }) async {
    final created = await _repository.create(
      name: name,
      dosage: dosage,
      frequency: frequency,
      startDate: startDate,
      endDate: endDate,
      times: times,
      notes: notes,
      patientId: _patientId,
    );
    // The list is newest-first, and this is the newest.
    state = AsyncData([created, ...state.valueOrNull ?? const []]);
    return created;
  }

  Future<Medicine> edit(
    String id, {
    String? name,
    String? dosage,
    String? frequency,
    String? startDate,
    String? endDate,
    List<String>? times,
    String? notes,
  }) async {
    final updated = await _repository.update(
      id,
      name: name,
      dosage: dosage,
      frequency: frequency,
      startDate: startDate,
      endDate: endDate,
      times: times,
      notes: notes,
      patientId: _patientId,
    );
    state = AsyncData([
      for (final medicine in state.valueOrNull ?? const <Medicine>[])
        if (medicine.id == id) updated else medicine,
    ]);
    return updated;
  }

  /// Soft delete. The row survives server-side, which is what makes [undoRemove]
  /// honest rather than a re-create with a new id.
  Future<void> remove(String id) async {
    await _repository.remove(id, patientId: _patientId);
    state = AsyncData([
      for (final medicine in state.valueOrNull ?? const <Medicine>[])
        if (medicine.id != id) medicine,
    ]);
  }

  /// `POST /{id}/restore`. Used by the snackbar's Undo and, in phase 6, by the
  /// patient reviewing what a caretaker removed.
  Future<Medicine> undoRemove(String id) async {
    final restored = await _repository.restore(id, patientId: _patientId);
    final list = [...state.valueOrNull ?? const <Medicine>[], restored];
    // Back into newest-first order rather than at the end, so Undo puts the row
    // back where it was instead of somewhere new.
    list.sort((a, b) {
      final left = a.created;
      final right = b.created;
      if (left == null || right == null) return 0;
      return right.compareTo(left);
    });
    state = AsyncData(list);
    return restored;
  }
}

/// `GET /api/medicines/interactions` — recomputed whenever the list changes,
/// because adding one medicine is exactly when a new interaction appears.
///
/// Skips the call entirely for an empty list: the answer is knowable without
/// asking, and a patient with no medicines should not be waiting on a request.
final interactionsProvider =
    FutureProvider.family<InteractionCheck, String?>((ref, patientId) async {
  final medicines = await ref.watch(medicinesProvider(patientId).future);
  if (medicines.isEmpty) {
    return const InteractionCheck(interactions: [], checkedCount: 0);
  }
  final check =
      await ref.watch(medicineRepositoryProvider).interactions(patientId: patientId);
  // Worst first — a severe interaction must not sit below a minor one.
  final sorted = [...check.interactions]..sort((a, b) => a.rank.compareTo(b.rank));
  return InteractionCheck(
    interactions: sorted,
    checkedCount: check.checkedCount,
  );
});

/// `GET /api/medicines/intake/log` — self only, so it takes no patient id.
final intakeLogProvider = FutureProvider<List<MedicineIntake>>((ref) async {
  if (ref.watch(currentUserProvider) == null) return const [];
  return ref.watch(medicineRepositoryProvider).intakeLog(limit: 200);
});
