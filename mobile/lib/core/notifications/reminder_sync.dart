/// Keeps the scheduled reminders equal to the medicine list.
///
/// There is no event to hang this off — no "medicine changed" webhook, no
/// background worker. What there is, is a Riverpod graph: watch the medicine
/// list and the reminders setting, and any change to either rebuilds this and
/// reschedules. Adding a dose time, ending a course, turning the switch off and
/// signing out all flow through the same path.
///
/// Mounted by the app shell, so the window rolls forward every time the app is
/// opened. That is also the honest limit of scheduling on the device: a phone
/// that never opens MediStore for eight days runs out of reminders.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/medicines/presentation/medicines_controller.dart';
import '../settings/app_settings.dart';
import 'reminders.dart';

/// How many reminders are currently scheduled. Shown on the settings screen,
/// which is also the only reason it is a value rather than a void.
final reminderSyncProvider =
    AsyncNotifierProvider<ReminderSync, int>(ReminderSync.new);

class ReminderSync extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final reminders = ref.watch(remindersProvider);
    final enabled = ref.watch(
      settingsProvider.select((s) => s.valueOrNull?.remindersEnabled ?? false),
    );

    if (!enabled) {
      // Includes sign-out, which clears the setting's owner along with
      // everything else — nobody's dose times should survive on a phone handed
      // to someone else.
      await reminders.cancelAll();
      return 0;
    }

    // Deliberately `medicinesProvider(null)`: a caretaker's client has their
    // own phone and their own reminders. Fanning a patient's doses out to a
    // caretaker's device is server-side delivery, and stays there.
    final medicines = await ref.watch(medicinesProvider(null).future);
    if (medicines.isEmpty) {
      await reminders.cancelAll();
      return 0;
    }

    if (await reminders.status() == ReminderPermission.denied) {
      // Nothing to schedule into. The settings screen says so; scheduling
      // anyway would report a number that means nothing.
      return 0;
    }

    final slots = ReminderWindow.slotsFrom(medicines, DateTime.now());
    final count = await reminders.schedule(slots);
    debugPrint('Scheduled $count dose reminders.');
    return count;
  }

  /// Re-runs the sync after the user grants permission, where nothing in the
  /// graph has changed but the answer has.
  Future<void> resync() async {
    state = const AsyncLoading();
    ref.invalidateSelf();
    await future;
  }
}
