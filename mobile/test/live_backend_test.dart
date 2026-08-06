/// The client against a **real** local backend — no fakes anywhere.
///
/// Skipped by default so `flutter test` stays offline and deterministic. Run it
/// against a live `uvicorn main:app --port 3001` with:
///
///   flutter test test/live_backend_test.dart --dart-define=LIVE_BACKEND=true
///
/// It registers a throwaway account (unique email per run) in whatever database
/// that server points at, so point it at local Postgres — never production.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medistore/core/network/api_client.dart';
import 'package:medistore/core/network/api_exception.dart';
import 'package:medistore/core/network/scoped_url.dart';
import 'package:medistore/features/auth/data/auth_repository.dart';

const _enabled = bool.fromEnvironment('LIVE_BACKEND');
const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:3001',
);

void main() {
  if (!_enabled) {
    test(
      'live backend checks',
      () {},
      skip: 'opt-in: --dart-define=LIVE_BACKEND=true, with uvicorn on $_baseUrl',
    );
    return;
  }

  late ApiClient client;
  late AuthRepository auth;
  late String email;
  var expiries = 0;

  const password = 'phase3-live-check';

  setUpAll(() {
    // flutter_test blocks real sockets by default; this test is the one place
    // that genuinely wants the network.
    HttpOverrides.global = null;
  });

  setUp(() {
    client = ApiClient(baseUrl: _baseUrl);
    client.onSessionExpired = () => expiries++;
    auth = AuthRepository(client);
    email = 'phase3+${DateTime.now().microsecondsSinceEpoch}@example.com';
  });

  tearDown(() => client.close());

  test('health reports a database and tells us about caretakers', () async {
    final json =
        await client.get<Map<String, dynamic>>('/health', options: unauthenticated);

    expect(json['status'], 'ok');
    expect(json['database'], isTrue);
    expect(json['caretaker'], isA<bool>());
  });

  test('register, then sign in, then read yourself back', () async {
    final registered = await auth.register(
      name: 'Phase Three',
      email: email,
      password: password,
    );
    expect(registered.user.email, email);
    expect(registered.user.role, 'PATIENT');
    expect(registered.user.id, startsWith('#'));

    final signedIn = await auth.login(email: email, password: password);
    expect(signedIn.token, isNotEmpty);

    client.useToken(signedIn.token);
    final me = await auth.me();
    expect(me.id, registered.user.id);
    expect(me.email, email);
    expect(expiries, 0);
  });

  test('a short password is refused in the server\'s own words', () async {
    await expectLater(
      auth.register(name: 'Too Short', email: email, password: 'short'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.invalid)
            .having((e) => e.message, 'message', contains('8 characters')),
      ),
    );
  });

  test('the wrong password is a credentials failure, not a dead session',
      () async {
    await auth.register(name: 'Phase Three', email: email, password: password);

    await expectLater(
      auth.login(email: email, password: 'not-the-password'),
      throwsA(isA<ApiException>()
          .having((e) => e.kind, 'kind', ApiErrorKind.credentials)),
    );
    expect(expiries, 0);
  });

  test('a dead token ends the session exactly once', () async {
    client.useToken('this.is.not-a-token');

    await expectLater(
      auth.me(),
      throwsA(isA<ApiException>()
          .having((e) => e.kind, 'kind', ApiErrorKind.unauthorized)),
    );
    expect(expiries, 1);
  });

  test('an authenticated data call works, # in the id and all', () async {
    final session = await auth.register(
      name: 'Phase Three',
      email: email,
      password: password,
    );
    client.useToken(session.token);

    // The id in the JWT contains a `#`; this proves the round trip survives it
    // and that ScopedUrl produces something the server accepts.
    final url = ScopedUrl.build('/api/medicines');
    final json = await client.get<Map<String, dynamic>>(url);

    expect(json['medicines'], isA<List<dynamic>>());
    expect(session.user.id, contains('#'));
  });
}
