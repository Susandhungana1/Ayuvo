/// The three choices a person makes about the app rather than about their
/// health: what language it speaks, how it looks, and whether it interrupts.
///
/// Deliberately not on the server. `PUT /api/users/me` has no column for any of
/// them, and inventing one would be a phase-7 backend change to store something
/// that is per-device by nature — a phone in Nepali and a tablet in English is
/// a reasonable thing to want, and dark mode already follows the device.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_store.dart';

@immutable
class AppSettings {
  const AppSettings({
    this.locale,
    this.themeMode = ThemeMode.system,
    this.remindersEnabled = false,
  });

  /// Null means "whatever the phone is set to", which is the default and the
  /// right answer for almost everyone.
  final Locale? locale;

  final ThemeMode themeMode;

  /// Opt-in. Scheduling notifications the moment someone signs in — and asking
  /// for the permission to do it — is the behaviour every app is disliked for.
  final bool remindersEnabled;

  static const defaults = AppSettings();

  AppSettings copyWith({
    Locale? locale,
    bool clearLocale = false,
    ThemeMode? themeMode,
    bool? remindersEnabled,
  }) =>
      AppSettings(
        locale: clearLocale ? null : (locale ?? this.locale),
        themeMode: themeMode ?? this.themeMode,
        remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      );

  Map<String, Object?> toJson() => {
        'locale': locale?.languageCode,
        'theme': themeMode.name,
        'reminders': remindersEnabled,
      };

  /// Unknown values fall back to the default rather than throwing: this file is
  /// read on launch, and a settings file written by a newer build must not be
  /// able to stop an older one from starting.
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final code = json['locale'];
    return AppSettings(
      locale: supportedCodes.contains(code) ? Locale(code as String) : null,
      themeMode: ThemeMode.values.firstWhere(
        (mode) => mode.name == json['theme'],
        orElse: () => ThemeMode.system,
      ),
      remindersEnabled: json['reminders'] == true,
    );
  }

  /// Mirrors `AppL10n.supportedLocales`. Kept as codes so this file, which is
  /// read before the first frame, does not depend on generated code.
  static const supportedCodes = {'en', 'ne'};

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.locale?.languageCode == locale?.languageCode &&
      other.themeMode == themeMode &&
      other.remindersEnabled == remindersEnabled;

  @override
  int get hashCode => Object.hash(locale?.languageCode, themeMode, remindersEnabled);
}

final settingsProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

/// The settings, or the defaults while the file is still being read. Screens
/// that only want to render want this — a one-frame flash of English on a
/// Nepali phone is better than a spinner where the app should be.
final currentSettingsProvider = Provider<AppSettings>(
  (ref) => ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults,
);

class SettingsController extends AsyncNotifier<AppSettings> {
  static const _key = 'settings.v1';

  LocalStore get _store => ref.read(localStoreProvider);

  @override
  Future<AppSettings> build() async {
    final json = decodeJsonObject(await _store.read(_key));
    return json == null ? AppSettings.defaults : AppSettings.fromJson(json);
  }

  Future<void> setLocale(Locale? locale) => _save(
        (current) => current.copyWith(locale: locale, clearLocale: locale == null),
      );

  Future<void> setThemeMode(ThemeMode mode) =>
      _save((current) => current.copyWith(themeMode: mode));

  Future<void> setRemindersEnabled(bool enabled) =>
      _save((current) => current.copyWith(remindersEnabled: enabled));

  /// Optimistic: the toggle moves on this frame and the write happens behind
  /// it. A failed write costs the preference on next launch, which is a better
  /// trade than a switch that waits on a disk.
  Future<void> _save(AppSettings Function(AppSettings) change) async {
    final next = change(state.valueOrNull ?? AppSettings.defaults);
    state = AsyncData(next);
    await _store.write(_key, jsonEncode(next.toJson()));
  }
}
