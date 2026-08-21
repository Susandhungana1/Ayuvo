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

  /// `GET /api/emergency/profile` — blood type, name and every contact.
  Future<EmergencyProfile> profile() async {
    final json = await _client.get<Map<String, dynamic>>('$_base/profile');
    return EmergencyProfile.fromJson(json);
  }

  /// `PUT /api/emergency/profile`.
  ///
  /// The server writes a field only `if data.x is not None`, so **null means
  /// "leave it alone" and the empty string is how you clear one**. The form
  /// therefore always sends the field, using `''` for clearing.
  Future<EmergencyProfile> save({required String bloodType}) async {
    final json = await _client.put<Map<String, dynamic>>(
      '$_base/profile',
      body: {'blood_type': bloodType},
    );
    return EmergencyProfile.fromJson(json);
  }

  /// `POST /api/emergency/contacts`.
  Future<EmergencyContact> addContact({
    required String name,
    required String phone,
  }) async {
    final json = await _client.post<Map<String, dynamic>>(
      '$_base/contacts',
      body: {'name': name, 'phone': phone},
    );
    return EmergencyContact.fromJson(json);
  }

  /// `DELETE /api/emergency/contacts/{id}` — hard, and there is no undo.
  Future<void> removeContact(String id) =>
      _client.delete<void>('$_base/contacts/$id');
}
