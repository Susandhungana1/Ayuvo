/// The controllers behind register, forgot-password and reset-password.
///
/// They share one shape — idle, working, failed, done — because all three are
/// the same interaction: submit a form, wait, then either say what went wrong
/// or say what happened. Sign-in is the exception (two steps) and lives in
/// `sign_in_controller.dart`.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/session/session_controller.dart';
import '../data/auth_repository.dart';

@immutable
class FormSubmission {
  const FormSubmission({this.submitting = false, this.error, this.message});

  const FormSubmission.working() : this(submitting: true);

  const FormSubmission.failed(String error) : this(error: error);

  /// Succeeded, with the server's own words to show.
  const FormSubmission.done(String message) : this(message: message);

  static const idle = FormSubmission();

  final bool submitting;
  final String? error;
  final String? message;

  bool get isDone => message != null;
}

final registerControllerProvider =
    NotifierProvider.autoDispose<RegisterController, FormSubmission>(
  RegisterController.new,
);

class RegisterController extends AutoDisposeNotifier<FormSubmission> {
  @override
  FormSubmission build() => FormSubmission.idle;

  /// Returns true once the new account is signed in — at which point the
  /// router has already moved on, so nothing else may touch state.
  Future<bool> submit({
    required String name,
    required String email,
    required String password,
  }) async {
    state = const FormSubmission.working();
    try {
      final session = await ref.read(authRepositoryProvider).register(
            name: name.trim(),
            email: email.trim(),
            password: password,
          );
      await ref.read(sessionControllerProvider.notifier).signIn(session);
      return true;
    } on ApiException catch (error) {
      state = FormSubmission.failed(switch (error.kind) {
        // The server's 400 here is literally "Email already registered".
        ApiErrorKind.invalid => error.message,
        ApiErrorKind.rateLimited =>
          'Too many sign-up attempts. Wait a minute and try again.',
        _ => error.message,
      });
      return false;
    }
  }
}

final forgotPasswordControllerProvider =
    NotifierProvider.autoDispose<ForgotPasswordController, FormSubmission>(
  ForgotPasswordController.new,
);

class ForgotPasswordController extends AutoDisposeNotifier<FormSubmission> {
  @override
  FormSubmission build() => FormSubmission.idle;

  Future<void> submit(String email) async {
    state = const FormSubmission.working();
    try {
      // The reply is deliberately the same whether or not that email has an
      // account, so it is safe to show verbatim.
      final message =
          await ref.read(authRepositoryProvider).forgotPassword(email.trim());
      state = FormSubmission.done(message);
    } on ApiException catch (error) {
      state = FormSubmission.failed(switch (error.kind) {
        ApiErrorKind.rateLimited =>
          'You can ask for a reset three times a minute. Try again shortly.',
        _ => error.message,
      });
    }
  }
}

final resetPasswordControllerProvider =
    NotifierProvider.autoDispose<ResetPasswordController, FormSubmission>(
  ResetPasswordController.new,
);

class ResetPasswordController extends AutoDisposeNotifier<FormSubmission> {
  @override
  FormSubmission build() => FormSubmission.idle;

  Future<bool> submit({
    required String token,
    required String newPassword,
  }) async {
    state = const FormSubmission.working();
    try {
      final message = await ref.read(authRepositoryProvider).resetPassword(
            token: token.trim(),
            newPassword: newPassword,
          );
      state = FormSubmission.done(message);
      return true;
    } on ApiException catch (error) {
      state = FormSubmission.failed(error.message);
      return false;
    }
  }
}
