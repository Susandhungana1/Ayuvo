import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/states.dart';
import 'auth_controllers.dart';
import 'auth_scaffold.dart';
import 'submit_button.dart';

/// Asks the server to email a reset code.
///
/// The email carries a link to the web page *and* the raw code, and
/// `POST /api/auth/reset-password` accepts a pasted code — so the whole reset
/// can finish in the app without the web page changing at all.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await ref.read(forgotPasswordControllerProvider.notifier).submit(
          _email.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(forgotPasswordControllerProvider);

    return AuthScaffold(
      showBack: true,
      title: 'Reset your password',
      subtitle: state.isDone
          ? 'Check your inbox, then come back with the code.'
          : "Enter your email and we'll send you a code.",
      children: [
        if (state.error != null) ...[
          MessageBanner(message: state.error!),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (state.isDone) ...[
          // The server answers identically whether or not the address has an
          // account, so this text can be shown as-is without revealing who is
          // registered.
          MessageBanner(message: state.message!, tone: BannerTone.notice),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: () => context.pushReplacement(Routes.resetPassword),
            child: const Text('I have a code'),
          ),
        ] else
          Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.username],
                  validator: AuthValidators.email,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'you@example.com',
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                SubmitButton(
                  label: 'Send the code',
                  submitting: state.submitting,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () => context.pushReplacement(Routes.resetPassword),
                  child: const Text('I already have a code'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
