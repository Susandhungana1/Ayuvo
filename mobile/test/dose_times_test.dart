/// `taking_times` is a JSON array inside a string, and the column has never
/// been validated. These pin both halves: what we can read, and what we write.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:medistore/features/medicines/domain/dose_schedule.dart';
import 'package:medistore/features/medicines/domain/dose_times.dart';
import 'package:medistore/features/medicines/domain/medicine.dart';

Medicine medicine({
  String id = 'med-1',
  String name = 'Amlodipine',
  String start = '2026-01-01',
  String? end,
  String? times,
}) {
  return Medicine(
    id: id,
    name: name,
    dosage: '5 mg',
    frequency: 'Once daily',
    startDate: start,
    endDate: end,
    takingTimes: times,
  );
}

void main() {
  group('DoseTimes.decode', () {
    test('reads the stored shape', () {
      expect(DoseTimes.decode('["08:00","20:00"]'), ['08:00', '20:00']);
    });

    test('sorts, so the schedule is in clock order however it was stored', () {
      expect(DoseTimes.decode('["20:00","08:00"]'), ['08:00', '20:00']);
    });

    test('deduplicates', () {
      expect(DoseTimes.decode('["08:00","8:00"]'), ['08:00']);
    });

    test('pads a sloppy time the web app may have written', () {
      // The column was fed by <input type="time"> with nothing validating it.
      expect(DoseTimes.decode('["8:5"]'), ['08:05']);
    });

    test('degrades to empty rather than throwing, exactly as the server does',
        () {
      // app/core/doses.py::parse_times swallows all of these. A medicine row
      // with a corrupt value must still appear in the list.
      expect(DoseTimes.decode('not json'), isEmpty);
      expect(DoseTimes.decode('{"morning":"08:00"}'), isEmpty);
      expect(DoseTimes.decode('["25:00","-1:00","","noon"]'), isEmpty);
      expect(DoseTimes.decode(null), isEmpty);
      expect(DoseTimes.decode(''), isEmpty);
    });

    test('keeps the good entries when only some are bad', () {
      expect(DoseTimes.decode('["08:00","garbage","20:00"]'),
          ['08:00', '20:00']);
    });
  });

  group('DoseTimes.encode', () {
    test('produces what the server stores', () {
      expect(DoseTimes.encode(['20:00', '08:00']), '["08:00","20:00"]');
    });

    test('an empty set is null, not "[]"', () {
      // PUT reads null as "leave unchanged", so the caller has to decide what
      // clearing means rather than getting it by accident.
      expect(DoseTimes.encode([]), isNull);
      expect(DoseTimes.encode(['nonsense']), isNull);
    });

    test('round-trips', () {
      const original = '["08:00","14:30","20:00"]';
      expect(DoseTimes.encode(DoseTimes.decode(original)), original);
    });
  });

  group('Medicine.coversDay', () {
    test('an open-ended course covers any day from its start', () {
      final med = medicine(start: '2026-01-01');
      expect(med.coversDay(DateTime(2026, 8, 6)), isTrue);
      expect(med.coversDay(DateTime(2025, 12, 31)), isFalse);
    });

    test('both bounds are inclusive, matching the server\'s comparison', () {
      final med = medicine(start: '2026-08-06', end: '2026-08-06');
      expect(med.coversDay(DateTime(2026, 8, 6)), isTrue);
      expect(med.coversDay(DateTime(2026, 8, 7)), isFalse);
      expect(med.coversDay(DateTime(2026, 8, 5)), isFalse);
    });

    test('an empty end date means ongoing, not ended', () {
      expect(medicine(end: '').coversDay(DateTime(2026, 8, 6)), isTrue);
    });
  });

  group('DoseSchedule', () {
    test('forDay orders by time and skips medicines with no schedule', () {
      final slots = DoseSchedule.forDay(
        [
          medicine(id: 'a', name: 'Evening', times: '["20:00"]'),
          medicine(id: 'b', name: 'Morning', times: '["08:00"]'),
          medicine(id: 'c', name: 'No schedule'),
        ],
        DateTime(2026, 8, 6),
      );
      expect(slots.map((slot) => slot.medicine.name), ['Morning', 'Evening']);
    });

    test('forDay leaves out a course that has ended', () {
      final slots = DoseSchedule.forDay(
        [medicine(end: '2026-08-05', times: '["08:00"]')],
        DateTime(2026, 8, 6),
      );
      expect(slots, isEmpty);
    });

    test('next picks the first slot still ahead today', () {
      final next = DoseSchedule.next(
        [medicine(times: '["08:00","14:00","20:00"]')],
        DateTime(2026, 8, 6, 12, 30),
      );
      expect(next!.time, '14:00');
    });

    test('next rolls to tomorrow once today is finished', () {
      // At 9pm every slot is behind you, and "nothing scheduled" would be a
      // lie — the 8am dose is the answer.
      final next = DoseSchedule.next(
        [medicine(times: '["08:00","20:00"]')],
        DateTime(2026, 8, 6, 21, 0),
      );
      expect(next!.time, '08:00');
      expect(next.at.day, 7);
    });

    test('next is null when tomorrow is past the end date too', () {
      final next = DoseSchedule.next(
        [medicine(end: '2026-08-06', times: '["08:00"]')],
        DateTime(2026, 8, 6, 21, 0),
      );
      expect(next, isNull);
    });

    test('a dose key is unique per medicine, time and day', () {
      final slots = DoseSchedule.forDay(
        [medicine(times: '["08:00","20:00"]')],
        DateTime(2026, 8, 6),
      );
      expect(slots.map((slot) => slot.key).toSet(), hasLength(2));
      expect(slots.first.key, 'med-1-08:00-2026-08-06');
    });
  });
}
