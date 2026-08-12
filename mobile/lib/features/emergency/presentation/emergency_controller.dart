/// The emergency profile as state.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
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

  /// All three fields go every time, empty string for the ones being cleared —
  /// the server reads null as "leave it alone", so there is no other way to
  /// remove an allergy that no longer applies.
  Future<EmergencyProfile> save({
    required String bloodType,
    required String allergies,
    required String medicalConditions,
  }) async {
    final saved = await _repository.save(
      bloodType: bloodType,
      allergies: allergies,
      medicalConditions: medicalConditions,
    );
    state = AsyncData(saved);
    return saved;
  }

  Future<EmergencyContact> addContact({
    required String name,
    required String relationship,
    required String phone,
    String? email,
  }) async {
    final contact = await _repository.addContact(
      name: name,
      relationship: relationship,
      phone: phone,
      email: email,
    );
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

/// The URL behind the QR: a `front/` page, not a screen in this app.
///
/// Null when nobody is signed in. The id is percent-encoded because it starts
/// with `#` — pasted raw into a URL, everything after it is a fragment the
/// server never sees, and the page loads for nobody.
final emergencyLinkProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return Env.webLink('emergency/id', user.id);
});
