/// Dose reminders, scheduled on the phone.
///
/// **Why local and not the server's push.** `/api/push/*` speaks Web Push: it
/// stores a browser `PushSubscription` (endpoint + p256dh + auth) and signs
/// payloads with VAPID. An Android app has no such subscription, so those
/// routes cannot be reused — only replaced, and replacing them is a backend
/// change the freeze forbids until phase 7. Scheduling here needs nothing from
/// the server at all, which is why the brief calls for it first.
///
/// **What that costs, honestly.** A reminder scheduled here dies with the app's
/// data: reinstall the app, or switch phones, and the alarms are gone until the
/// app is opened again. It also cannot fan out to a caretaker — that is
/// server-side delivery and stays with `reminder_scheduler.py`. Both are
/// written up in `BACKEND_NOTES.md` as the case for FCM routes beside the Web
/// Push ones.
///
/// **What the notification says.** The medicine's name and dose, which is
/// visible on a lock screen. That is a real disclosure, and it is deliberate:
/// a reminder that will not say what to take is not a reminder. It matches
/// what the product already does — `_payload` in `reminder_scheduler.py` sends
/// "Time for Amlodipine 5 mg" over Web Push today. Nothing here leaves the
/// device.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../features/medicines/domain/dose_schedule.dart';
import '../../features/medicines/domain/medicine.dart';
import '../network/network_providers.dart';
import '../time/medi_time.dart';
import 'web_reminders_stub.dart'
    if (dart.library.js_interop) 'web_reminders.dart' as web_reminders;

enum ReminderPermission {
  /// Allowed to post notifications.
  granted,

  /// Refused, or switched off in system settings. Only the user can undo this;
  /// asking again from here does nothing on Android 13+.
  denied,

  /// Never asked. The one state where prompting is appropriate.
  unknown,

  /// A platform with no notification support in this build (a widget test, a
  /// desktop run). Not an error, and not worth a message on screen.
  unsupported,
}

/// The seam the tests use. A widget test must never touch the plugin: it would
/// need a platform channel, and asserting "we asked for 14 reminders" is a
/// better test than asserting the OS accepted them.
abstract interface class Reminders {
  Future<void> initialise();

  Future<ReminderPermission> status();

  /// Prompts if the platform allows it. Returns the state afterwards.
  Future<ReminderPermission> request();

  /// Whether notifications are already permitted, answered without a platform
  /// probe. Null when the platform cannot know synchronously (a phone).
  bool? permissionNow();

  /// Makes sure this device is subscribed for reminders. A no-op on a phone,
  /// where scheduling is local; in a browser it creates the Web Push
  /// subscription and registers it with the server. Returns whether the
  /// subscription now exists.
  Future<bool> ensureSubscribed();

  /// Why reminders could not be armed, in a phrase a user can read back. Null
  /// when all is well. Only web push sets this — a phone cannot be diagnosed
  /// from here — but the settings screen shows it wherever it is set.
  String? get setupNote;

  /// Replaces every scheduled reminder with the ones [slots] implies.
  /// Returns how many are now pending.
  Future<int> schedule(List<DoseSlot> slots);

  Future<void> cancelAll();

  /// Schedules a single notification a few seconds from now so the user can
  /// verify end-to-end delivery without waiting for a dose time. Returns false
  /// when permission is missing or scheduling fails — the caller says why.
  Future<bool> sendTest();
}

/// How far ahead to schedule, and how many alarms that may cost.
///
/// Android will not hold an unbounded number of alarms — the documented ceiling
/// is 500 per app, and OEM builds are stricter. Seven days of a busy schedule
/// is well inside that, and the app re-syncs every time it is opened, so the
/// window rolls forward on its own.
abstract final class ReminderWindow {
  static const days = 7;
  static const maxScheduled = 120;

  /// Every dose in the next [days] days that has not already passed.
  static List<DoseSlot> slotsFrom(
    Iterable<Medicine> medicines,
    DateTime now, {
    int days = ReminderWindow.days,
    int max = maxScheduled,
  }) {
    final slots = <DoseSlot>[];
    for (var offset = 0; offset < days; offset++) {
      final day = DateTime(now.year, now.month, now.day + offset);
      for (final slot in DoseSchedule.forDay(medicines, day)) {
        if (slot.at.isAfter(now)) slots.add(slot);
        if (slots.length >= max) return slots;
      }
    }
    return slots;
  }
}

class LocalReminders implements Reminders {
  LocalReminders([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'ayuvo.doses';
  static const _channelName = 'Dose reminders';
  static const _channelDescription =
      'One notification at each dose time on your medicine list.';

  final FlutterLocalNotificationsPlugin _plugin;

  bool _ready = false;

  @override
  Future<void> initialise() async {
    if (_ready) return;

    tzdata.initializeTimeZones();
    try {
      // A dose at 08:00 is 08:00 wherever the user is standing, so the alarm
      // has to be anchored to a named zone rather than to an offset — an offset
      // captured today is wrong the day the clocks change.
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (error) {
      // Falls back to UTC, which is wrong by hours rather than broken. Better
      // than refusing to schedule anything at all.
      debugPrint('Device timezone unavailable ($error); reminders use UTC.');
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permission is asked for later, from the settings screen, where the
        // user has just said they want reminders. Asking on first launch is
        // asking before there is anything to remind them about.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

  @override
  Future<ReminderPermission> status() async {
    await initialise();
    final android = _android;
    if (android != null) {
      final enabled = await android.areNotificationsEnabled();
      if (enabled == null) return ReminderPermission.unknown;
      return enabled ? ReminderPermission.granted : ReminderPermission.denied;
    }
    // iOS has no "have I already been granted this" that does not prompt, so
    // the honest answer before the first request is "we don't know".
    return _ios != null
        ? ReminderPermission.unknown
        : ReminderPermission.unsupported;
  }

  @override
  bool? permissionNow() => null;

  @override
  Future<bool> ensureSubscribed() async => true;

  @override
  String? get setupNote => null;

  @override
  Future<ReminderPermission> request() async {
    await initialise();
    final android = _android;
    if (android != null) {
      final granted = await android.requestNotificationsPermission() ?? false;
      // Deliberately not `requestExactAlarmsPermission`. That needs
      // SCHEDULE_EXACT_ALARM in the manifest — a permission Google Play
      // reviews and users are right to be suspicious of — and a dose reminder
      // does not need to defeat Doze to the second. See [schedule].
      return granted ? ReminderPermission.granted : ReminderPermission.denied;
    }
    final ios = _ios;
    if (ios != null) {
      final granted = await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
      return granted ? ReminderPermission.granted : ReminderPermission.denied;
    }
    return ReminderPermission.unsupported;
  }

  @override
  Future<int> schedule(List<DoseSlot> slots) async {
    await initialise();
    // Cancel first, always. Editing a medicine's times leaves alarms for the
    // old ones, and there is no way to know which id belonged to a slot that no
    // longer exists — so the whole set is rebuilt every sync.
    await cancelAll();

    var scheduled = 0;
    for (final slot in slots) {
      try {
        await _plugin.zonedSchedule(
          id: _idFor(slot),
          title: 'Time for ${slot.medicine.name}',
          body: '${slot.medicine.dosage} · ${MediTime.clockLabel(slot.time)}',
          scheduledDate: tz.TZDateTime.from(slot.at, tz.local),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDescription,
              importance: Importance.high,
              priority: Priority.high,
              category: AndroidNotificationCategory.reminder,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          // Not exact: a dose reminder does not need to interrupt Doze to the
          // second, and `inexactAllowWhileIdle` needs no special permission,
          // so reminders work on a phone that refused the exact-alarm prompt.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        scheduled++;
      } catch (error) {
        // One bad slot must not cost the other six days of reminders.
        debugPrint('Could not schedule ${slot.key}: $error');
      }
    }
    return scheduled;
  }

  @override
  Future<void> cancelAll() async {
    await initialise();
    await _plugin.cancelAll();
  }

  /// A fixed id outside the dose-id space, so a test notification can never be
  /// mistaken for a real dose slot by a re-sync.
  static const _testId = 0x7ffffff0;

  @override
  Future<bool> sendTest() async {
    await initialise();
    if (await status() != ReminderPermission.granted) return false;
    try {
      await _plugin.zonedSchedule(
        id: _testId,
        title: 'Ayuvo test reminder',
        body: 'Your dose reminders are working.',
        scheduledDate:
            tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10)),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      return true;
    } catch (error) {
      // One bad schedule must not take the settings screen down with it.
      debugPrint('Could not schedule test reminder: $error');
      return false;
    }
  }

  /// A stable 31-bit id derived from the slot's own key, so re-scheduling the
  /// same dose reuses the same notification instead of stacking duplicates.
  static int _idFor(DoseSlot slot) => slot.key.hashCode & 0x7fffffff;
}

/// The null object: used in tests and on any platform where the plugin is not
/// available. Records what it was asked to do so a test can assert on it.
class NoReminders implements Reminders {
  NoReminders({this.permission = ReminderPermission.unsupported});

  ReminderPermission permission;

  /// Every `schedule` call, most recent last.
  final scheduled = <List<DoseSlot>>[];

  int cancels = 0;

  /// How many times a test reminder was asked for. Lets a widget test assert on
  /// the button without a platform channel.
  int testRequests = 0;

  @override
  Future<void> initialise() async {}

  @override
  Future<ReminderPermission> status() async => permission;

  @override
  Future<ReminderPermission> request() async => permission;

  @override
  bool? permissionNow() =>
      permission == ReminderPermission.granted ? true : null;

  @override
  String? get setupNote => null;

  /// How many times `ensureSubscribed` asked for a subscription.
  int subscribes = 0;

  @override
  Future<bool> ensureSubscribed() async {
    if (permission == ReminderPermission.granted) {
      subscribes++;
      return true;
    }
    return false;
  }

  @override
  Future<int> schedule(List<DoseSlot> slots) async {
    scheduled.add(slots);
    return slots.length;
  }

  @override
  Future<void> cancelAll() async => cancels++;

  @override
  Future<bool> sendTest() async {
    testRequests++;
    return permission == ReminderPermission.granted;
  }
}

/// The real thing on a phone, the server's Web Push in a browser, a no-op
/// everywhere else (a widget test overrides this; nothing else should have to
/// know which it got).
final remindersProvider = Provider<Reminders>((ref) {
  if (kIsWeb) {
    return web_reminders.createWebReminders(ref.watch(apiClientProvider));
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => LocalReminders(),
    _ => NoReminders(),
  };
});
