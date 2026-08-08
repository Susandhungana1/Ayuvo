import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/settings/app_settings.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';

class MediStoreApp extends ConsumerWidget {
  const MediStoreApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(currentSettingsProvider);

    return MaterialApp.router(
      title: 'MediStore',
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
    );
  }
}
