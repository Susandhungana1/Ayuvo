/// Turning a list of medicines into "what do I take, and when".
///
/// The server stores a course (`start_date`…`end_date`) and a set of clock
/// times; it never materialises a dose. Every screen that shows today's doses
/// or a next-dose countdown derives them here, so the definition of "active"
/// and the ordering of slots exist once.
library;

import '../../../core/time/medi_time.dart';
import 'dose_times.dart';
import 'medicine.dart';

/// One medicine at one time on one day.
class DoseSlot {
  const DoseSlot({
    required this.medicine,
    required this.time,
    required this.at,
  });

  final Medicine medicine;

  /// The stored slot, `"08:00"` — the value `POST /{id}/intake` wants back.
  final String time;

  /// That slot as a local instant on a specific day.
  final DateTime at;

  bool isPast(DateTime now) => at.isBefore(now);

  /// A stable identity for a dose on a day: the de-dupe key the web's alarm
  /// component uses, and the right key for a list row.
  String get key => '${medicine.id}-$time-${MediTime.dateOnly(at)}';

  @override
  String toString() => 'DoseSlot(${medicine.name} at $time)';
}

abstract final class DoseSchedule {
  /// Every dose scheduled on [day], ordered by time.
  ///
  /// A medicine with no `taking_times` contributes nothing: it is a real
  /// prescription with no schedule attached, and inventing a time for it would
  /// be worse than showing none.
  static List<DoseSlot> forDay(Iterable<Medicine> medicines, DateTime day) {
    final slots = <DoseSlot>[];
    for (final medicine in medicines) {
      if (!medicine.coversDay(day)) continue;
      for (final time in medicine.times) {
        final minutes = DoseTimes.minutesOfDay(time);
        if (minutes == null) continue;
        slots.add(
          DoseSlot(
            medicine: medicine,
            time: time,
            at: DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60),
          ),
        );
      }
    }
    slots.sort((a, b) {
      final byTime = a.at.compareTo(b.at);
      return byTime != 0 ? byTime : a.medicine.name.compareTo(b.medicine.name);
    });
    return slots;
  }

  /// The next dose due at or after [now], looking at today and then tomorrow.
  ///
  /// Tomorrow matters: at 9pm every one of today's slots is behind you, and
  /// "nothing scheduled" would be wrong — the 8am dose is the answer.
  static DoseSlot? next(Iterable<Medicine> medicines, DateTime now) {
    final list = medicines.toList(growable: false);
    for (final slot in forDay(list, now)) {
      if (!slot.at.isBefore(now)) return slot;
    }
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final ahead = forDay(list, tomorrow);
    return ahead.isEmpty ? null : ahead.first;
  }

  /// Medicines whose course covers today — what the interactions check looks
  /// at, and what the list shows above the finished ones.
  static List<Medicine> activeOn(Iterable<Medicine> medicines, DateTime day) =>
      [for (final medicine in medicines) if (medicine.coversDay(day)) medicine];
}
