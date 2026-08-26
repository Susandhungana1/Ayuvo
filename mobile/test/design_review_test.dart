/// Renders the design-review gallery in both themes, at normal and 2× text
/// scale, on a small phone. DESIGN.md claims the system survives text scaling
/// to 2.0 with no clipping; this is what makes that a fact rather than a claim.
///
/// No error-capture plumbing here on purpose: the test binding already turns a
/// RenderFlex overflow into a test failure. Intercepting FlutterError.onError
/// to collect them is both unnecessary and illegal — the binding asserts that a
/// test restores it, and swallowing the error hides the very thing being
/// checked.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ayuvo/core/theme/app_theme.dart';
import 'package:ayuvo/core/widgets/range_bar.dart';
import 'package:ayuvo/dev/design_gallery.dart';

/// The narrowest phone worth supporting (iPhone SE / small Android). The height
/// is deliberately huge: it makes the ListView lay out every section in one
/// pass, so overflow is detected everywhere rather than only above the fold.
/// Scrolling instead would mean flinging a list whose ballistic simulation
/// never settles at 2x text scale.
const _viewport = Size(320, 6000);

Future<void> _pumpGallery(
  WidgetTester tester, {
  required Brightness brightness,
  required double textScale,
}) async {
  tester.view.physicalSize = _viewport;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // Set these on the platform dispatcher, not by wrapping the app in a
  // MediaQuery: MaterialApp builds its own from the view and would discard it,
  // so the scale under test would silently always be 1.0.
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  await tester.pumpWidget(const DesignReviewApp());
  await tester.pumpAndSettle();
}

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'gallery renders in ${brightness.name} at ${scale}x text',
        (tester) async {
          await _pumpGallery(tester, brightness: brightness, textScale: scale);

          // Every section lays out at once in this viewport, so an overflow
          // anywhere in the gallery has already failed the test by now.
          expect(find.byType(RangeBar), findsNWidgets(3));
        },
      );
    }
  }

  testWidgets('the signature widget states are all present', (tester) async {
    await _pumpGallery(tester, brightness: Brightness.light, textScale: 1.0);

    expect(find.byType(RangeBar), findsNWidgets(3));
    // ok / caution / alert are each demonstrated, and the two out-of-range
    // states carry a direction glyph rather than relying on colour.
    expect(find.text('Normal'), findsWidgets);
    expect(find.text('Stage 1 high'), findsOneWidget);
    expect(find.text('Low'), findsWidgets);
  });

  testWidgets('a range bar exposes its reading to a screen reader',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: RangeBar(
            value: 134,
            min: 80,
            max: 190,
            normalLow: 90,
            normalHigh: 120,
            status: RangeStatus.caution,
            direction: RangeDirection.above,
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('Reading 134.0, normal range 90.0 to 120.0'),
      findsOneWidget,
    );
    handle.dispose();
  });
}
