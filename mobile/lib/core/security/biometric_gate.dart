/// The fingerprint check that stands between a restored session and the app.
///
/// `SessionController` reads the token out of the keystore before the first
/// frame, which is what makes the app open on the medicine list instead of on
/// a sign-in screen. That is the right default, and it is also the reason this
/// gate exists: without it, a stored session means anyone holding an unlocked
/// phone is holding an open health record.
///
/// So when a session is restored *and* the user has turned biometrics on, the
/// app opens covered, prompts immediately, and stays covered until it matches.
///
/// **Failing is not being stuck.** Every path out of a failed scan leads to the
/// password screen, because the password is the real authentication and the
/// scan was only the shortcut past it. There is no "try again forever" state.
///
/// It gates only the *launch*. Coming back from the app switcher does not
/// re-lock — that is `PrivacyShield`'s job, and re-prompting on every glance at
/// a notification would train people to hate the feature and turn it off.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/session_controller.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import 'biometric_service.dart';
import 'security_preferences.dart';

class BiometricGate extends ConsumerStatefulWidget {
  const BiometricGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends ConsumerState<BiometricGate> {
  /// Null until the three answers it depends on — session, preference,
  /// hardware — have all arrived. Nothing is covered before then, because a
  /// signed-out launch must not flash a lock screen at somebody.
  bool? _locked;

  bool _prompting = false;

  /// The decision is made once per launch. Without this latch, unlocking would
  /// flip `_locked` to false and the next rebuild would recompute it back to
  /// true from preferences that have not changed.
  bool _decided = false;

  Future<void> _decide() async {
    if (_decided) return;

    // The session has to have *settled*, not merely be absent. It is restored
    // from the keystore asynchronously, and the preferences file usually wins
    // that race — deciding on a half-answered question would latch "signed
    // out, do not lock" a frame before the stored session arrives.
    final session = ref.read(sessionControllerProvider);
    if (!session.hasValue) return;

    final signedIn = ref.read(currentUserProvider) != null;
    final prefs = ref.read(securityPreferencesProvider).valueOrNull;
    final availability = ref.read(biometricAvailabilityProvider).valueOrNull;

    // Still loading: leave it undecided rather than guessing either way.
    if (prefs == null || availability == null) return;

    _decided = true;
    final shouldLock = signedIn &&
        prefs.biometricEnabled &&
        availability == BiometricAvailability.ready;

    if (!mounted) return;
    setState(() => _locked = shouldLock);
    if (shouldLock) await _unlock();
  }

  Future<void> _unlock() async {
    if (_prompting) return;
    setState(() => _prompting = true);
    final ok = await ref.read(biometricServiceProvider).authenticate(
          reason: 'Unlock your health record',
        );
    if (!mounted) return;
    setState(() {
      _prompting = false;
      if (ok) _locked = false;
    });
  }

  /// "Use my password instead" — and the destination every failure leads to.
  /// Signing out drops the restored session, which sends the router to the
  /// sign-in screen on its own.
  Future<void> _usePassword() async {
    setState(() => _locked = false);
    await ref.read(sessionControllerProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    // Watched, not read: this rebuilds as each of the answers lands, and
    // `_decide` runs again until it has all of them.
    ref.watch(sessionControllerProvider);
    ref.watch(securityPreferencesProvider);
    ref.watch(biometricAvailabilityProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _decide());

    return Stack(
      children: [
        widget.child,
        if (_locked == true)
          _LockScreen(
            prompting: _prompting,
            onRetry: _unlock,
            onUsePassword: _usePassword,
          ),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({
    required this.prompting,
    required this.onRetry,
    required this.onUsePassword,
  });

  final bool prompting;
  final Future<void> Function() onRetry;
  final Future<void> Function() onUsePassword;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.fingerprint,
                size: 56,
                color: context.colors.primary,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Ayuvo is locked',
                style: context.texts.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Unlock with your fingerprint or face to open your health '
                'record.',
                style: context.texts.bodyMedium
                    ?.copyWith(color: context.colors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: prompting ? null : onRetry,
                icon: const Icon(Icons.fingerprint, size: 20),
                label: Text(prompting ? 'Waiting…' : 'Unlock'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: prompting ? null : onUsePassword,
                child: const Text('Use my password instead'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
