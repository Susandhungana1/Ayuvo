import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/states.dart';
import 'auth_controllers.dart';
import 'auth_scaffold.dart';
import 'submit_button.dart';

/// Finishes a reset with the code from the email.
///
/// The code is a 43-character URL-safe token, so the field is multi-line and
/// paste-friendly rather than a row of digit boxes.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final done = await ref.read(resetPasswordControllerProvider.notifier).submit(
          token: _code.text,
          newPassword: _password.text,
        );
    if (!done || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password updated. Sign in with it now.')),
    );
    context.go(Routes.signIn);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(resetPasswordControllerProvider);

    return AuthScaffold(
      showBack: true,
      title: 'Enter your code',
      subtitle: 'Paste the code from the reset email and choose a new '
          'password. The code lasts 30 minutes.',
      children: [
        if (state.error != null) ...[
          MessageBanner(message: state.error!),
          const SizedBox(height: AppSpacing.lg),
        ],
        Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _code,
                autofocus: true,
                minLines: 1,
                maxLines: 2,
                textInputAction: TextInputAction.next,
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? 'Paste the code from the email.'
                    : null,
                decoration: const InputDecoration(labelText: 'Reset code'),
              ),
              const SizedBox(height: AppSpacing.lg),
              PasswordField(
                controller: _password,
                label: 'New password',
                hint: 'At least 8 characters.',
                autofillHints: const [AutofillHints.newPassword],
                validator: AuthValidators.newPassword,
                onSubmitted: _submit,
              ),
              const SizedBox(height: AppSpacing.xl),
              SubmitButton(
                label: 'Set new password',
                submitting: state.submitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
