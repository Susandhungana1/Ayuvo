import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/security/biometric_gate.dart';
import 'core/security/biometric_offer.dart';
import 'core/security/privacy_shield.dart';
import 'core/settings/app_settings.dart';
import 'core/theme/app_theme.dart';
import 'features/legal/presentation/medical_disclaimer.dart';
import 'l10n/app_localizations.dart';

class AyuvoApp extends ConsumerWidget {
  const AyuvoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(currentSettingsProvider);

    return MaterialApp.router(
      title: 'Ayuvo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // The system decides unless the user has overridden it in Settings.
      // DESIGN.md specifies both modes and the tests check both, so following
      // the phone is the right default — but a phone-wide choice is not always
      // the right one for a health app read in bed.
      themeMode: settings.themeMode,
      // Null follows the device, which is what `supportedLocales` resolution is
      // for. An explicit choice from Settings wins over it.
      locale: settings.locale,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      routerConfig: ref.watch(routerProvider),
      // Four layers that sit above every route and below the theme, outermost
      // first. Order is the point:
      //
      //   PrivacyShield          covers everything, including the three below,
      //                          when the OS takes its task-switcher snapshot.
      //   BiometricGate          covers the app until a restored session is
      //                          unlocked — so the disclaimer is not readable,
      //                          or acknowledgeable, before that.
      //   MedicalDisclaimerGate  covers the router until it is acknowledged.
      //   BiometricOffer         asks, once, whether to use a fingerprint —
      //                          innermost, so it cannot appear over the
      //                          disclaimer that has to be read first.
      //
      // `builder` rather than wrapping `MaterialApp` itself: this is inside
      // Theme, Directionality and MediaQuery, all of which these need, and a
      // `Navigator` is not required because each renders its own layer.
      builder: (context, child) => PrivacyShield(
        child: BiometricGate(
          child: MedicalDisclaimerGate(
            child: BiometricOffer(
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
