/// TEMPORARY — the phase 1.5 design review harness.
///
/// This is not a product screen. It renders the design system so the direction
/// can be approved on a device before any real screen exists, and it is
/// replaced by the app shell in phase 3 (foundation).
///
///   `flutter run -d <device>`
library;

import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/app_tokens.dart';
import 'core/widgets/range_bar.dart';

void main() => runApp(const DesignReviewApp());

class DesignReviewApp extends StatefulWidget {
  const DesignReviewApp({super.key});

  @override
  State<DesignReviewApp> createState() => _DesignReviewAppState();
}

class _DesignReviewAppState extends State<DesignReviewApp> {
  ThemeMode _mode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediStore — design review',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _mode,
      home: _Gallery(
        mode: _mode,
        onModeChanged: (m) => setState(() => _mode = m),
      ),
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({required this.mode, required this.onModeChanged});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Design review'),
        actions: [
          IconButton(
            tooltip: 'Switch theme',
            icon: Icon(switch (mode) {
              ThemeMode.light => Icons.light_mode_outlined,
              ThemeMode.dark => Icons.dark_mode_outlined,
              ThemeMode.system => Icons.brightness_auto_outlined,
            }),
            onPressed: () => onModeChanged(switch (mode) {
              ThemeMode.system => ThemeMode.light,
              ThemeMode.light => ThemeMode.dark,
              ThemeMode.dark => ThemeMode.system,
            }),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        children: const [
          _Section(
            title: 'The signature',
            caption:
                'A reading against its band. Position carries the meaning; '
                'colour only says how urgent, and a glyph says which way.',
            child: _RangeBarDemo(),
          ),
          SizedBox(height: AppSpacing.xl),
          _Section(title: 'Type scale', child: _TypeDemo()),
          SizedBox(height: AppSpacing.xl),
          _Section(title: 'Status', child: _StatusDemo()),
          SizedBox(height: AppSpacing.xl),
          _Section(title: 'Chart series', child: _SeriesDemo()),
          SizedBox(height: AppSpacing.xl),
          _Section(title: 'Components', child: _ComponentDemo()),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, this.caption, required this.child});

  final String title;
  final String? caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.texts.titleLarge),
        if (caption != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(caption!, style: context.texts.bodySmall),
        ],
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    );
  }
}

class _RangeBarDemo extends StatelessWidget {
  const _RangeBarDemo();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _VitalTile(
          label: 'Blood pressure',
          value: '118/76',
          unit: 'mmHg',
          reading: 118,
          min: 80,
          max: 190,
          normalLow: 90,
          normalHigh: 120,
          status: RangeStatus.ok,
          bandLabel: 'Normal',
        ),
        SizedBox(height: AppSpacing.md),
        _VitalTile(
          label: 'Blood pressure',
          value: '134/86',
          unit: 'mmHg',
          reading: 134,
          min: 80,
          max: 190,
          normalLow: 90,
          normalHigh: 120,
          status: RangeStatus.caution,
          direction: RangeDirection.above,
          bandLabel: 'Stage 1 high',
        ),
        SizedBox(height: AppSpacing.md),
        _VitalTile(
          label: 'Oxygen saturation',
          value: '88',
          unit: '%',
          reading: 88,
          min: 70,
          max: 100,
          normalLow: 95,
          normalHigh: 100,
          status: RangeStatus.alert,
          direction: RangeDirection.below,
          bandLabel: 'Low',
        ),
      ],
    );
  }
}

class _VitalTile extends StatelessWidget {
  const _VitalTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.reading,
    required this.min,
    required this.max,
    required this.normalLow,
    required this.normalHigh,
    required this.status,
    required this.bandLabel,
    this.direction = RangeDirection.within,
  });

  final String label;
  final String value;
  final String unit;
  final double reading;
  final double min;
  final double max;
  final double normalLow;
  final double normalHigh;
  final RangeStatus status;
  final RangeDirection direction;
  final String bandLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label above, reading below — not side by side. A Row of
            // "label ....... 118/76 mmHg" overflows the moment someone turns
            // text scaling up, and the number is the thing being read anyway.
            Text(label, style: context.texts.bodyMedium),
            const SizedBox(height: AppSpacing.xxs),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: value, style: context.numerals.numericLarge),
                  TextSpan(text: ' $unit', style: context.texts.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            RangeBar(
              value: reading,
              min: min,
              max: max,
              normalLow: normalLow,
              normalHigh: normalHigh,
              status: status,
              direction: direction,
            ),
            const SizedBox(height: AppSpacing.sm),
            StatusChip(label: bandLabel, status: status, direction: direction),
          ],
        ),
      ),
    );
  }
}

class _TypeDemo extends StatelessWidget {
  const _TypeDemo();

  @override
  Widget build(BuildContext context) {
    final t = context.texts;
    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('128/82', style: context.numerals.numericLarge),
            Text('Health summary', style: t.headlineMedium),
            Text('Today’s medicines', style: t.titleLarge),
            Text('Amoxicillin 500mg', style: t.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Take one capsule three times a day with food. '
              'स्वास्थ्य रेकर्ड — Devanagari falls back to Noto Sans.',
              style: t.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('Recorded 6 Aug 2026, 09:14', style: t.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _StatusDemo extends StatelessWidget {
  const _StatusDemo();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        StatusChip(label: 'Normal', status: RangeStatus.ok),
        StatusChip(
          label: 'Elevated',
          status: RangeStatus.caution,
          direction: RangeDirection.above,
        ),
        StatusChip(
          label: 'Stage 2 high',
          status: RangeStatus.alert,
          direction: RangeDirection.above,
        ),
        StatusChip(
          label: 'Low',
          status: RangeStatus.alert,
          direction: RangeDirection.below,
        ),
      ],
    );
  }
}

class _SeriesDemo extends StatelessWidget {
  const _SeriesDemo();

  @override
  Widget build(BuildContext context) {
    const names = ['Systolic', 'Diastolic', 'Slot 3', 'Slot 4'];
    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          children: [
            for (var i = 0; i < context.chart.series.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 3,
                      color: context.chart.series[i],
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(names[i], style: context.texts.bodyMedium),
                    ),
                  ],
                ),
              ),
            Text(
              'Validated for colour-vision deficiency in both modes. '
              'Never green, amber or red — those mean something else here.',
              style: context.texts.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ComponentDemo extends StatelessWidget {
  const _ComponentDemo();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TextField(
          decoration: InputDecoration(
            labelText: 'Medicine name',
            hintText: 'e.g. Amoxicillin',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(onPressed: () {}, child: const Text('Save changes')),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(onPressed: () {}, child: const Text('Add another time')),
        const SizedBox(height: AppSpacing.sm),
        TextButton(onPressed: () {}, child: const Text('Remove')),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: ListTile(
            title: const Text('Amoxicillin'),
            subtitle: const Text('500mg · three times a day'),
            trailing: Icon(Icons.chevron_right, color: context.colors.onSurfaceVariant),
            onTap: () {},
          ),
        ),
      ],
    );
  }
}
