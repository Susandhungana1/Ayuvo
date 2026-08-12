/// `/api/care/*`, and the four failures a caretaker screen has to tell apart.
///
/// `front/lib/care.ts` worked this taxonomy out and it is worth mirroring
/// one-for-one, because the messages are not interchangeable:
///
///   401  the session is over               → the app signs out (ApiClient)
///   403  the patient revoked the link      → [CareFailure.revoked]
///   404  on a `/api/care/` path            → [CareFailure.featureOff]
///   else something else went wrong         → whatever ApiException says
///
/// "Not available on your account" is exactly the wrong thing to say when the
/// API is simply unreachable, and "check your connection" is exactly the wrong
/// thing to say when the server answered 404 because a flag is off.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/network_providers.dart';
import '../domain/care_link.dart';

enum CareRole { patient, caretaker }

/// The two care-specific failures, as an exception a screen can switch on.
class CareFailure implements Exception {
  const CareFailure(this.kind, this.message);

  final CareFailureKind kind;
  final String message;

  static const revoked = CareFailure(
    CareFailureKind.revoked,
    'This care link is no longer active.',
  );

  static const featureOff = CareFailure(
    CareFailureKind.featureOff,
    'Caretaker links are not switched on for this server.',
  );

  @override
  String toString() => 'CareFailure(${kind.name}): $message';
}

enum CareFailureKind { revoked, featureOff }

final careRepositoryProvider = Provider<CareRepository>(
  (ref) => CareRepository(ref.watch(apiClientProvider)),
);

class CareRepository {
  const CareRepository(this._client);

  final ApiClient _client;

  static const _base = '/api/care';

  /// `GET /links?role=` — patient: who cares for me. caretaker: who I care for.
  Future<List<CareLink>> links(CareRole role) => _guard(() async {
        final json = await _client.get<Map<String, dynamic>>(
          '$_base/links?role=${role.name}',
        );
        final rows = json['links'] as List<dynamic>? ?? const [];
        return [
          for (final row in rows) CareLink.fromJson(row as Map<String, dynamic>),
        ];
      });

  /// `POST /invites` — the code comes back once and is never retrievable again.
  /// Rate limited to 10 a day, and capped at 5 active caretakers.
  Future<CareInvite> createInvite() => _guard(() async {
        final json = await _client.post<Map<String, dynamic>>('$_base/invites');
        return CareInvite.fromJson(json);
      });

  /// `POST /invites/redeem`. Wrong, expired and already-used codes all come
  /// back as the same 400 on purpose — do not try to tell the user which.
  Future<CareLink> redeem(String code) => _guard(() async {
        final json = await _client.post<Map<String, dynamic>>(
          '$_base/invites/redeem',
          body: {'code': code.trim().toUpperCase()},
        );
        return CareLink.fromJson(json);
      });

  /// `PATCH /links/{id}` — caretaker side only. A patient cannot silence their
  /// own caretaker's alerts, and the server enforces that with a 404.
  Future<CareLink> setNotify(String linkId, bool notify) => _guard(() async {
        final json = await _client.patch<Map<String, dynamic>>(
          '$_base/links/$linkId',
          body: {'notify': notify},
        );
        return CareLink.fromJson(json);
      });

  /// `DELETE /links/{id}` — either party may end it, and it takes effect on the
  /// caretaker's very next request.
  Future<void> revoke(String linkId) =>
      _guard(() => _client.delete<void>('$_base/links/$linkId'));

  /// Translates the two status codes that mean something specific on a care
  /// route. Everything else passes through untouched, so the generic error
  /// handling keeps working.
  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException catch (error) {
      throw switch (error.kind) {
        ApiErrorKind.forbidden => CareFailure.revoked,
        ApiErrorKind.notFound => CareFailure.featureOff,
        _ => error,
      };
    }
  }
}
