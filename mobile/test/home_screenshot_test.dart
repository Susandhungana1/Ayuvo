/// Renders the real home screen to PNG files, so the redesign can be looked at
/// without a backend, a device, or a deployment.
///
/// This is a throwaway: it drives the same `AyuvoApp` and the same scripted
/// backend the other widget tests use, so what comes out is the actual widget
/// tree the phone builds — not a mock-up. The app's own fonts are loaded first,
/// because the test binding otherwise substitutes a placeholder face and every
/// line of text renders as a black bar.
///
/// Run:  flutter test test/home_screenshot_test.dart --update-goldens
/// Out:  test/screenshots/*.png
///
/// Tagged `golden` and excluded from CI on purpose. Text rasterises slightly
/// differently on every platform, so a PNG shot on Windows will never match
/// one compared on a Linux runner — a golden in CI would fail for reasons that
/// have nothing to do with the code. These images are for looking at, not for
/// asserting against.
@Tags(['golden'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_api.dart';
import 'support/harness.dart';

/// Registers every font the app declares, read from the build's own
/// `FontManifest.json`.
///
/// Hand-listing the families is what the first attempt did, and it half-worked:
/// the manifest is what Flutter actually resolves against, so reading it is the
/// only way to be sure the registered names and weights match the ones
/// `app_theme.dart` asks for. Without this the test binding substitutes a
/// placeholder face and every glyph renders as a filled box.
Future<void> loadAppFonts() async {
  final manifest = json.decode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<dynamic>;

  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final family = entry['family'] as String;
    // Flutter registers its own Material/Cupertino families already.
    if (family.startsWith('packages/')) continue;
    final loader = FontLoader(family);
    for (final font in (entry['fonts'] as List<dynamic>)
        .cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppFonts();
    Directory('test/screenshots').createSync(recursive: true);
  });

  /// A phone-shaped viewport, tall enough that the whole scroll view lays out
  /// in one pass — otherwise the shot stops at the fold.
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(420, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('screenshots/$name.png'),
    );
  }

  testWidgets('home — a real account', (tester) async {
    phone(tester);
    await pumpSignedIn(
      tester,
      FakeApi()
        ..json('GET /api/medicines', {
          'medicines': [
            medicineRow(),
            medicineRow(
              id: 'med-2',
              name: 'Metformin',
              dosage: '500 mg',
              takingTimes: '["09:00","21:00"]',
            ),
          ],
        })
        ..json('GET /api/vitals', {
          'vitals': [
            vitalRow(systolic: 138, diastolic: 88, heartRate: 74),
          ],
        })
        ..json('GET /api/reports', {
          'reports': [
            reportRow(),
            reportRow(id: 'rep-2', reportType: 'XRAY'),
          ],
          'total': 2,
        }),
    );
    await shoot(tester, 'home-with-data');
  });

  testWidgets('home — a brand-new account', (tester) async {
    phone(tester);
    await pumpSignedIn(
      tester,
      FakeApi()
        ..json('GET /api/medicines', {'medicines': const []})
        ..json('GET /api/vitals', {'vitals': const []}),
    );
    await shoot(tester, 'home-empty');
  });
}
