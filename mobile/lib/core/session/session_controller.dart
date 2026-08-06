/// Who is signed in, and the three things that can change that: signing in,
/// signing out, and a 401 that says the token is finished.
///
/// The token is restored from the keystore before the first frame, so the app
/// opens on the right screen rather than flashing sign-in at someone who is
/// already signed in.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/auth_user.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
import '../network/network_providers.dart';
import '../storage/session_store.dart';
import 'jwt.dart';
import 'session_state.dart';

final sessionStoreProvider = Provider<SessionStore>(
  (ref) => const SecureSessionStore(),
);

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

/// The signed-in user, or null. Most screens want this rather than the whole
/// state machine.
final currentUserProvider = Provider<AuthUser?>((ref) {
  final state = ref.watch(sessionControllerProvider).valueOrNull;
  return state is SignedIn ? state.user : null;
});

class SessionController extends AsyncNotifier<SessionState> {
  bool _alive = true;

  ApiClient get _client => ref.read(apiClientProvider);

  SessionStore get _store => ref.read(sessionStoreProvider);

  @override
  Future<SessionState> build() async {
    final client = ref.watch(apiClientProvider);
    _alive = true;
    client.onSessionExpired = _handleExpiry;
    ref.onDispose(() {
      _alive = false;
      client.onSessionExpired = null;
    });

    return _restore(client);
  }

  Future<SessionState> _restore(ApiClient client) async {
    final raw = await _store.read();
    if (raw == null) return const SignedOut();

    AuthSession session;
    try {
      session = AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (error) {
      // A blob we can't read is worth exactly nothing; drop it rather than
      // carrying a corrupt session around.
      debugPrint('Stored session unreadable; clearing it.');
      await _store.clear();
      return const SignedOut();
    }

    // There is no refresh token — after seven days the answer is simply
    // "sign in again", and saying so beats a screen that 401s on load.
    if (isTokenExpired(session.token)) {
      await _store.clear();
      return const SignedOut(
        notice: 'Your session ran out after seven days. Sign in again.',
      );
    }

    client.useToken(session.token);
    // Not awaited: the app opens on the stored user, and a changed name or
    // role lands a moment later. A 401 here is handled by the interceptor.
    unawaited(_refreshUser());
    return SignedIn(session);
  }

  /// Called after register, or after login when there was no second factor.
  Future<void> signIn(AuthSession session) async {
    _client.useToken(session.token);
    await _store.write(jsonEncode(session.toJson()));
    if (_alive) state = AsyncData(SignedIn(session));
  }

  /// The user asked to sign out. No notice — they know why they are here.
  Future<void> signOut() async {
    _client.useToken(null);
    await _store.clear();
    if (_alive) state = const AsyncData(SignedOut());
  }

  /// The sign-in screen has shown [SignedOut.notice]; don't show it again on
  /// the next rebuild.
  void clearNotice() {
    if (state.valueOrNull is SignedOut) {
      state = const AsyncData(SignedOut());
    }
  }

  /// The interceptor saw a 401 on an authenticated call. Synchronous, and safe
  /// to call from several in-flight requests at once.
  void _handleExpiry() {
    if (!_alive || state.valueOrNull is SignedOut) return;
    _client.useToken(null);
    unawaited(_store.clear());
    state = const AsyncData(
      SignedOut(notice: 'Your session has ended. Sign in again.'),
    );
  }

  /// Pulls the current name/email/role so a change made elsewhere (or a role
  /// granted since last launch) is reflected without a re-login.
  Future<void> _refreshUser() async {
    try {
      final user = await ref.read(authRepositoryProvider).me();
      final current = state.valueOrNull;
      if (!_alive || current is! SignedIn || current.user == user) return;
      final refreshed = current.session.copyWith(user: user);
      await _store.write(jsonEncode(refreshed.toJson()));
      if (_alive) state = AsyncData(SignedIn(refreshed));
    } on ApiException catch (error) {
      // Offline, or a 401 the interceptor has already acted on. Either way the
      // stored session stands; the next real request will settle it.
      debugPrint('Session refresh skipped: ${error.kind.name}');
    }
  }
}
