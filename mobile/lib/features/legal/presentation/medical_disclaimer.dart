/// What this app is not.
///
/// Ayuvo flags a lab value against a reference range and names the band a
/// blood pressure falls in. Both look like a verdict, and neither is one — the
/// ranges are typical-adult tables applied without knowing the person's age,
/// pregnancy, medication or history. Somebody has to say so once, plainly,
/// before the first result is read rather than in small print underneath it.
///
/// Shown once per install, on the first launch after signing in, and never
/// again. The same words live in Settings → About, where they can be found on
/// purpose instead of by accident.
///
/// **Non-dismissible.** No barrier tap, no back gesture, one button. An
/// acknowledgement that can be swiped away by mistake has not been given.
///
/// Rendered as a layer rather than through `showDialog` because it is mounted
/// above the router, where there is no `Navigator` in scope to push onto.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/security_preferences.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';

/// The one paragraph, in one place, so the modal and the About screen cannot
/// drift apart.
const String medicalDisclaimerBody =
    'Ayuvo provides educational summaries of your health records, not '
    'clinical diagnoses. Always consult a qualified healthcare professional '
    'for medical decisions.';

const String medicalDisclaimerTitle = 'Medical Disclaimer';

class MedicalDisclaimerGate extends ConsumerWidget {
  const MedicalDisclaimerGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(currentUserProvider) != null;
    // `valueOrNull` and not the default constant: while the file is still being
    // read the answer is unknown, and showing the modal on a guess would flash
    // it at somebody who accepted it months ago.
    final prefs = ref.watch(securityPreferencesProvider).valueOrNull;

    final show = signedIn && prefs != null && !prefs.disclaimerAccepted;

    return Stack(
      children: [
        child,
        if (show)
          _DisclaimerModal(
            onAccept: () => ref
                .read(securityPreferencesProvider.notifier)
                .acceptDisclaimer(),
          ),
      ],
    );
  }
}

class _DisclaimerModal extends StatelessWidget {
  const _DisclaimerModal({required this.onAccept});

  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // The Android back gesture is a barrier tap by another name.
      canPop: false,
      child: Semantics(
        // Everything behind the scrim is unreachable, so it should also be
        // unreadable to a screen reader — otherwise the focus order walks off
        // into a screen the user cannot act on.
        scopesRoute: true,
        explicitChildNodes: true,
        namesRoute: true,
        label: medicalDisclaimerTitle,
        child: Material(
          // A scrim, not a solid fill: the app stays visible behind it so the
          // modal reads as a step, not as a different screen.
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
                        Icon(
                          Icons.info_outline,
                          color: context.colors.primary,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          medicalDisclaimerTitle,
                          style: context.texts.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          medicalDisclaimerBody,
                          style: context.texts.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        FilledButton(
                          onPressed: onAccept,
                          child: const Text('I understand'),
                        ),
                      ],
                    ),
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
