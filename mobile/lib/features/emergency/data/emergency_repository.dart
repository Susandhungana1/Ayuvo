/// Every `/api/emergency*` call the signed-in owner makes.
///
/// `GET /api/emergency/public/{user_id}` is missing on purpose: it is
/// unauthenticated and only ever read by the public web page; these details
/// also travel with the all-reports share QR, which is the supported way for
/// someone else to see them.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/network_providers.dart';
import '../domain/emergency_profile.dart';

final emergencyRepositoryProvider = Provider<EmergencyRepository>(
  (ref) => EmergencyRepository(ref.watch(apiClientProvider)),
);

class EmergencyRepository {
  const EmergencyRepository(this._client);

  final ApiClient _client;

  static const _base = '/api/emergency';

  /// `GET /api/emergency/profile` — the three fields and every contact.
  Future<EmergencyProfile> profile() async {
    final json = await _client.get<Map<String, dynamic>>('$_base/profile');
    return EmergencyProfile.fromJson(json);
  }

  /// `PUT /api/emergency/profile`.
  ///
  /// The server writes a field only `if data.x is not None`, so **null means
  /// "leave it alone" and the empty string is how you clear one**. The form
  /// therefore always sends all three, using `''` for the ones the user
  /// emptied — otherwise an allergy that has stopped applying can never be
  /// removed, only added to.
  Future<EmergencyProfile> save({
    required String bloodType,
    required String allergies,
    required String medicalConditions,
  }) async {
    final json = await _client.put<Map<String, dynamic>>(
      '$_base/profile',
      body: {
        'blood_type': bloodType,
        'allergies': allergies,
        'medical_conditions': medicalConditions,
      },
    );
    return EmergencyProfile.fromJson(json);
  }

  /// `POST /api/emergency/contacts`.
  Future<EmergencyContact> addContact({
    required String name,
    required String relationship,
    required String phone,
    String? email,
  }) async {
    final json = await _client.post<Map<String, dynamic>>(
      '$_base/contacts',
      body: {
        'name': name,
        'relationship': relationship,
        'phone': phone,
        'email': ?email,
      },
    );
    return EmergencyContact.fromJson(json);
  }

  /// `DELETE /api/emergency/contacts/{id}` — hard, and there is no undo.
  Future<void> removeContact(String id) =>
      _client.delete<void>('$_base/contacts/$id');
}
