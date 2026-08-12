import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_user.freezed.dart';
part 'auth_user.g.dart';

/// The signed-in person, exactly as `/api/auth/me` and the login response
/// describe them. Field names are the server's — do not rename them here.
@freezed
abstract class AuthUser with _$AuthUser {
  const factory AuthUser({
    required String id,
    required String name,
    required String email,

    /// `PATIENT` (the default), `DOCTOR` or `ADMIN`.
    required String role,
  }) = _AuthUser;

  const AuthUser._();

  factory AuthUser.fromJson(Map<String, dynamic> json) =>
      _$AuthUserFromJson(json);

  /// Which shell this account gets. `front/` gates on `role === 'DOCTOR'`
  /// exactly, so ADMIN sees the patient app there and here too — parity beats
  /// a guess about what an admin wants.
  bool get isDoctor => role.toUpperCase() == 'DOCTOR';

  /// First name only, for a greeting. Never used as an identifier.
  String get shortName => name.trim().split(RegExp(r'\s+')).first;
}

/// A user plus the bearer token that proves it. This is what gets written to
/// the keystore, so its JSON shape is a storage format: change it and bump the
/// key version in `SecureSessionStore`.
@freezed
abstract class AuthSession with _$AuthSession {
  const factory AuthSession({
    required AuthUser user,
    required String token,
  }) = _AuthSession;

  factory AuthSession.fromJson(Map<String, dynamic> json) =>
      _$AuthSessionFromJson(json);

  /// The login and register responses are flat — `{id, name, email, role,
  /// token}` — so the user and the token come out of the same map.
  factory AuthSession.fromTokenResponse(Map<String, dynamic> json) =>
      AuthSession(
        user: AuthUser.fromJson(json),
        token: json['token'] as String,
      );
}
