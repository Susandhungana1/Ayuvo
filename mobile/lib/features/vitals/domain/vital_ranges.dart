/// Reference ranges. **These are client-side only** — the API stores numbers
/// and has no opinion about them, so this file is the whole of the app's
/// clinical judgement and the web app's is the only other copy.
///
/// Ported branch for branch from `front/app/vitals/page.tsx:38-135` so the two
/// clients cannot disagree about whether a reading is normal. Where the web's
/// logic is odd, it is reproduced and the oddity is noted rather than quietly
/// improved: a patient comparing phone and browser must see the same word.
///
/// One deliberate divergence, from FEATURE_MAP §4.3: blood sugar is **mg/dL**
/// everywhere. The web's summary strip labels it mmol/L while its own analyser
/// and entry form use mg/dL — a display bug there, not a second unit.
library;

import '../../../core/widgets/range_bar.dart';
import 'vital_sign.dart';

/// The six things this app measures.
enum VitalMetric {
  bloodPressure,
  heartRate,
  bloodSugar,
  temperature,
  oxygenSaturation,
  weight;

  String get label => switch (this) {
        VitalMetric.bloodPressure => 'Blood pressure',
        VitalMetric.heartRate => 'Heart rate',
        VitalMetric.bloodSugar => 'Blood sugar',
        VitalMetric.temperature => 'Temperature',
        VitalMetric.oxygenSaturation => 'Oxygen',
        VitalMetric.weight => 'Weight',
      };

  /// The compact form, for a tile header or a chart legend.
  String get shortLabel => switch (this) {
        VitalMetric.bloodPressure => 'BP',
        VitalMetric.heartRate => 'Heart rate',
        VitalMetric.bloodSugar => 'Sugar',
        VitalMetric.temperature => 'Temp',
        VitalMetric.oxygenSaturation => 'SpO₂',
        VitalMetric.weight => 'Weight',
      };

  String get unit => switch (this) {
        VitalMetric.bloodPressure => 'mmHg',
        VitalMetric.heartRate => 'bpm',
        VitalMetric.bloodSugar => 'mg/dL',
        VitalMetric.temperature => '°C',
        VitalMetric.oxygenSaturation => '%',
        VitalMetric.weight => 'kg',
      };

  /// What "normal" is, in the shortest honest form — printed beside the tile.
  String get normalLabel => switch (this) {
        VitalMetric.bloodPressure => '≤120/80',
        VitalMetric.heartRate => '60–100',
        VitalMetric.bloodSugar => '70–100',
        VitalMetric.temperature => '36.1–37.2',
        VitalMetric.oxygenSaturation => '95–100',
        VitalMetric.weight => '—',
      };

  /// Whether [reading] carries this metric at all.
  bool presentIn(VitalSign reading) => switch (this) {
        VitalMetric.bloodPressure => reading.hasBloodPressure,
        VitalMetric.heartRate => reading.heartRate != null,
        VitalMetric.bloodSugar => reading.bloodSugar != null,
        VitalMetric.temperature => reading.temperature != null,
        VitalMetric.oxygenSaturation => reading.oxygenSaturation != null,
        VitalMetric.weight => reading.weight != null,
      };

  /// The single number a chart plots. Blood pressure charts as **systolic**,
  /// with diastolic as a second series — see [VitalMetric.diastolicOf].
  double? valueIn(VitalSign reading) => switch (this) {
        VitalMetric.bloodPressure => reading.systolic?.toDouble(),
        VitalMetric.heartRate => reading.heartRate?.toDouble(),
        VitalMetric.bloodSugar => reading.bloodSugar,
        VitalMetric.temperature => reading.temperature,
        VitalMetric.oxygenSaturation => reading.oxygenSaturation?.toDouble(),
        VitalMetric.weight => reading.weight,
      };

  /// The second series, and only blood pressure has one.
  double? diastolicOf(VitalSign reading) => this == VitalMetric.bloodPressure
      ? reading.diastolic?.toDouble()
      : null;

  /// The band drawn behind the line, and the ends of a range bar's track. The
  /// track is wider than the band so an out-of-range reading still lands
  /// somewhere visible instead of pinned to an edge.
  ({double low, double high, double min, double max})? get band =>
      switch (this) {
        VitalMetric.bloodPressure => (low: 90, high: 120, min: 70, max: 200),
        VitalMetric.heartRate => (low: 60, high: 100, min: 40, max: 160),
        VitalMetric.bloodSugar => (low: 70, high: 100, min: 40, max: 250),
        VitalMetric.temperature => (low: 36.1, high: 37.2, min: 34, max: 41),
        VitalMetric.oxygenSaturation => (low: 95, high: 100, min: 80, max: 100),
        // Weight has no normal range: the healthy figure depends on the person,
        // and inventing a band would be the app making a claim it cannot back.
        VitalMetric.weight => null,
      };

  /// How many decimals the reading is shown to.
  int get decimals => switch (this) {
        VitalMetric.temperature || VitalMetric.weight => 1,
        _ => 0,
      };
}

/// A metric of one reading, judged.
class VitalReading {
  const VitalReading({
    required this.metric,
    required this.value,
    required this.display,
    required this.status,
    required this.tone,
    required this.direction,
  });

  final VitalMetric metric;

  /// The plotted number — systolic, for a blood pressure.
  final double value;

  /// What the tile prints: `"128/82"`, `"36.8"`, `"98"`.
  final String display;

  /// The band's name, as the web says it: `Normal`, `Elevated`, `Stage 1 High`,
  /// `Prediabetic`, `Hypothermia`, `Recorded`…
  final String status;

  final RangeStatus tone;
  final RangeDirection direction;

  bool get isNormal => status == 'Normal' || status == 'Recorded';
}

abstract final class VitalRanges {
  /// Every metric present in [reading], judged, in tile order.
  static List<VitalReading> readingsOf(VitalSign reading) => [
        for (final metric in VitalMetric.values)
          if (metric.presentIn(reading)) analyse(metric, reading)!,
      ];

  /// One metric of one reading. Null when the reading doesn't carry it.
  static VitalReading? analyse(VitalMetric metric, VitalSign reading) {
    return switch (metric) {
      VitalMetric.bloodPressure => reading.hasBloodPressure
          ? bloodPressure(reading.systolic!, reading.diastolic!)
          : null,
      VitalMetric.heartRate =>
        reading.heartRate == null ? null : heartRate(reading.heartRate!),
      VitalMetric.bloodSugar =>
        reading.bloodSugar == null ? null : bloodSugar(reading.bloodSugar!),
      VitalMetric.temperature =>
        reading.temperature == null ? null : temperature(reading.temperature!),
      VitalMetric.oxygenSaturation => reading.oxygenSaturation == null
          ? null
          : oxygen(reading.oxygenSaturation!),
      VitalMetric.weight =>
        reading.weight == null ? null : bodyWeight(reading.weight!),
    };
  }

  /// `<90/60` Low · `≤120/80` Normal · `≤129/80` Elevated · `≤139/89` Stage 1 ·
  /// `≤179/119` Stage 2 · else Crisis.
  ///
  /// The last three branches are `||` in the web's code where the first two are
  /// `&&`, so 135/95 lands in Stage 1 rather than Stage 2. That is reproduced
  /// deliberately — it is the behaviour a patient has already seen.
  static VitalReading bloodPressure(int systolic, int diastolic) {
    final (status, tone, direction) = switch ((systolic, diastolic)) {
      _ when systolic < 90 || diastolic < 60 =>
        ('Low', RangeStatus.alert, RangeDirection.below),
      _ when systolic <= 120 && diastolic <= 80 =>
        ('Normal', RangeStatus.ok, RangeDirection.within),
      _ when systolic <= 129 && diastolic <= 80 =>
        ('Elevated', RangeStatus.caution, RangeDirection.above),
      _ when systolic <= 139 || diastolic <= 89 =>
        ('Stage 1 High', RangeStatus.caution, RangeDirection.above),
      _ when systolic <= 179 || diastolic <= 119 =>
        ('Stage 2 High', RangeStatus.alert, RangeDirection.above),
      _ => ('Crisis', RangeStatus.alert, RangeDirection.above),
    };
    return VitalReading(
      metric: VitalMetric.bloodPressure,
      value: systolic.toDouble(),
      display: '$systolic/$diastolic',
      status: status,
      tone: tone,
      direction: direction,
    );
  }

  /// `<60` Low · `≤100` Normal · `≤120` Mild High · else High.
  static VitalReading heartRate(int bpm) {
    final (status, tone, direction) = switch (bpm) {
      _ when bpm < 60 => ('Low', RangeStatus.caution, RangeDirection.below),
      _ when bpm <= 100 => ('Normal', RangeStatus.ok, RangeDirection.within),
      _ when bpm <= 120 =>
        ('Mild High', RangeStatus.caution, RangeDirection.above),
      _ => ('High', RangeStatus.alert, RangeDirection.above),
    };
    return VitalReading(
      metric: VitalMetric.heartRate,
      value: bpm.toDouble(),
      display: '$bpm',
      status: status,
      tone: tone,
      direction: direction,
    );
  }

  /// mg/dL. `<70` Low · `≤100` Normal · `≤125` Prediabetic · `≤180` High ·
  /// else Very High. Displayed rounded, as the web does.
  static VitalReading bloodSugar(double mgdl) {
    final (status, tone, direction) = switch (mgdl) {
      _ when mgdl < 70 => ('Low', RangeStatus.alert, RangeDirection.below),
      _ when mgdl <= 100 => ('Normal', RangeStatus.ok, RangeDirection.within),
      _ when mgdl <= 125 =>
        ('Prediabetic', RangeStatus.caution, RangeDirection.above),
      _ when mgdl <= 180 => ('High', RangeStatus.alert, RangeDirection.above),
      _ => ('Very High', RangeStatus.alert, RangeDirection.above),
    };
    return VitalReading(
      metric: VitalMetric.bloodSugar,
      value: mgdl,
      display: '${mgdl.round()}',
      status: status,
      tone: tone,
      direction: direction,
    );
  }

  /// °C. `<35` Hypothermia · `<36` Low · `≤37.2` Normal · `≤38` Mild Fever ·
  /// `≤39` Fever · else High Fever.
  static VitalReading temperature(double celsius) {
    final (status, tone, direction) = switch (celsius) {
      _ when celsius < 35.0 =>
        ('Hypothermia', RangeStatus.alert, RangeDirection.below),
      _ when celsius < 36.0 =>
        ('Low', RangeStatus.caution, RangeDirection.below),
      _ when celsius <= 37.2 =>
        ('Normal', RangeStatus.ok, RangeDirection.within),
      _ when celsius <= 38.0 =>
        ('Mild Fever', RangeStatus.caution, RangeDirection.above),
      _ when celsius <= 39.0 =>
        ('Fever', RangeStatus.alert, RangeDirection.above),
      _ => ('High Fever', RangeStatus.alert, RangeDirection.above),
    };
    return VitalReading(
      metric: VitalMetric.temperature,
      value: celsius,
      display: celsius.toStringAsFixed(1),
      status: status,
      tone: tone,
      direction: direction,
    );
  }

  /// `≥95` Normal · `≥90` Mild Low · `≥80` Low · else Critical.
  static VitalReading oxygen(int percent) {
    final (status, tone, direction) = switch (percent) {
      _ when percent >= 95 =>
        ('Normal', RangeStatus.ok, RangeDirection.within),
      _ when percent >= 90 =>
        ('Mild Low', RangeStatus.caution, RangeDirection.below),
      _ when percent >= 80 => ('Low', RangeStatus.alert, RangeDirection.below),
      _ => ('Critical', RangeStatus.alert, RangeDirection.below),
    };
    return VitalReading(
      metric: VitalMetric.oxygenSaturation,
      value: percent.toDouble(),
      display: '$percent',
      status: status,
      tone: tone,
      direction: direction,
    );
  }

  /// No band. "Recorded" is the honest word for a number this app cannot judge.
  static VitalReading bodyWeight(double kg) => VitalReading(
        metric: VitalMetric.weight,
        value: kg,
        display: kg.toStringAsFixed(1),
        status: 'Recorded',
        tone: RangeStatus.ok,
        direction: RangeDirection.within,
      );
}
