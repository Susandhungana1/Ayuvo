/// The fingerprint / Face ID layer, and everything it deliberately is not.
///
/// **It is a convenience, not an authorisation.** The server never sees it.
/// Every request is still authorised by the JWT in `SessionStore`, and the only
/// thing a successful scan does is stop covering a session that was already
/// valid. That is why a failed scan falls back to the password screen rather
/// than to nothing: the fallback is the *real* authentication, and the scan was
/// only ever the shortcut past it.
///
/// Everything the plugin can throw is turned into a [BiometricAvailability] or
/// a plain false. A phone with a broken sensor, a locked-out sensor after five
/// failed attempts, or no hardware at all must all end up at the password
/// screen — never at an exception on launch.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';

/// Why the app may or may not offer a fingerprint.
enum BiometricAvailability {
  /// Hardware is present and at least one finger or face is enrolled.
  ready,

  /// Hardware is present but nothing is enrolled, so there is nothing to match
  /// against. Offering it would produce a prompt that can only ever fail.
  notEnrolled,

  /// No sensor, an unsupported platform (this app also builds for web), or a
  /// sensor that is locked out or unreadable.
  unavailable,
}

abstract interface class BiometricService {
  Future<BiometricAvailability> availability();

  /// Shows the OS prompt. True only on a positive match — a cancel, a lockout
  /// and a mismatch are all false, because none of them is the user proving
  /// who they are.
  Future<bool> authenticate({required String reason});
}

class LocalAuthBiometricService implements BiometricService {
  LocalAuthBiometricService([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<BiometricAvailability> availability() async {
    // The web build has no plugin behind the channel at all.
    if (kIsWeb) return BiometricAvailability.unavailable;
    try {
      // `isDeviceSupported` answers "is there hardware"; `canCheckBiometrics`
      // answers "can it be asked right now". Both have to be true before the
      // enrolment list is worth reading.
      final supported = await _auth.isDeviceSupported();
      if (!supported) return BiometricAvailability.unavailable;
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return BiometricAvailability.unavailable;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isEmpty
          ? BiometricAvailability.notEnrolled
          : BiometricAvailability.ready;
    } on PlatformException catch (error) {
      debugPrint('Biometric availability unreadable (${error.code}).');
      return BiometricAvailability.unavailable;
    } on MissingPluginException {
      // A test binding, or a platform the plugin was never registered on.
      return BiometricAvailability.unavailable;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    if (kIsWeb) return false;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          // Biometrics only. Falling back to the device PIN would mean the
          // phone's passcode unlocks the health record, which is a different
          // and weaker promise than the one this screen makes.
          biometricOnly: true,
          // The prompt survives the app going to the background — on Android
          // the system dialog itself causes an `inactive` cycle.
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (error) {
      // Every one of these ends at the password screen; the message differs
      // only so a bug report says which happened.
      const unavailable = {
        auth_error.notAvailable,
        auth_error.notEnrolled,
        auth_error.passcodeNotSet,
      };
      const lockedOut = {
        auth_error.lockedOut,
        auth_error.permanentlyLockedOut,
      };
      final what = unavailable.contains(error.code)
          ? 'unavailable'
          : lockedOut.contains(error.code)
              ? 'locked out'
              : 'failed';
      debugPrint('Biometric prompt $what (${error.code}).');
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

/// Always unavailable. Wired into widget tests, where there is no plugin on the
/// other end of the channel and a prompt would hang the pump.
class UnavailableBiometricService implements BiometricService {
  const UnavailableBiometricService();

  @override
  Future<BiometricAvailability> availability() async =>
      BiometricAvailability.unavailable;

  @override
  Future<bool> authenticate({required String reason}) async => false;
}

final biometricServiceProvider = Provider<BiometricService>(
  (ref) => LocalAuthBiometricService(),
);

/// Whether a fingerprint can be offered on this device, read once per launch.
final biometricAvailabilityProvider =
    FutureProvider<BiometricAvailability>((ref) async {
  return ref.watch(biometricServiceProvider).availability();
});
