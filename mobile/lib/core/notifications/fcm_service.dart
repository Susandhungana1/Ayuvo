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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/network_providers.dart';
import '../session/session_controller.dart';

/// Top-level background handler. Must be a top-level function (not a closure
/// or method), and must be registered before any FCM subscription.
@pragma('vm:entry-point')
Future<void> fcmBackgroundHandler(RemoteMessage message) async {
  // Background handlers run in a separate isolate. No Riverpod, no shared
  // state — just enough to let the OS show the notification that FCM already
  // carries in its payload.
  debugPrint('FCM background message: ${message.messageId}');
}

/// Manages the FCM lifecycle: token, foreground messages, and server
/// registration.
class FcmService {
  FcmService(this._client);

  final ApiClient _client;
  final _messaging = FirebaseMessaging.instance;
  bool _registered = false;

  /// Called once after sign-in. Requests permission (Android 13+ / iOS),
  /// obtains the token, and registers it with the server.
  Future<void> register() async {
    if (_registered) return;

    // Request permission. On Android 13+ this shows the system dialog;
    // on iOS it shows the alert; on older Android it's a no-op that returns
    // 'authorized'.
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('FCM permission: ${settings.authorizationStatus}');

    // Get the token. On Android this returns the FCM token; on iOS the APNs
    // token wrapped for FCM. Returns null if the device cannot provide one.
    final token = await _messaging.getToken();
    if (token != null) {
      await _sendToken(token);
    }

    // Listen for token refreshes (the server needs the latest token).
    _messaging.onTokenRefresh.listen(_sendToken);

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
      // Non-fatal: the server may be down. The local reminders still work
      // while the app is alive; only the background delivery path is affected.
      debugPrint('FCM token registration failed: $error');
    }
  }

  /// Deletes the token from the server on sign-out.
  Future<void> unregister() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _client.post<Map<String, dynamic>>(
          '/api/push/fcm/remove',
          body: {'token': token},
        );
      }
      await _messaging.deleteToken();
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

    // React to sign-in / sign-out.
    ref.listen<Object?>(currentUserProvider, (previous, next) {
      if (next != null && previous == null) {
        // Signed in — register FCM.
        fcm.register();
      } else if (next == null && previous != null) {
        // Signed out — unregister.
        fcm.unregister();
      }
    });

    // First launch with an existing session.
    if (user != null) {
      // Fire-and-forget: registration happens asynchronously.
      fcm.register();
    }

    return child;
  }
}
