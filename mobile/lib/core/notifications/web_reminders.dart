/// Dose reminders on the web build, delivered by the server's Web Push.
///
/// A phone schedules alarms locally (`LocalReminders`); a browser cannot — the
/// app is not running most of the time, and `flutter_local_notifications` has
/// no web target. The web build already has exactly what a browser needs: the
/// server's existing Web Push endpoints and scheduler. So this implementation
/// does no local scheduling at all. It
///
///   1. registers a service worker (`web/sw.js`) that can show a notification,
///   2. subscribes the browser with the server's VAPID key,
///   3. tells the server about the subscription (`/api/push/subscribe`),
///
/// and from then on the backend reminder scheduler pushes a reminder at each
/// dose time — even when the tab is closed — exactly as it does for the Next.js
/// PWA. `schedule()` returns the slot count as the number the server will send;
/// `cancelAll()` unsubscribes so the server stops delivering to this device.
library;

import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import '../../features/medicines/domain/dose_schedule.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
import 'reminders.dart';

/// Picked by the conditional import in `reminders.dart` on the web build only.
Reminders createWebReminders(ApiClient client) => WebReminders(client);

class WebReminders implements Reminders {
  WebReminders(this._client);

  final ApiClient _client;

  /// Relative to the site root — Flutter copies `web/` verbatim into the
  /// build, so this file lands beside `index.html`.
  static const _swUrl = '/sw.js';

  bool _ready = false;
  bool _vapidEnabled = false;
  String _vapidPublicKey = '';
  web.ServiceWorkerRegistration? _registration;

  /// Why reminders could not be armed, set at whichever step failed. Shown on
  /// the settings screen when nothing is scheduled, so a user can read back
  /// exactly what the browser refused.
  String? _setupNote;

  @override
  String? get setupNote => _setupNote;

  @override
  Future<void> initialise() async {
    if (_ready) return;
    _ready = true;
    if (!_webPushSupported()) {
      _setupNote = 'This browser cannot show notifications (no web push API).';
      return;
    }

    try {
      _registration =
          await web.window.navigator.serviceWorker.register(_swUrl.toJS).toDart;
      // The key is public (it only lets a server encrypt a message to us), so
      // it is fetched without a session.
      final key = await _client.get<Map<String, dynamic>>(
        '/api/push/vapid-public-key',
        options: unauthenticated,
      );
      _vapidEnabled = key['enabled'] == true;
      _vapidPublicKey = (key['public_key'] as String?) ?? '';
    } catch (error) {
      debugPrint('Web push initialise failed: $error');
      _setupNote = 'Could not reach the push service ($error).';
    }
  }

  /// A context where the browser can show notifications and push. Reading the
  /// globals throws in a browser that lacks the API (or an insecure context),
  /// so existence is proven by surviving the read rather than inspected.
  bool _webPushSupported() {
    try {
      web.Notification.permission;
      web.window.navigator.serviceWorker;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<ReminderPermission> status() async {
    await initialise();
    if (!_webPushSupported()) return ReminderPermission.unsupported;
    try {
      return switch (web.Notification.permission) {
        'granted' => ReminderPermission.granted,
        'denied' => ReminderPermission.denied,
        _ => ReminderPermission.unknown,
      };
    } catch (_) {
      return ReminderPermission.unsupported;
    }
  }

  @override
  Future<ReminderPermission> request() async {
    await initialise();
    if (!_webPushSupported()) return ReminderPermission.unsupported;
    try {
      final permission =
          await web.Notification.requestPermission().toDart;
      return switch (permission) {
        'granted' => ReminderPermission.granted,
        'denied' => ReminderPermission.denied,
        _ => ReminderPermission.unknown,
      };
    } catch (_) {
      return ReminderPermission.unsupported;
    }
  }

  @override
  bool? permissionNow() {
    try {
      return switch (web.Notification.permission) {
        'granted' => true,
        'denied' => false,
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }

  /// Creates the push subscription and tells the server about it, so the
  /// reminder scheduler can push to this device.
  ///
  /// This is the web build's critical gesture: on iOS, `subscribe()` only
  /// succeeds as the *first* awaited call of the user tap that reached it —
  /// any earlier `await` (even of an already-resolved future) revokes the
  /// gesture token and the call throws `NotAllowedError`. The settings screen
  /// therefore calls this straight from the toggle's tap handler, and we lean
  /// on [initialise] having already registered the service worker and fetched
  /// the VAPID key (pre-warmed at app launch), so there is nothing left to
  /// await before `subscribe()` here.
  @override
  Future<bool> ensureSubscribed() async {
    if (!_vapidEnabled || _vapidPublicKey.isEmpty) {
      _setupNote = 'Push is not configured on the server.';
      return false;
    }
    final registration = _registration;
    if (registration == null) {
      _setupNote = 'The notification worker has not started yet — try again.';
      return false;
    }
    try {
      if (web.Notification.permission != 'granted') {
        _setupNote = 'Notifications are not allowed.';
        return false;
      }
    } catch (_) {
      return false;
    }
    final web.PushManager manager;
    try {
      manager = registration.pushManager;
    } catch (_) {
      // iOS only exposes PushManager inside a Home Screen web app; in a
      // Safari tab this is undefined and every reminder stays silent.
      _setupNote = 'Open MediStore from your Home Screen to receive '
          'notifications (this browser tab cannot).';
      return false;
    }
    try {
      final sub = await manager
          .subscribe(
            web.PushSubscriptionOptionsInit(
              userVisibleOnly: true,
              applicationServerKey: _decodeVapidKey(_vapidPublicKey).toJS,
            ),
          )
          .toDart;
      return await _registerOnServer(sub);
    } catch (error) {
      debugPrint('Push subscribe failed: $error');
      _setupNote = 'The browser refused to subscribe ($error).';
      return false;
    }
  }

  /// The current subscription for our service worker, creating it if needed.
  ///
  /// Returns null when push is not configured on the server or the browser
  /// refused to subscribe (iOS Safari before the app is added to the Home
  /// Screen is the classic case).
  Future<web.PushSubscription?> _subscription() async {
    await initialise();
    if (!_webPushSupported()) {
      _setupNote = 'This browser cannot show notifications (no web push API).';
      return null;
    }
    if (!_vapidEnabled || _vapidPublicKey.isEmpty) {
      _setupNote = 'Push is not configured on the server.';
      return null;
    }
    final registration = _registration;
    if (registration == null) {
      _setupNote = 'The notification worker has not started yet — try again.';
      return null;
    }

    final web.PushManager manager;
    try {
      manager = registration.pushManager;
    } catch (_) {
      // iOS only exposes PushManager inside a Home Screen web app; in a
      // Safari tab this is undefined and every reminder stays silent.
      _setupNote = 'Open MediStore from your Home Screen to receive '
          'notifications (this browser tab cannot).';
      return null;
    }
    try {
      var sub = await manager.getSubscription().toDart;
      sub ??= await manager
          .subscribe(
            web.PushSubscriptionOptionsInit(
              userVisibleOnly: true,
              applicationServerKey: _decodeVapidKey(_vapidPublicKey).toJS,
            ),
          )
          .toDart;
      return sub;
    } catch (error) {
      debugPrint('Push subscribe failed: $error');
      _setupNote = 'The browser refused to subscribe ($error).';
      return null;
    }
  }

  Future<bool> _registerOnServer(web.PushSubscription sub) async {
    try {
      // dartify() returns the nested keys object as a plain Map; casting it to
      // Map<String, dynamic> throws a TypeError. Use raw Map access instead.
      final Object? payload = sub.toJSON().dartify();
      if (payload is! Map) {
        throw const FormatException('PushSubscription.toJSON() did not return an object');
      }
      final Object? keys = payload['keys'];
      if (keys is! Map) {
        throw const FormatException('PushSubscription did not include keys');
      }
      final timezone = DateTime.now().timeZoneName;
      await _client.post<Map<String, dynamic>>(
        '/api/push/subscribe',
        body: {
          'endpoint': payload['endpoint'],
          'keys': {'p256dh': keys['p256dh'], 'auth': keys['auth']},
          'timezone': timezone,
        },
      );
      return true;
    } catch (error) {
      debugPrint('Push subscribe (server) failed: $error');
      // The status and server detail go straight into the settings-screen note
      // so a phone user can read back exactly what the server refused.
      final detail =
          error is ApiException ? '${error.statusCode}: ${error.message}' : '$error';
      _setupNote = 'The server did not accept the subscription ($detail).';
      return false;
    }
  }

  @override
  Future<int> schedule(List<DoseSlot> slots) async {
    if (await status() != ReminderPermission.granted) {
      _setupNote = 'Notifications are not allowed.';
      return 0;
    }
    final sub = await _subscription();
    if (sub == null) return 0;
    if (!await _registerOnServer(sub)) {
      // _registerOnServer already set _setupNote with the exact failure.
      return 0;
    }
    _setupNote = null;
    return slots.length;
  }

  @override
  Future<void> cancelAll() async {
    final registration = _registration;
    if (registration == null) return;
    try {
      final sub = await registration.pushManager.getSubscription().toDart;
      if (sub != null) {
        await sub.unsubscribe().toDart;
        // Best-effort: tell the server to drop the endpoint so a stale push
        // never 410s on a later tick. If this fails the server prunes dead
        // subscriptions itself on the next send.
        try {
          await _client.post<Map<String, dynamic>>(
            '/api/push/unsubscribe',
            body: {'endpoint': sub.endpoint},
          );
        } catch (_) {}
      }
    } catch (error) {
      debugPrint('Push unsubscribe failed: $error');
    }
  }

  @override
  Future<bool> sendTest() async {
    try {
      final result = await _client.post<Map<String, dynamic>>('/api/push/test');
      return ((result['sent'] as num?)?.toInt() ?? 0) > 0;
    } catch (error) {
      debugPrint('Push test failed: $error');
      return false;
    }
  }
}

/// The VAPID key arrives URL-safe and unpadded; the browser wants the raw
/// bytes. Normalising before decoding keeps it tolerant of either form.
Uint8List _decodeVapidKey(String key) {
  var b64 = key.replaceAll('-', '+').replaceAll('_', '/');
  while (b64.length % 4 != 0) {
    b64 += '=';
  }
  return base64Decode(b64);
}
