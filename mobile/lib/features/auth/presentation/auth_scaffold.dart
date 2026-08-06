/// The frame every signed-out screen sits in.
///
/// One column, capped at a readable width so the form doesn't stretch across a
/// tablet, scrollable so a raised keyboard can never hide the submit button,
/// and padded off the bottom safe area.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.showBack = false,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showBack ? AppBar(title: const SizedBox.shrink()) : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: context.texts.headlineMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    subtitle,
                    style: context.texts.bodyMedium
                        ?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared field rules, so "enter your email" reads the same everywhere.
abstract final class AuthValidators {
  static final _email = RegExp(r'^[\w.%+-]+@[\w.-]+\.[A-Za-z]{2,}$');

  /// Mirrors the server's own check in `UserCreate.validate_email`, so a
  /// typo is caught before it costs a round trip.
  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your email address.';
    if (!_email.hasMatch(text)) return 'That email address looks incomplete.';
    return null;
  }

  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Enter your password.';
    return null;
  }

  /// The server rejects anything shorter than 8 characters.
  static String? newPassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Choose a password.';
    if (text.length < 8) return 'Use at least 8 characters.';
    return null;
  }

  static String? name(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your name.';
    return null;
  }

  static String? totp(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter the 6-digit code.';
    if (text.length != 6 || int.tryParse(text) == null) {
      return 'The code is 6 digits.';
    }
    return null;
  }
}

/// A password field with a show/hide toggle. Stateful because the toggle is
/// leaf state — flipping it must not rebuild the form around it.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.textInputAction = TextInputAction.done,
    this.autofillHints,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final FormFieldValidator<String>? validator;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final VoidCallback? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _hidden,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.hint,
        suffixIcon: IconButton(
          onPressed: () => setState(() => _hidden = !_hidden),
          icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          tooltip: _hidden ? 'Show password' : 'Hide password',
        ),
      ),
    );
  }
}
