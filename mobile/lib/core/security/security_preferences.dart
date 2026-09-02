/// Two per-device answers that are not settings about the app and not health
/// data either: whether this phone unlocks with a fingerprint, and whether the
/// person using it has read the medical disclaimer.
///
/// **Why the file store and not the keystore.** `SessionStore` holds a bearer
/// token — a credential that opens a health record — and belongs in the
/// platform keychain. Neither value here is a secret. `disclaimer_accepted` is
/// a "seen it" flag. `biometric_enabled` only decides whether to *offer* a
/// fingerprint prompt: flipping it false gets you the password screen, and
/// flipping it true with nothing enrolled gets you the password screen too.
/// Neither direction is an attack, so putting them behind a keystore round trip
/// on every launch would buy nothing and cost the first frame. See the header
/// of `local_store.dart` for the rule this follows.
///
/// Deliberately **not** cleared on sign-out. Both are facts about the device
/// and the person holding it, not about the session: signing out and back in
/// should not re-ask a disclaimer that was already read, or forget that this
/// phone is the one with the fingerprint set up.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_store.dart';

@immutable
class SecurityPreferences {
  const SecurityPreferences({
    this.biometricEnabled = false,
    this.biometricAsked = false,
    this.disclaimerAccepted = false,
  });

  /// Opt-in, like reminders. Nothing about a health record should start using
  /// a fingerprint because the app assumed it was wanted.
  final bool biometricEnabled;

  /// Whether the one-time "enable this?" dialog has already been shown. Kept
  /// separate from [biometricEnabled] so that declining once means declining,
  /// rather than being asked again after every sign-in.
  final bool biometricAsked;

  final bool disclaimerAccepted;

  static const defaults = SecurityPreferences();

  SecurityPreferences copyWith({
    bool? biometricEnabled,
    bool? biometricAsked,
    bool? disclaimerAccepted,
  }) =>
      SecurityPreferences(
        biometricEnabled: biometricEnabled ?? this.biometricEnabled,
        biometricAsked: biometricAsked ?? this.biometricAsked,
        disclaimerAccepted: disclaimerAccepted ?? this.disclaimerAccepted,
      );

  Map<String, Object?> toJson() => {
        'biometric_enabled': biometricEnabled,
        'biometric_asked': biometricAsked,
        'disclaimer_accepted': disclaimerAccepted,
      };

  /// Anything unreadable falls back to the default, for the same reason
  /// `AppSettings` does: this is read on launch, and a file written by a newer
  /// build must never stop an older one from starting.
  factory SecurityPreferences.fromJson(Map<String, dynamic> json) =>
      SecurityPreferences(
        biometricEnabled: json['biometric_enabled'] == true,
        biometricAsked: json['biometric_asked'] == true,
        disclaimerAccepted: json['disclaimer_accepted'] == true,
      );

  @override
  bool operator ==(Object other) =>
      other is SecurityPreferences &&
      other.biometricEnabled == biometricEnabled &&
      other.biometricAsked == biometricAsked &&
      other.disclaimerAccepted == disclaimerAccepted;

  @override
  int get hashCode =>
      Object.hash(biometricEnabled, biometricAsked, disclaimerAccepted);
}

final securityPreferencesProvider =
    AsyncNotifierProvider<SecurityPreferencesController, SecurityPreferences>(
  SecurityPreferencesController.new,
);

/// The preferences, or the defaults while the file is still being read.
///
/// Defaulting to "not accepted, not enabled" while loading is the safe way
/// round: the worst case is a disclaimer shown for one frame too long, never a
/// lock screen skipped.
final currentSecurityPreferencesProvider = Provider<SecurityPreferences>(
  (ref) =>
      ref.watch(securityPreferencesProvider).valueOrNull ??
      SecurityPreferences.defaults,
);

class SecurityPreferencesController extends AsyncNotifier<SecurityPreferences> {
  static const _key = 'security.v1';

  LocalStore get _store => ref.read(localStoreProvider);

  @override
  Future<SecurityPreferences> build() async {
    final json = decodeJsonObject(await _store.read(_key));
    return json == null
        ? SecurityPreferences.defaults
        : SecurityPreferences.fromJson(json);
  }

  Future<void> setBiometricEnabled(bool enabled) =>
      _save((current) => current.copyWith(
            biometricEnabled: enabled,
            // Turning it on or off from Settings also answers the one-time
            // question, so sign-in stops asking.
            biometricAsked: true,
          ));

  /// The one-time offer was shown and declined. Recorded on its own so the next
  /// sign-in does not ask again.
  Future<void> markBiometricAsked() =>
      _save((current) => current.copyWith(biometricAsked: true));

  Future<void> acceptDisclaimer() =>
      _save((current) => current.copyWith(disclaimerAccepted: true));

  /// Optimistic, like `SettingsController._save`: the switch moves on this
  /// frame and the write happens behind it.
  Future<void> _save(
    SecurityPreferences Function(SecurityPreferences) change,
  ) async {
    final next = change(state.valueOrNull ?? SecurityPreferences.defaults);
    state = AsyncData(next);
    await _store.write(_key, jsonEncode(next.toJson()));
  }
}
