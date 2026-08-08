/// Dose reminders: which doses get an alarm, and what turns them off again.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medistore/core/notifications/reminder_sync.dart';
import 'package:medistore/core/notifications/reminders.dart';
import 'package:medistore/core/session/session_controller.dart';
import 'package:medistore/core/settings/app_settings.dart';
import 'package:medistore/core/storage/local_store.dart';
import 'package:medistore/features/medicines/data/medicine_repository.dart';
import 'package:medistore/features/medicines/domain/medicine.dart';

import 'support/fake_api.dart';
import 'support/fakes.dart';

Medicine medicine({
  String id = 'med-1',
  String name = 'Amlodipine',
  String? times = '["08:00","20:00"]',
  String startDate = '2020-01-01',
  String? endDate,
}) =>
    Medicine(
      id: id,
      name: name,
      dosage: '5 mg',
      frequency: 'Twice daily',
      startDate: startDate,
      endDate: endDate,
      takingTimes: times,
    );

void main() {
  group('which doses get an alarm', () {
    final noon = DateTime(2026, 8, 6, 12);

    test('today\'s remaining doses and the next six days', () {
      final slots = ReminderWindow.slotsFrom([medicine()], noon);

      // 20:00 today, then 08:00 and 20:00 on each of the next six days.
      expect(slots, hasLength(13));
      expect(slots.first.time, '20:00');
      expect(slots.first.at, DateTime(2026, 8, 6, 20));
    });

    test('a dose already past today is not scheduled into the past', () {
      final slots = ReminderWindow.slotsFrom([medicine()], noon);

      expect(slots.every((slot) => slot.at.isAfter(noon)), isTrue);
    });

    test('a course that has ended contributes nothing', () {
      final slots = ReminderWindow.slotsFrom(
        [medicine(endDate: '2026-08-01')],
        noon,
      );

      expect(slots, isEmpty);
    });

    test('a course starting later begins on its own start date', () {
      final slots = ReminderWindow.slotsFrom(
        [medicine(startDate: '2026-08-09')],
        noon,
      );

      expect(slots.first.at, DateTime(2026, 8, 9, 8));
    });

    test('a medicine with no dose times is not invented a schedule', () {
      // A real prescription with no times attached: showing nothing beats
      // guessing 9am.
      expect(ReminderWindow.slotsFrom([medicine(times: null)], noon), isEmpty);
    });

    test('the count is capped so Android does not refuse the lot', () {
      // The documented per-app alarm ceiling is 500, and OEM builds are
      // stricter. Seven days of a very busy schedule must stay well inside it.
      final busy = [
        for (var i = 0; i < 10; i++)
          medicine(
            id: 'med-$i',
            times: '["06:00","09:00","12:00","15:00","18:00","21:00"]',
          ),
      ];

      final slots = ReminderWindow.slotsFrom(busy, noon);

      expect(slots, hasLength(ReminderWindow.maxScheduled));
    });

    test('each slot keeps a stable identity across a re-sync', () {
      final first = ReminderWindow.slotsFrom([medicine()], noon);
      final again = ReminderWindow.slotsFrom([medicine()], noon);

      expect(first.map((s) => s.key), again.map((s) => s.key));
    });
  });

  group('keeping the schedule in step', () {
    /// Settings are resolved before the sync is read, which is the order the
    /// app runs in: the file is read on launch and the shell mounts after.
    /// Reading the sync first would only measure the one frame where the
    /// setting is still unknown.
    Future<int> sync({
      required bool enabled,
      List<Map<String, Object?>> medicines = const [],
      required Reminders reminders,
    }) async {
      final api = FakeApi()..json('GET /api/medicines', {'medicines': medicines});
      final container = ProviderContainer(
        overrides: [
          localStoreProvider.overrideWithValue(InMemoryLocalStore()),
          remindersProvider.overrideWithValue(reminders),
          currentUserProvider.overrideWithValue(testUser),
          medicineRepositoryProvider
              .overrideWithValue(MedicineRepository(api.client())),
          settingsProvider.overrideWith(
            () => _FixedSettings(AppSettings(remindersEnabled: enabled)),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(settingsProvider.future);
      return container.read(reminderSyncProvider.future);
    }

    test('the switch off cancels everything and schedules nothing', () async {
      final reminders = NoReminders(permission: ReminderPermission.granted);

      final count = await sync(
        enabled: false,
        medicines: [medicineRow()],
        reminders: reminders,
      );

      expect(count, 0);
      expect(reminders.cancels, 1);
      expect(reminders.scheduled, isEmpty);
    });

    test('the switch on schedules the medicine list', () async {
      final reminders = NoReminders(permission: ReminderPermission.granted);

      final count = await sync(
        enabled: true,
        medicines: [medicineRow()],
        reminders: reminders,
      );

      expect(count, greaterThan(0));
      expect(reminders.scheduled.single, hasLength(count));
    });

    test('an empty medicine list clears rather than schedules nothing',
        () async {
      // Removing your last medicine has to take its alarms with it.
      final reminders = NoReminders(permission: ReminderPermission.granted);

      expect(await sync(enabled: true, reminders: reminders), 0);
      expect(reminders.cancels, 1);
    });

    test('a refused permission reports nothing scheduled, honestly', () async {
      final reminders = NoReminders(permission: ReminderPermission.denied);

      final count = await sync(
        enabled: true,
        medicines: [medicineRow()],
        reminders: reminders,
      );

      expect(count, 0);
      expect(reminders.scheduled, isEmpty);
    });
  });

  group('settings on disk', () {
    test('a round trip keeps all three choices', () {
      const settings = AppSettings(
        locale: Locale('ne'),
        themeMode: ThemeMode.dark,
        remindersEnabled: true,
      );

      expect(AppSettings.fromJson(settings.toJson()), settings);
    });

    test('the default is the phone\'s own language and theme, no reminders',
        () {
      expect(AppSettings.defaults.locale, isNull);
      expect(AppSettings.defaults.themeMode, ThemeMode.system);
      expect(AppSettings.defaults.remindersEnabled, isFalse);
    });

    test('a language this build does not have falls back to the phone\'s', () {
      // A settings file written by a newer build must not stop an older one.
      final settings = AppSettings.fromJson({'locale': 'fr', 'theme': 'moon'});

      expect(settings.locale, isNull);
      expect(settings.themeMode, ThemeMode.system);
    });
  });
}

/// Settings that are simply *there*, with no disk behind them.
class _FixedSettings extends SettingsController {
  _FixedSettings(this.value);

  final AppSettings value;

  @override
  Future<AppSettings> build() async => value;
}
