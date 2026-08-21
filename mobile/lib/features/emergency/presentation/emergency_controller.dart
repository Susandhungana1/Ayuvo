/// The emergency profile as state.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../data/emergency_repository.dart';
import '../domain/emergency_profile.dart';

final emergencyProfileProvider =
    AsyncNotifierProvider<EmergencyController, EmergencyProfile>(
  EmergencyController.new,
);

class EmergencyController extends AsyncNotifier<EmergencyProfile> {
  EmergencyRepository get _repository => ref.read(emergencyRepositoryProvider);

  @override
  Future<EmergencyProfile> build() async {
    if (ref.watch(currentUserProvider) == null) {
      return const EmergencyProfile();
    }
    return _repository.profile();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repository.profile);
  }

  /// Blood type goes every time, empty string for clearing — the server reads
  /// null as "leave it alone", so there is no other way to remove a value.
  Future<EmergencyProfile> save({required String bloodType}) async {
    final saved = await _repository.save(bloodType: bloodType);
    state = AsyncData(saved);
    return saved;
  }

  Future<EmergencyContact> addContact({
    required String name,
    required String phone,
  }) async {
    final contact = await _repository.addContact(name: name, phone: phone);
    final current = state.valueOrNull ?? const EmergencyProfile();
    state = AsyncData(
      current.copyWith(contacts: [...current.contacts, contact]),
    );
    return contact;
  }

  Future<void> removeContact(String id) async {
    await _repository.removeContact(id);
    final current = state.valueOrNull ?? const EmergencyProfile();
    state = AsyncData(
      current.copyWith(
        contacts: [
          for (final contact in current.contacts)
            if (contact.id != id) contact,
        ],
      ),
    );
  }
}
