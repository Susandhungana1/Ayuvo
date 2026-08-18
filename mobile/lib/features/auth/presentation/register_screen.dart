import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInput;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/states.dart';
import '../../legal/presentation/privacy_screen.dart';
import '../../legal/presentation/terms_screen.dart';
import 'auth_controllers.dart';
import 'auth_scaffold.dart';
import 'submit_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _agreed = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _openLegal(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_agreed) return;
    FocusScope.of(context).unfocus();

    final created = await ref.read(registerControllerProvider.notifier).submit(
          name: _name.text,
          email: _email.text,
          password: _password.text,
        );
    if (created) TextInput.finishAutofillContext();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registerControllerProvider);

    return AuthScaffold(
      showBack: true,
      title: 'Create your account',
      subtitle: 'One account holds your medicines, vitals, reports and '
          'documents in one place.',
      children: [
        if (state.error != null) ...[
          MessageBanner(message: state.error!),
          const SizedBox(height: AppSpacing.lg),
        ],
        Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  validator: AuthValidators.name,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newUsername],
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
                  hint: 'At least 8 characters.',
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: AuthValidators.newPassword,
                ),
                const SizedBox(height: AppSpacing.lg),
                PasswordField(
                  controller: _confirm,
                  label: 'Confirm password',
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (value) => value == _password.text
                      ? null
                      : "Those two passwords don't match.",
                  onSubmitted: _submit,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _agreed,
                      onChanged: (value) =>
                          setState(() => _agreed = value ?? false),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: RichText(
                          key: const ValueKey('consent-text'),
                          text: TextSpan(
                            style: context.texts.bodySmall?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                            children: [
                              const TextSpan(text: 'I agree to the '),
                              TextSpan(
                                text: 'Terms of Service',
                                style: context.texts.bodySmall?.copyWith(
                                  color: context.colors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => _openLegal(const TermsScreen()),
                              ),
                              const TextSpan(text: ' and the '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: context.texts.bodySmall?.copyWith(
                                  color: context.colors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => _openLegal(const PrivacyScreen()),
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                SubmitButton(
                  label: 'Create account',
                  submitting: state.submitting,
                  enabled: _agreed,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
