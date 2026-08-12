import '../../features/auth/domain/auth_user.dart';

/// Who is signed in, as a closed set of two answers.
///
/// "Still restoring from the keystore" is deliberately *not* one of them — that
/// is the `AsyncValue.loading` around this type, so a screen can never forget
/// to handle it.
sealed class SessionState {
  const SessionState();
}

final class SignedOut extends SessionState {
  const SignedOut({this.notice});

  /// Why the app is showing sign-in, when there is a reason worth saying —
  /// "Your session has ended", not silence on a screen the user didn't ask for.
  final String? notice;
}

final class SignedIn extends SessionState {
  const SignedIn(this.session);

  final AuthSession session;

  AuthUser get user => session.user;
}
