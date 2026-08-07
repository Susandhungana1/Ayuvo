/// The reference ranges, checked against `front/app/vitals/page.tsx:38-135`
/// band by band and boundary by boundary.
///
/// These are the app's only clinical judgement, and the web app is the other
/// copy of them. A test here failing means the two clients would tell the same
/// patient two different things about the same number.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:medistore/core/widgets/range_bar.dart';
import 'package:medistore/features/vitals/domain/vital_ranges.dart';
import 'package:medistore/features/vitals/domain/vital_sign.dart';

void main() {
  group('blood pressure', () {
    String band(int systolic, int diastolic) =>
        VitalRanges.bloodPressure(systolic, diastolic).status;

    test('the bands, at their edges', () {
      expect(band(89, 70), 'Low');
      expect(band(110, 59), 'Low');
      expect(band(120, 80), 'Normal');
      expect(band(90, 60), 'Normal');
      expect(band(129, 80), 'Elevated');
      expect(band(121, 80), 'Elevated');
      expect(band(139, 89), 'Stage 1 High');
      expect(band(179, 119), 'Stage 2 High');
      expect(band(180, 120), 'Crisis');
    });

    test('a low diastolic beats a normal systolic', () {
      // `systolic < 90 || diastolic < 60` is the first branch, so this is Low
      // even though 115 is a fine systolic.
      expect(band(115, 55), 'Low');
    });

    test('reproduces the web\'s || in the upper branches', () {
      // The first two branches use && and the rest use ||, so 135/95 lands in
      // Stage 1 rather than Stage 2. Faithfully odd: changing it would make
      // the phone disagree with the browser about the same reading.
      expect(band(135, 95), 'Stage 1 High');
    });

    test('displays as the pair, and charts as systolic', () {
      final reading = VitalRanges.bloodPressure(128, 82);
      expect(reading.display, '128/82');
      expect(reading.value, 128);
    });
  });

  group('heart rate', () {
    String band(int bpm) => VitalRanges.heartRate(bpm).status;

    test('the bands, at their edges', () {
      expect(band(59), 'Low');
      expect(band(60), 'Normal');
      expect(band(100), 'Normal');
      expect(band(101), 'Mild High');
      expect(band(120), 'Mild High');
      expect(band(121), 'High');
    });
  });

  group('blood sugar', () {
    String band(double mgdl) => VitalRanges.bloodSugar(mgdl).status;

    test('the bands, at their edges, in mg/dL', () {
      expect(band(69), 'Low');
      expect(band(70), 'Normal');
      expect(band(100), 'Normal');
      expect(band(125), 'Prediabetic');
      expect(band(180), 'High');
      expect(band(181), 'Very High');
    });

    test('rounds for display, as the web does', () {
      expect(VitalRanges.bloodSugar(98.6).display, '99');
    });
  });

  group('temperature', () {
    String band(double celsius) => VitalRanges.temperature(celsius).status;

    test('the bands, at their edges', () {
      expect(band(34.9), 'Hypothermia');
      expect(band(35.0), 'Low');
      expect(band(35.9), 'Low');
      expect(band(36.0), 'Normal');
      expect(band(37.2), 'Normal');
      expect(band(38.0), 'Mild Fever');
      expect(band(39.0), 'Fever');
      expect(band(39.1), 'High Fever');
    });

    test('one decimal place', () {
      expect(VitalRanges.temperature(36.83).display, '36.8');
    });

    test('36.05 reads Normal even though the printed band starts at 36.1', () {
      // The label says 36.1–37.2 and the analyser's branch is `< 36.0`. Both
      // come from the web; the gap is real and is reproduced rather than
      // silently closed.
      expect(band(36.05), 'Normal');
    });
  });

  group('oxygen saturation', () {
    String band(int percent) => VitalRanges.oxygen(percent).status;

    test('the bands, at their edges', () {
      expect(band(100), 'Normal');
      expect(band(95), 'Normal');
      expect(band(94), 'Mild Low');
      expect(band(90), 'Mild Low');
      expect(band(89), 'Low');
      expect(band(80), 'Low');
      expect(band(79), 'Critical');
    });
  });

  group('weight', () {
    test('is recorded, not judged', () {
      final reading = VitalRanges.bodyWeight(72.45);
      expect(reading.status, 'Recorded');
      expect(reading.display, '72.5');
      expect(reading.tone, RangeStatus.ok);
      // No band means no range bar: the healthy figure depends on the person.
      expect(VitalMetric.weight.band, isNull);
    });
  });

  group('direction', () {
    test('points the way a reading is wrong, so colour is never alone', () {
      expect(VitalRanges.oxygen(88).direction, RangeDirection.below);
      expect(VitalRanges.heartRate(140).direction, RangeDirection.above);
      expect(VitalRanges.heartRate(70).direction, RangeDirection.within);
    });
  });

  group('readingsOf', () {
    VitalSign reading({
      int? systolic,
      int? diastolic,
      int? heartRate,
      double? weight,
    }) =>
        VitalSign(
          id: 'v1',
          systolic: systolic,
          diastolic: diastolic,
          heartRate: heartRate,
          weight: weight,
          measuredAt: '2026-08-06 09:00:00',
          createdAt: '2026-08-06 09:00:00',
        );

    test('skips a blood pressure with only one half', () {
      // Half a blood pressure is not a reading, and the web's analyser skips
      // it for the same reason.
      final readings = VitalRanges.readingsOf(reading(systolic: 120));
      expect(readings, isEmpty);
    });

    test('returns only the metrics actually present, in tile order', () {
      final readings = VitalRanges.readingsOf(
        reading(systolic: 118, diastolic: 76, weight: 70, heartRate: 68),
      );
      expect(
        readings.map((r) => r.metric),
        [VitalMetric.bloodPressure, VitalMetric.heartRate, VitalMetric.weight],
      );
    });

    test('an empty row yields nothing rather than a row of zeros', () {
      // POST /api/vitals accepts a body with every field null and stores it.
      expect(reading().isEmpty, isTrue);
      expect(VitalRanges.readingsOf(reading()), isEmpty);
    });
  });
}
