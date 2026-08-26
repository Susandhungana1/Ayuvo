/// What the HTTP layer promises every screen: the token is attached, a dead
/// session is noticed exactly once, and nothing leaves here as a DioException.
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ayuvo/core/network/api_client.dart';
import 'package:ayuvo/core/network/api_exception.dart';
import 'package:ayuvo/features/auth/data/auth_repository.dart';

import 'support/fake_http.dart';

({ApiClient client, FakeAdapter adapter, List<void> expiries}) build(
  ResponseBody Function(RecordedRequest request) respond,
) {
  final adapter = FakeAdapter(respond);
  final dio = Dio()..httpClientAdapter = adapter;
  final client = ApiClient(baseUrl: 'http://127.0.0.1:3001', dio: dio);
  final expiries = <void>[];
  client.onSessionExpired = () => expiries.add(null);
  return (client: client, adapter: adapter, expiries: expiries);
}

void main() {
  test('attaches the bearer token to an authenticated call', () async {
    final f = build((_) => jsonResponse({
          'id': '#hos014',
          'name': 'Ram',
          'email': 'ram@example.com',
          'role': 'PATIENT',
        }));
    f.client.useToken('token-abc');

    final user = await AuthRepository(f.client).me();

    expect(f.adapter.requests.single.authorization, 'Bearer token-abc');
    expect(user.id, '#hos014');
    expect(user.isDoctor, isFalse);
  });

  test('sends no token on sign-in, even when one is held', () async {
    final f = build((_) => jsonResponse({
          'id': '#hos014',
          'name': 'Ram',
          'email': 'ram@example.com',
          'role': 'PATIENT',
          'token': 'fresh',
        }));
    f.client.useToken('stale-token');

    await AuthRepository(f.client)
        .login(email: 'ram@example.com', password: 'hunter2hunter2');

    expect(f.adapter.requests.single.authorization, isNull);
  });

  test('login is form-encoded and carries the TOTP code in client_secret',
      () async {
    final f = build((_) => jsonResponse({
          'id': '#hos014',
          'name': 'Ram',
          'email': 'ram@example.com',
          'role': 'PATIENT',
          'token': 'fresh',
        }));

    final session = await AuthRepository(f.client).login(
      email: 'ram@example.com',
      password: 'hunter2hunter2',
      totpCode: ' 123456 ',
    );

    final request = f.adapter.requests.single;
    expect(
      request.options.contentType,
      startsWith(Headers.formUrlEncodedContentType),
    );
    expect(request.body, contains('grant_type=password'));
    expect(request.body, contains('username=ram%40example.com'));
    // The OAuth2 form has no field for a second factor; the server reads it
    // out of client_secret. Trimmed, because a pasted code often has spaces.
    expect(request.body, contains('client_secret=123456'));
    expect(session.token, 'fresh');
  });

  test('omits client_secret when there is no code', () async {
    final f = build((_) => jsonResponse({
          'id': '#hos014',
          'name': 'Ram',
          'email': 'ram@example.com',
          'role': 'PATIENT',
          'token': 'fresh',
        }));

    await AuthRepository(f.client)
        .login(email: 'ram@example.com', password: 'hunter2hunter2');

    expect(f.adapter.requests.single.body, isNot(contains('client_secret')));
  });

  test('a 401 with X-2FA-Required asks for a code and keeps the session',
      () async {
    final f = build(
      (_) => jsonResponse(
        {'detail': 'TOTP code required'},
        statusCode: 401,
        headers: {
          'x-2fa-required': ['true'],
        },
      ),
    );

    await expectLater(
      AuthRepository(f.client)
          .login(email: 'ram@example.com', password: 'hunter2hunter2'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.twoFactorRequired),
      ),
    );
    expect(f.expiries, isEmpty, reason: 'a 2FA prompt is not a dead session');
  });

  test('a 401 on sign-in is bad credentials, not an ended session', () async {
    final f = build(
      (_) => jsonResponse({'detail': 'Invalid credentials'}, statusCode: 401),
    );

    await expectLater(
      AuthRepository(f.client)
          .login(email: 'ram@example.com', password: 'wrong-password'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.credentials),
      ),
    );
    expect(f.expiries, isEmpty);
  });

  test('a 401 on an authenticated call ends the session, once', () async {
    final f = build(
      (_) => jsonResponse({'detail': 'Invalid credentials'}, statusCode: 401),
    );
    f.client.useToken('expired');

    await expectLater(
      AuthRepository(f.client).me(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.unauthorized)
            .having((e) => e.message, 'message', contains('Sign in again')),
      ),
    );
    expect(f.expiries, hasLength(1));
  });

  test('reads a FastAPI validation error into one readable line', () async {
    final f = build(
      (_) => jsonResponse(
        {
          'detail': [
            {
              'loc': ['body', 'password'],
              'msg': 'Value error, Password must be at least 8 characters',
              'type': 'value_error',
            },
          ],
        },
        statusCode: 422,
      ),
    );

    await expectLater(
      AuthRepository(f.client).register(
        name: 'Ram',
        email: 'ram@example.com',
        password: 'short',
      ),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.invalid)
            .having((e) => e.message, 'message',
                'Password must be at least 8 characters'),
      ),
    );
  });

  test('rate limiting says how to recover, not what the status code was',
      () async {
    final f = build((_) => jsonResponse({'detail': 'Rate limit exceeded'},
        statusCode: 429));

    await expectLater(
      AuthRepository(f.client)
          .login(email: 'ram@example.com', password: 'hunter2hunter2'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.rateLimited)
            .having((e) => e.message, 'message', contains('Wait a minute')),
      ),
    );
  });

  test('an unreachable server is a network error, and retryable', () async {
    final f = build((_) => throw const SocketExceptionStub());

    await expectLater(
      AuthRepository(f.client).me(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.network)
            .having((e) => e.isRetryable, 'isRetryable', isTrue)
            .having((e) => e.message, 'message',
                contains("Couldn't reach Ayuvo")),
      ),
    );
    // Unreachable is not the same as unauthorized: nobody gets signed out.
    expect(f.expiries, isEmpty);
  });
}

/// Stands in for a real socket failure without importing dart:io into a test
/// that otherwise has no need for it.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
