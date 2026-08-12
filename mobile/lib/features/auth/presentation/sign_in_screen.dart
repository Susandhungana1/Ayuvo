import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInput;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/session/session_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/states.dart';
import 'auth_scaffold.dart';
import 'sign_in_controller.dart';
import 'submit_button.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final controller = ref.read(signInControllerProvider.notifier);
    final step = ref.read(signInControllerProvider).step;
    // Whatever brought the user here has been read; don't repeat it after a
    // failed attempt of their own.
    ref.read(sessionControllerProvider.notifier).clearNotice();

    final signedIn = step == SignInStep.credentials
        ? await controller.submitCredentials(
            email: _email.text,
            password: _password.text,
          )
        : await controller.submitCode(_code.text);

    // Offer the credentials to the platform password manager only once they
    // are known to be right.
    if (signedIn) TextInput.finishAutofillContext();
  }

  void _restart() {
    _code.clear();
    _password.clear();
    ref.read(signInControllerProvider.notifier).restart();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(signInControllerProvider);
    final onCodeStep = state.step == SignInStep.twoFactor;

    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final notice = session is SignedOut ? session.notice : null;

    return PopScope(
      // On the code step, back means "wrong account, start over" — not "leave
      // the app", which is what the system back button would otherwise do.
      canPop: !onCodeStep,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _restart();
      },
      child: AuthScaffold(
        title: onCodeStep ? 'Two-factor code' : 'Sign in',
        subtitle: onCodeStep
            ? 'Open your authenticator app and enter the current 6-digit code.'
            : 'Your health record, on your phone.',
        children: [
          if (notice != null && !onCodeStep) ...[
            MessageBanner(message: notice, tone: BannerTone.notice),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (state.error != null) ...[
            MessageBanner(message: state.error!),
            const SizedBox(height: AppSpacing.lg),
          ],
          Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: onCodeStep ? _codeStep(state) : _credentialsStep(state),
          ),
        ],
      ),
    );
  }

  Widget _credentialsStep(SignInState state) {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            validator: AuthValidators.email,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'you@example.com',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PasswordField(
            controller: _password,
            label: 'Password',
            autofillHints: const [AutofillHints.password],
            validator: AuthValidators.password,
            onSubmitted: _submit,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push(Routes.forgotPassword),
              child: const Text('Forgot password?'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SubmitButton(
            label: 'Sign in',
            submitting: state.submitting,
            onPressed: _submit,
          ),
          const SizedBox(height: AppSpacing.xl),
          _FooterPrompt(
            question: 'New to MediStore?',
            action: 'Create an account',
            onPressed: () => context.push(Routes.register),
          ),
        ],
      ),
    );
  }

  Widget _codeStep(SignInState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _code,
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.oneTimeCode],
          maxLength: 6,
          validator: AuthValidators.totp,
          onFieldSubmitted: (_) => _submit(),
          style: context.numerals.numericLarge,
          decoration: const InputDecoration(
            labelText: 'Authenticator code',
            counterText: '',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SubmitButton(
          label: 'Verify',
          submitting: state.submitting,
          onPressed: _submit,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: state.submitting ? null : _restart,
          child: const Text('Use a different account'),
        ),
      ],
    );
  }
}

class _FooterPrompt extends StatelessWidget {
  const _FooterPrompt({
    required this.question,
    required this.action,
    required this.onPressed,
  });

  final String question;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          question,
          style: context.texts.bodyMedium
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
        TextButton(onPressed: onPressed, child: Text(action)),
      ],
    );
  }
}
