/// The design system's contract, as assertions.
///
/// DESIGN.md quotes contrast ratios. Quoted numbers rot the moment someone
/// nudges a colour, so they are recomputed here: change a token and the number
/// that no longer holds fails a test rather than a screen reader.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ayuvo/core/theme/app_theme.dart';
import 'package:ayuvo/core/theme/app_tokens.dart';

/// WCAG 2.1 relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

/// AA for body text and for any text below 18pt — which is all of ours.
const _aaText = 4.5;

/// AA for a focus ring, a border, or any other non-text affordance.
const _aaNonText = 3.0;

void main() {
  group('both themes build', () {
    for (final (name, theme) in [('light', AppTheme.light), ('dark', AppTheme.dark)]) {
      test('$name carries every extension a widget may ask for', () {
        expect(theme.extension<AppStatusColors>(), isNotNull);
        expect(theme.extension<AppChartColors>(), isNotNull);
        expect(theme.extension<AppTypography>(), isNotNull);
      });

      test('$name defines the full type scale', () {
        final t = theme.textTheme;
        for (final style in [
          t.displaySmall,
          t.headlineMedium,
          t.titleLarge,
          t.titleMedium,
          t.bodyLarge,
          t.bodyMedium,
          t.bodySmall,
          t.labelLarge,
          t.labelMedium,
          t.labelSmall,
        ]) {
          expect(style, isNotNull);
          expect(style!.fontSize, isNotNull);
          // Every style needs an explicit line height; leaving it to the font
          // makes vertical rhythm unpredictable across Latin and Devanagari.
          expect(style.height, isNotNull, reason: 'missing line height');
        }
      });

      test('$name numerals use tabular figures', () {
        final n = theme.extension<AppTypography>()!;
        for (final style in [n.numericLarge, n.numericMedium]) {
          expect(
            style.fontFeatures,
            contains(const FontFeature.tabularFigures()),
            reason: 'figures must not change width as they tick',
          );
        }
      });
    }
  });

  group('contrast — text', () {
    final cases = <String, (Color, Color, ThemeData)>{
      'body on surface': (
        AppTheme.light.colorScheme.onSurface,
        AppTheme.light.colorScheme.surface,
        AppTheme.light
      ),
      'secondary on surface': (
        AppTheme.light.colorScheme.onSurfaceVariant,
        AppTheme.light.colorScheme.surface,
        AppTheme.light
      ),
      'body on card': (
        AppTheme.light.colorScheme.onSurface,
        AppTheme.light.colorScheme.surfaceContainer,
        AppTheme.light
      ),
      'button label on primary': (
        AppTheme.light.colorScheme.onPrimary,
        AppTheme.light.colorScheme.primary,
        AppTheme.light
      ),
      'error on surface': (
        AppTheme.light.colorScheme.error,
        AppTheme.light.colorScheme.surface,
        AppTheme.light
      ),
      'dark body on surface': (
        AppTheme.dark.colorScheme.onSurface,
        AppTheme.dark.colorScheme.surface,
        AppTheme.dark
      ),
      'dark secondary on surface': (
        AppTheme.dark.colorScheme.onSurfaceVariant,
        AppTheme.dark.colorScheme.surface,
        AppTheme.dark
      ),
      'dark body on card': (
        AppTheme.dark.colorScheme.onSurface,
        AppTheme.dark.colorScheme.surfaceContainer,
        AppTheme.dark
      ),
      'dark button label on primary': (
        AppTheme.dark.colorScheme.onPrimary,
        AppTheme.dark.colorScheme.primary,
        AppTheme.dark
      ),
      'dark error on surface': (
        AppTheme.dark.colorScheme.error,
        AppTheme.dark.colorScheme.surface,
        AppTheme.dark
      ),
    };

    cases.forEach((name, tuple) {
      final (fg, bg, _) = tuple;
      test('$name meets AA', () {
        expect(_contrast(fg, bg), greaterThanOrEqualTo(_aaText),
            reason: '$name is ${_contrast(fg, bg).toStringAsFixed(2)}:1');
      });
    });
  });

  group('contrast — status', () {
    for (final (label, theme) in [
      ('light', AppTheme.light),
      ('dark', AppTheme.dark),
    ]) {
      final s = theme.extension<AppStatusColors>()!;
      final surface = theme.colorScheme.surface;

      test('$label status text is readable on the surface', () {
        for (final (name, c) in [('ok', s.ok), ('caution', s.caution), ('alert', s.alert)]) {
          expect(_contrast(c, surface), greaterThanOrEqualTo(_aaText),
              reason: '$name is ${_contrast(c, surface).toStringAsFixed(2)}:1');
        }
      });

      test('$label status text is readable on its own container', () {
        for (final (name, fg, bg) in [
          ('ok', s.ok, s.okContainer),
          ('caution', s.caution, s.cautionContainer),
          ('alert', s.alert, s.alertContainer),
        ]) {
          expect(_contrast(fg, bg), greaterThanOrEqualTo(_aaText),
              reason: '$name chip is ${_contrast(fg, bg).toStringAsFixed(2)}:1');
        }
      });
    }
  });

  group('contrast — non-text', () {
    test('the focus ring is visible against both surfaces', () {
      expect(_contrast(AppPalette.cyan600, AppTheme.light.colorScheme.surface),
          greaterThanOrEqualTo(_aaNonText));
      expect(_contrast(AppPalette.cyanDark, AppTheme.dark.colorScheme.surface),
          greaterThanOrEqualTo(_aaNonText));
    });

    test('chart series are distinguishable from their surface', () {
      for (final (theme, ext) in [
        (AppTheme.light, AppChartColors.light),
        (AppTheme.dark, AppChartColors.dark),
      ]) {
        for (final c in ext.series) {
          expect(_contrast(c, theme.colorScheme.surface),
              greaterThanOrEqualTo(_aaNonText),
              reason: '$c on ${theme.colorScheme.surface}');
        }
      }
    });
  });

  group('reserved colours', () {
    test('no chart series reuses a status colour', () {
      for (final (chart, status) in [
        (AppChartColors.light, AppStatusColors.light),
        (AppChartColors.dark, AppStatusColors.dark),
      ]) {
        final reserved = {status.ok, status.caution, status.alert};
        for (final series in chart.series) {
          expect(reserved, isNot(contains(series)),
              reason: 'status colours mean something; a series must not borrow one');
        }
      }
    });

    test('the series order is fixed and the same length in both modes', () {
      expect(AppChartColors.light.series, hasLength(4));
      expect(AppChartColors.dark.series, hasLength(AppChartColors.light.series.length));
    });
  });

  group('component themes are set, not left to Material defaults', () {
    for (final (name, theme) in [('light', AppTheme.light), ('dark', AppTheme.dark)]) {
      test('$name maps the component layer', () {
        expect(theme.cardTheme.shape, isA<RoundedRectangleBorder>());
        expect(theme.cardTheme.elevation, 0, reason: 'cards are flat with a hairline');
        expect(theme.inputDecorationTheme.filled, isTrue);
        expect(theme.filledButtonTheme.style, isNotNull);
        expect(theme.chipTheme.shape, isA<RoundedRectangleBorder>());
        expect(theme.bottomSheetTheme.showDragHandle, isTrue);
        expect(theme.navigationBarTheme.labelBehavior,
            NavigationDestinationLabelBehavior.alwaysShow);
        expect(theme.dividerTheme.color, theme.colorScheme.outlineVariant);
      });

      test('$name buttons meet the minimum touch target', () {
        final size = theme.filledButtonTheme.style
            ?.minimumSize
            ?.resolve(<WidgetState>{});
        expect(size?.height, greaterThanOrEqualTo(AppTouch.target));
      });
    }
  });

  testWidgets('a widget reads tokens through the context extensions',
      (tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(captured.colors.primary, AppPalette.cyan700);
    expect(captured.status.ok, AppPalette.okLight);
    expect(captured.chart.series.first, isNotNull);
    expect(captured.numerals.numericLarge.fontSize, 28);
    expect(captured.texts.titleLarge, isNotNull);
  });

  testWidgets('reduced motion collapses every duration', (tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(AppMotion.of(captured, AppMotion.slow), Duration.zero);
    expect(AppMotion.of(captured, AppMotion.base), Duration.zero);
  });
}
