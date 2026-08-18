/// Test doubles shared by the session and auth-flow tests.
library;

import 'dart:convert';

import 'package:medistore/core/network/api_exception.dart';
import 'package:medistore/features/auth/data/auth_repository.dart';
import 'package:medistore/features/auth/domain/auth_user.dart';

const testUser = AuthUser(
  id: '#hos014',
  name: 'Ram Bahadur',
  email: 'ram@example.com',
  role: 'PATIENT',
);

const testDoctor = AuthUser(
  id: '#doc002',
  name: 'Dr Asha Rai',
  email: 'asha@example.com',
  role: 'DOCTOR',
);

/// A JWT the app can read but nobody can verify — which is exactly what the
/// client does with a real one: it only ever looks at `exp`.
String fakeJwt({Duration expiresIn = const Duration(days: 7)}) {
  String segment(Map<String, Object?> claims) =>
      base64Url.encode(utf8.encode(jsonEncode(claims))).replaceAll('=', '');

  final exp =
      DateTime.now().toUtc().add(expiresIn).millisecondsSinceEpoch ~/ 1000;
  return '${segment({'alg': 'HS256', 'typ': 'JWT'})}'
      '.${segment({'sub': '#hos014', 'exp': exp})}'
      '.not-a-real-signature';
}

String storedSession({
  AuthUser user = testUser,
  String? token,
  String? refreshToken = 'fake-refresh-token',
}) =>
    jsonEncode(
      AuthSession(
        user: user,
        token: token ?? fakeJwt(),
        refreshToken: refreshToken,
      ).toJson(),
    );

/// A scripted [AuthRepository]. Every method answers from a field, so a test
/// says what the server does and nothing else has to be arranged.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.user = testUser,
    this.token,
    this.loginError,
    this.registerError,
    this.requiresTwoFactor = false,
    this.expectedCode = '123456',
  });

  AuthUser user;
  String? token;

  /// Thrown by [login] before any 2FA handling.
  ApiException? loginError;
  ApiException? registerError;

  /// When true, a login without the right code answers the way the server
  /// does: 401 carrying `X-2FA-Required`.
  bool requiresTwoFactor;
  String expectedCode;

  final loginCalls = <({String email, String? code})>[];

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
    String? totpCode,
  }) async {
    loginCalls.add((email: email, code: totpCode));
    final error = loginError;
    if (error != null) throw error;

    if (requiresTwoFactor) {
      if (totpCode == null) {
        throw const ApiException(
          ApiErrorKind.twoFactorRequired,
          'Enter the 6-digit code from your authenticator app.',
          statusCode: 401,
        );
      }
      if (totpCode.trim() != expectedCode) {
        throw const ApiException(
          ApiErrorKind.credentials,
          'Invalid TOTP code',
          statusCode: 401,
        );
      }
    }
    return AuthSession(user: user, token: token ?? fakeJwt());
  }

  @override
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final error = registerError;
    if (error != null) throw error;
    user = AuthUser(id: user.id, name: name, email: email, role: 'PATIENT');
    return AuthSession(user: user, token: token ?? fakeJwt());
  }

  @override
  Future<AuthUser> me() async => user;

  /// What the refresh endpoint returns. A test can point these at new values
  /// and a call will hand them back, so the client's rotation path is scripted
  /// like any other server behaviour.
  ({String token, String refreshToken})? refreshResult;
  int refreshCalls = 0;
  bool refreshFails = false;

  @override
  Future<({String token, String refreshToken})> refreshTokens(
    String refreshToken,
  ) async {
    refreshCalls++;
    if (refreshFails) {
      throw const ApiException(
        ApiErrorKind.unauthorized,
        'Invalid refresh token',
        statusCode: 401,
      );
    }
    return refreshResult ?? (token: token ?? fakeJwt(), refreshToken: refreshToken);
  }

  int logoutCalls = 0;

  @override
  Future<void> logout(String? refreshToken) async {
    logoutCalls++;
  }

  int deleteAccountCalls = 0;
  ApiException? deleteAccountError;

  @override
  Future<void> deleteAccount() async {
    deleteAccountCalls++;
    final error = deleteAccountError;
    if (error != null) throw error;
  }

  @override
  Future<String> forgotPassword(String email) async =>
      'If an account exists for that email, a reset link has been sent.';

  @override
  Future<String> resetPassword({
    required String token,
    required String newPassword,
  }) async =>
      'Password updated. You can now sign in with your new password.';
}
