/// The one-time "shall I remember this fingerprint?" offer.
///
/// Shown once, when all four of these are true: somebody is signed in, the
/// phone has an enrolled sensor, the question has never been asked before, and
/// the medical disclaimer is already behind them. Answering it either way — or
/// setting the switch in Settings → Security — records that it was asked, so it
/// never appears again.
///
/// A layer rather than something bolted onto `SignInController`, for two
/// reasons. It keeps a plugin that can hang out of the sign-in path, which is
/// the one path in the app that must never hang. And it catches the people who
/// already had a session before this feature existed, who would otherwise have
/// to sign out and back in to be offered it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/session_controller.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import 'biometric_service.dart';
import 'security_preferences.dart';

class BiometricOffer extends ConsumerWidget {
  const BiometricOffer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(currentUserProvider) != null;
    final prefs = ref.watch(securityPreferencesProvider).valueOrNull;
    final availability = ref.watch(biometricAvailabilityProvider).valueOrNull;

    final show = signedIn &&
        prefs != null &&
        !prefs.biometricAsked &&
        prefs.disclaimerAccepted &&
        availability == BiometricAvailability.ready;

    if (!show) return child;

    final notifier = ref.read(securityPreferencesProvider.notifier);

    return Stack(
      children: [
        child,
        _OfferModal(
          onEnable: () => notifier.setBiometricEnabled(true),
          onDecline: notifier.markBiometricAsked,
        ),
      ],
    );
  }
}

class _OfferModal extends StatelessWidget {
  const _OfferModal({required this.onEnable, required this.onDecline});

  final VoidCallback onEnable;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back dismisses it, but as a decline rather than as nothing — otherwise
      // the offer comes back on the next launch and becomes nagging.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onDecline();
      },
      child: Material(
        color: Colors.black54,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                color: context.colors.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.fingerprint, color: context.colors.primary),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Faster sign-in',
                        style: context.texts.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Use your fingerprint or Face ID to open Ayuvo next '
                        'time instead of typing your password. You can turn '
                        'this off in Settings at any time.',
                        style: context.texts.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      FilledButton(
                        onPressed: onEnable,
                        child: const Text('Turn it on'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton(
                        onPressed: onDecline,
                        child: const Text('Not now'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
