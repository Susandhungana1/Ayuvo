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
import '../cache/offline_cache.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
import '../network/network_providers.dart';
import '../storage/local_store.dart';
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
    client.onTokensRefreshed = _handleTokensRefreshed;
    ref.onDispose(() {
      _alive = false;
      client.onSessionExpired = null;
      client.onTokensRefreshed = null;
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

    // A session from before refresh tokens existed can never be renewed: even
    // an unexpired access token has a use-by date it can't outlive. Sign out
    // with a reason rather than 401 on the first request.
    final refreshToken = session.refreshToken;
    if (refreshToken == null) {
      await _store.clear();
      return const SignedOut(
        notice: 'Your session ran out. Sign in again.',
      );
    }

    client.useSession(session.token, refreshToken);

    // An expired access token is paid off up front: renewing here, before any
    // screen renders, means the first request after launch is never a 401 —
    // and it avoids racing the launch-time background calls against each
    // other's refreshes.
    if (isTokenExpired(session.token)) {
      final renewed = await client.refreshNow();
      if (!renewed) {
        await _store.clear();
        return const SignedOut(
          notice: 'Your session ran out. Sign in again.',
        );
      }
      session = session.copyWith(
        token: client.accessToken!,
        refreshToken: client.currentRefreshToken!,
      );
    }

    // Not awaited: the app opens on the stored user, and a changed name or
    // role lands a moment later. A 401 here is handled by the interceptor.
    unawaited(_refreshUser());
    return SignedIn(session);
  }

  /// Called after register, or after login when there was no second factor.
  Future<void> signIn(AuthSession session) async {
    _client.useSession(session.token, session.refreshToken);
    await _store.write(jsonEncode(session.toJson()));
    if (_alive) state = AsyncData(SignedIn(session));
  }

  /// The user asked to sign out. No notice — they know why they are here.
  ///
  /// The refresh token is revoked server-side first (best-effort, so it can't
  /// resurrect the session), then everything local goes away. The offline cache
  /// goes with the token: its entries are stamped with the owner and would be
  /// refused for anyone else anyway, but a phone handed to a family member
  /// should not still have a medicine list on it, refused or not.
  ///
  /// Cleared through [LocalStore] rather than through `offlineCacheProvider`:
  /// that provider watches the session to know whose cache it is, so reading it
  /// from here would be a circular dependency.
  Future<void> signOut() async {
    final session = state.valueOrNull;
    if (session is SignedIn) {
      _client.useToken(null);
      _client.useRefreshToken(null);
      // Revocation is a courtesy, not a requirement: sign-out must complete on
      // a dead network, so the outcome is deliberately ignored.
      unawaited(
        ref
            .read(authRepositoryProvider)
            .logout(session.session.refreshToken)
            .catchError((Object _) {}),
      );
    } else {
      _client.useToken(null);
      _client.useRefreshToken(null);
    }
    await Future.wait([
      _store.clear(),
      ref.read(localStoreProvider).clearPrefix(OfflineCache.filePrefix),
    ]);
    if (_alive) state = const AsyncData(SignedOut());
  }

  /// The sign-in screen has shown [SignedOut.notice]; don't show it again on
  /// the next rebuild.
  void clearNotice() {
    if (state.valueOrNull is SignedOut) {
      state = const AsyncData(SignedOut());
    }
  }

  /// The interceptor saw a 401 on an authenticated call and had no way to
  /// renew (no refresh token, or the refresh itself failed). Synchronous, and
  /// safe to call from several in-flight requests at once.
  void _handleExpiry() {
    if (!_alive || state.valueOrNull is SignedOut) return;
    _client.useSession(null, null);
    unawaited(_store.clear());
    state = const AsyncData(
      SignedOut(notice: 'Your session has ended. Sign in again.'),
    );
  }

  /// The interceptor rotated the pair and wants the new one persisted so the
  /// next launch starts with a live session instead of a 401-then-refresh.
  Future<void> _handleTokensRefreshed(
    String accessToken,
    String refreshToken,
  ) async {
    final current = state.valueOrNull;
    if (current is SignedIn) {
      final updated = current.session.copyWith(
        token: accessToken,
        refreshToken: refreshToken,
      );
      await _store.write(jsonEncode(updated.toJson()));
      if (_alive) state = AsyncData(SignedIn(updated));
      return;
    }
    // The refresh beat the launch: `build()` is still restoring, so state isn't
    // SignedIn yet, but the stored pair still needs to be rotated — otherwise
    // the launch continues on a token that is already dead.
    if (!_alive) return;
    try {
      final raw = await _store.read();
      if (raw == null) return;
      final stored =
          AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      await _store.write(jsonEncode(
        stored.copyWith(token: accessToken, refreshToken: refreshToken).toJson(),
      ));
    } catch (_) {
      // Unreadable blob; the restore path will clear it on its own.
    }
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
