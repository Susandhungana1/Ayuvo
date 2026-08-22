/// Firebase Cloud Messaging integration for reliable push reminders.
///
/// Local reminders via `flutter_local_notifications` work while the app is
/// alive or recently backgrounded, but die on reboot or after 7 days without
/// opening the app. FCM lets the server push reminders even when the app is
/// fully killed — the OS wakes it to show the notification.
///
/// The flow:
///   1. On sign-in, request an FCM token and send it to `POST /api/push/fcm`.
///   2. The server stores the token alongside the user's medicines.
///   3. The reminder scheduler sends an FCM push at each dose time.
///   4. On Android, FCM wakes the app and shows the notification even when
///      killed. On iOS, APNs handles delivery.
library;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/network_providers.dart';
import '../session/session_controller.dart';

/// Top-level background handler. Must be a top-level function (not a closure
/// or method), and must be registered before any FCM subscription.
@pragma('vm:entry-point')
Future<void> fcmBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message: ${message.messageId}');
}

/// Manages the FCM lifecycle: token, foreground messages, and server
/// registration. No-ops on web where Firebase is not initialized.
class FcmService {
  FcmService(this._client);

  final ApiClient _client;
  bool _registered = false;

  /// Called once after sign-in. Requests permission (Android 13+ / iOS),
  /// obtains the token, and registers it with the server.
  Future<void> register() async {
    if (_registered || kIsWeb) return;

    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('FCM permission: ${settings.authorizationStatus}');

    final token = await messaging.getToken();
    if (token != null) {
      await _sendToken(token);
    }

    messaging.onTokenRefresh.listen(_sendToken);

    _registered = true;
  }

  /// Sends the token to the server so the reminder scheduler can push to
  /// this device.
  Future<void> _sendToken(String token) async {
    try {
      await _client.post<Map<String, dynamic>>(
        '/api/push/fcm',
        body: {'token': token},
      );
      debugPrint('FCM token registered with server');
    } catch (error) {
      debugPrint('FCM token registration failed: $error');
    }
  }

  /// Deletes the token from the server on sign-out.
  Future<void> unregister() async {
    if (kIsWeb) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token != null) {
        await _client.post<Map<String, dynamic>>(
          '/api/push/fcm/remove',
          body: {'token': token},
        );
      }
      await messaging.deleteToken();
    } catch (_) {
      // Best-effort cleanup.
    }
    _registered = false;
  }
}

/// Riverpod provider for the FCM service.
final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService(ref.watch(apiClientProvider));
});

/// Auto-registers FCM when a user is signed in, and unregisters on sign-out.
///
/// Mounted by the app shell alongside the reminder sync.
class FcmSync extends ConsumerWidget {
  const FcmSync({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final fcm = ref.watch(fcmServiceProvider);

    ref.listen<Object?>(currentUserProvider, (previous, next) {
      if (next != null && previous == null) {
        fcm.register();
      } else if (next == null && previous != null) {
        fcm.unregister();
      }
    });

    if (user != null) {
      fcm.register();
    }

    return child;
  }
}
