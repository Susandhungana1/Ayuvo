/// What happens to a stored session between launches, and what a 401 does to
/// one that is already open.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medistore/core/network/api_client.dart';
import 'package:medistore/core/network/api_exception.dart';
import 'package:medistore/core/network/network_providers.dart';
import 'package:medistore/core/session/session_controller.dart';
import 'package:medistore/core/session/session_state.dart';
import 'package:medistore/core/storage/local_store.dart';
import 'package:medistore/core/storage/session_store.dart';
import 'package:medistore/features/auth/data/auth_repository.dart';
import 'package:medistore/features/auth/domain/auth_user.dart';

import 'support/fake_http.dart';
import 'support/fakes.dart';

({ProviderContainer container, InMemorySessionStore store, FakeAdapter adapter})
    boot({
  String? stored,
  ResponseBody Function(RecordedRequest request)? respond,
}) {
  final store = InMemorySessionStore(stored);
  final adapter = FakeAdapter(
    respond ??
        (request) {
          if (request.path.endsWith('/api/auth/refresh')) {
            return jsonResponse({
              'token': fakeJwt(),
              'refresh_token': 'fresh-refresh-token',
            });
          }
          return jsonResponse({
            'id': testUser.id,
            'name': testUser.name,
            'email': testUser.email,
            'role': testUser.role,
          });
        },
  );
  final container = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(store),
      // Signing out clears the offline cache as well as the keystore, and the
      // real store is a method channel that never answers under `flutter test`.
      localStoreProvider.overrideWithValue(InMemoryLocalStore()),
      apiClientProvider.overrideWith(
        (ref) => ApiClient(
          baseUrl: 'http://127.0.0.1:3001',
          dio: Dio()..httpClientAdapter = adapter,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, store: store, adapter: adapter);
}

void main() {
  test('no stored session means signed out, with nothing to explain', () async {
    final f = boot();

    final state = await f.container.read(sessionControllerProvider.future);

    expect(state, isA<SignedOut>());
    expect((state as SignedOut).notice, isNull);
  });

  test('a stored session is restored before the first screen', () async {
    final f = boot(stored: storedSession());

    final state = await f.container.read(sessionControllerProvider.future);

    expect(state, isA<SignedIn>());
    expect((state as SignedIn).user.email, testUser.email);
    expect(f.container.read(currentUserProvider)?.id, testUser.id);
  });

  test('an expired token with a refresh token restores, not signs out',
      () async {
    final f = boot(
      stored: storedSession(token: fakeJwt(expiresIn: -const Duration(days: 1))),
    );

    final state = await f.container.read(sessionControllerProvider.future);

    // The access token is stale but the session is renewable: the first real
    // request 401s, the interceptor refreshes, and nobody gets dumped out.
    expect(state, isA<SignedIn>());
    expect(await f.store.read(), isNotNull);
  });

  test('a session with no refresh token signs out and says why', () async {
    final f = boot(
      stored: storedSession(
        token: fakeJwt(expiresIn: -const Duration(days: 1)),
        refreshToken: null,
      ),
    );

    final state = await f.container.read(sessionControllerProvider.future);

    expect(state, isA<SignedOut>());
    expect((state as SignedOut).notice, contains('Sign in again'));
    expect(await f.store.read(), isNull, reason: 'the dead token is dropped');
  });

  test('an unreadable stored blob is discarded rather than crashing launch',
      () async {
    final f = boot(stored: 'not json at all');

    final state = await f.container.read(sessionControllerProvider.future);

    expect(state, isA<SignedOut>());
    expect(await f.store.read(), isNull);
  });

  test('signing in persists the session and arms the client', () async {
    final f = boot();
    await f.container.read(sessionControllerProvider.future);

    final session = AuthSession(user: testUser, token: fakeJwt());
    await f.container.read(sessionControllerProvider.notifier).signIn(session);

    expect(f.container.read(sessionControllerProvider).value, isA<SignedIn>());
    final saved = jsonDecode((await f.store.read())!) as Map<String, dynamic>;
    expect(saved['token'], session.token);
    expect(saved['user']['email'], testUser.email);

    // The next authenticated call carries the token without anyone passing it.
    await f.container.read(authRepositoryProvider).me();
    expect(f.adapter.requests.last.authorization, 'Bearer ${session.token}');
  });

  test('signing out clears storage and the client', () async {
    final f = boot(stored: storedSession());
    await f.container.read(sessionControllerProvider.future);

    await f.container.read(sessionControllerProvider.notifier).signOut();

    final state = f.container.read(sessionControllerProvider).value;
    expect(state, isA<SignedOut>());
    expect((state! as SignedOut).notice, isNull, reason: 'they know why');
    expect(await f.store.read(), isNull);

    await f.container.read(authRepositoryProvider).me();
    expect(f.adapter.requests.last.authorization, isNull);
  });

  test('a 401 with a live refresh token renews and retries, invisibly',
      () async {
    var meCalls = 0;
    final f = boot(
      stored: storedSession(),
      respond: (request) {
        if (request.path.endsWith('/api/auth/refresh')) {
          return jsonResponse({
            'token': fakeJwt(),
            'refresh_token': 'rotated-refresh-token',
          });
        }
        // First call is the launch-time user refresh on a fresh token (200,
        // just like a real server would answer); every later call 401s until
        // the retry proves the rotation worked.
        meCalls++;
        if (meCalls == 1 || meCalls >= 3) {
          return jsonResponse({
            'id': testUser.id,
            'name': testUser.name,
            'email': testUser.email,
            'role': testUser.role,
          });
        }
        return jsonResponse({'detail': 'expired'}, statusCode: 401);
      },
    );
    await f.container.read(sessionControllerProvider.future);

    final user = await f.container.read(authRepositoryProvider).me();

    expect(user.email, testUser.email, reason: 'the retry succeeded');
    expect(meCalls, 3, reason: 'launch check, one refusal, one retry');
    final state = f.container.read(sessionControllerProvider).value;
    expect(state, isA<SignedIn>(), reason: 'nobody got signed out');

    // The rotated pair was persisted for the next launch.
    final saved = jsonDecode((await f.store.read())!) as Map<String, dynamic>;
    expect(saved['refreshToken'], 'rotated-refresh-token');
  });

  test('a 401 with a dead refresh token signs out once and says so',
      () async {
    var calls = 0;
    final f = boot(
      stored: storedSession(),
      respond: (_) {
        calls++;
        return jsonResponse({'detail': 'Invalid credentials'}, statusCode: 401);
      },
    );
    await f.container.read(sessionControllerProvider.future);

    // Two requests in flight, both refused — the refresh also fails, and the
    // user is signed out once.
    await expectLater(
      f.container.read(authRepositoryProvider).me(),
      throwsA(isA<ApiException>()
          .having((e) => e.kind, 'kind', ApiErrorKind.unauthorized)),
    );
    await expectLater(
      f.container.read(authRepositoryProvider).me(),
      throwsA(isA<ApiException>()),
    );

    final state = f.container.read(sessionControllerProvider).value;
    expect(state, isA<SignedOut>());
    expect((state! as SignedOut).notice, contains('session has ended'));
    expect(await f.store.read(), isNull);
    expect(calls, greaterThanOrEqualTo(3), reason: 'me + refresh + me');
  });

  test('the notice is shown once, then cleared', () async {
    final f = boot(
      stored: storedSession(
        token: fakeJwt(expiresIn: -const Duration(days: 1)),
        refreshToken: null,
      ),
    );
    await f.container.read(sessionControllerProvider.future);

    f.container.read(sessionControllerProvider.notifier).clearNotice();

    final state = f.container.read(sessionControllerProvider).value;
    expect((state! as SignedOut).notice, isNull);
  });
}
