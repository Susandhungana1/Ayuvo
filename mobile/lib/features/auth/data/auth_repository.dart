/// Every `/api/auth/*` call the app makes, and the only place their URLs and
/// field names appear. Screens call these methods; nothing builds a request.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/network_providers.dart';
import '../domain/auth_user.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);

class AuthRepository {
  const AuthRepository(this._client);

  final ApiClient _client;

  /// `POST /api/auth/register` — JSON, unlike login. Rate limited 5/min.
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final json = await _client.post<Map<String, dynamic>>(
      '/api/auth/register',
      body: {'name': name, 'email': email, 'password': password},
      options: unauthenticated,
    );
    return AuthSession.fromTokenResponse(json);
  }

  /// `POST /api/auth/login` — OAuth2 **form-encoded**, not JSON.
  ///
  /// The form has no field for a second factor, so the 6-digit TOTP code rides
  /// in `client_secret`; that is the server's contract, not a shortcut. When
  /// 2FA is on and no code is supplied the server answers 401 with
  /// `X-2FA-Required: true`, which arrives here as
  /// [ApiErrorKind.twoFactorRequired] — collect the code and call again.
  ///
  /// Rate limited 10/min per IP.
  Future<AuthSession> login({
    required String email,
    required String password,
    String? totpCode,
  }) async {
    final code = totpCode?.trim();
    final json = await _client.postForm<Map<String, dynamic>>(
      '/api/auth/login',
      {
        'grant_type': 'password',
        'username': email,
        'password': password,
        if (code != null && code.isNotEmpty) 'client_secret': code,
      },
    );
    return AuthSession.fromTokenResponse(json);
  }

  /// `GET /api/auth/me`.
  Future<AuthUser> me() async {
    final json = await _client.get<Map<String, dynamic>>('/api/auth/me');
    return AuthUser.fromJson(json);
  }

  /// `POST /api/auth/refresh` — exchanges a refresh token for a fresh access
  /// token, rotating the refresh token. The caller (the API client's 401
  /// interceptor) hands the returned pair back to the session.
  Future<({String token, String refreshToken})> refreshTokens(
    String refreshToken,
  ) async {
    final json = await _client.post<Map<String, dynamic>>(
      '/api/auth/refresh',
      body: {'refresh_token': refreshToken},
      options: unauthenticated,
    );
    return (
      token: json['token'] as String,
      refreshToken: json['refresh_token'] as String,
    );
  }

  /// `POST /api/auth/logout` — revokes the refresh token server-side so the
  /// session cannot come back. The access token dies on its own (short-lived).
  /// Best-effort: sign-out must not fail because the network is down.
  Future<void> logout(String? refreshToken) async {
    await _client.post<Map<String, dynamic>>(
      '/api/auth/logout',
      body: refreshToken == null ? null : {'refresh_token': refreshToken},
    );
  }

  /// `DELETE /api/users/me` — erases the account and every row that belongs
  /// to it: reports and their files, medicines, appointments, share links,
  /// vitals, care links, everything. There is no undo.
  Future<void> deleteAccount() async {
    await _client.delete<void>('/api/users/me');
  }

  /// `POST /api/auth/forgot-password` — rate limited 3/min.
  ///
  /// Answers identically whether or not the email has an account, so the reply
  /// can be shown verbatim without leaking who is registered. The mail carries
  /// both a link to the web page and a raw code, which is what
  /// [resetPassword] takes.
  Future<String> forgotPassword(String email) async {
    final json = await _client.post<Map<String, dynamic>>(
      '/api/auth/forgot-password',
      body: {'email': email},
      options: unauthenticated,
    );
    return json['message'] as String;
  }

  /// `POST /api/auth/reset-password` — the token is the code from the email.
  Future<String> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final json = await _client.post<Map<String, dynamic>>(
      '/api/auth/reset-password',
      body: {'token': token, 'new_password': newPassword},
      options: unauthenticated,
    );
    return json['message'] as String;
  }
}
