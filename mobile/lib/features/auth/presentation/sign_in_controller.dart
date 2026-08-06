/// Sign-in, which is two steps whenever the account has 2FA switched on.
///
/// The first submit sends email and password. If the server answers 401 with
/// `X-2FA-Required: true` the credentials were right and only the second factor
/// is missing, so the screen moves to the code step and the same credentials
/// are sent again with the code attached.
///
/// That means holding the password in memory between the two steps. It is held
/// here, in an auto-disposed controller, and dropped the moment the flow ends
/// or the user backs out — never written to storage, never put in a route.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/session/session_controller.dart';
import '../data/auth_repository.dart';

enum SignInStep { credentials, twoFactor }

@immutable
class SignInState {
  const SignInState({
    this.step = SignInStep.credentials,
    this.submitting = false,
    this.error,
    this.email = '',
    this.password = '',
  });

  final SignInStep step;
  final bool submitting;
  final String? error;

  /// Kept only to resubmit with the TOTP code.
  final String email;
  final String password;

  SignInState working() => SignInState(
        step: step,
        submitting: true,
        email: email,
        password: password,
      );

  SignInState failed(String message) => SignInState(
        step: step,
        error: message,
        email: email,
        password: password,
      );

  SignInState challenged(String email, String password) => SignInState(
        step: SignInStep.twoFactor,
        email: email,
        password: password,
      );

  static const initial = SignInState();
}

final signInControllerProvider =
    NotifierProvider.autoDispose<SignInController, SignInState>(
  SignInController.new,
);

class SignInController extends AutoDisposeNotifier<SignInState> {
  @override
  SignInState build() => SignInState.initial;

  /// Step one. Returns true when the session is live — the router has moved on
  /// by then, so nothing may write state after a true.
  Future<bool> submitCredentials({
    required String email,
    required String password,
  }) async {
    state = SignInState(
      submitting: true,
      email: email.trim(),
      password: password,
    );
    return _attempt(email: email.trim(), password: password);
  }

  /// Step two: the same credentials plus the authenticator code.
  Future<bool> submitCode(String code) async {
    state = state.working();
    return _attempt(
      email: state.email,
      password: state.password,
      totpCode: code,
    );
  }

  /// Back out of the code step. Drops the held password on the way.
  void restart() => state = SignInState(email: state.email);

  Future<bool> _attempt({
    required String email,
    required String password,
    String? totpCode,
  }) async {
    try {
      final session = await ref.read(authRepositoryProvider).login(
            email: email,
            password: password,
            totpCode: totpCode,
          );
      await ref.read(sessionControllerProvider.notifier).signIn(session);
      return true;
    } on ApiException catch (error) {
      state = switch (error.kind) {
        ApiErrorKind.twoFactorRequired =>
          state.challenged(email, password),
        // On the code step a 401 means the code was wrong, not the password —
        // the server already accepted that to get this far.
        ApiErrorKind.credentials when totpCode != null => state.failed(
            "That code didn't work. Codes change every 30 seconds — try the "
            'current one.',
          ),
        ApiErrorKind.credentials =>
          state.failed('Your email or password is incorrect.'),
        ApiErrorKind.rateLimited => state.failed(
            'Too many sign-in attempts. Wait a minute and try again.',
          ),
        _ => state.failed(error.message),
      };
      return false;
    }
  }
}
