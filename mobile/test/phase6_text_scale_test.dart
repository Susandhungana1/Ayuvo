/// Every phase 6 screen on a small phone at 2× text, in both themes — and in
/// Nepali, whose Devanagari runs longer than the English it replaces.
///
/// Phase 5 added this kind of test after finding six overflows on five
/// screens. Every screen that has ever been checked this way failed the first
/// time, so a new screen without one should be assumed broken.
///
/// No error plumbing: the test binding already turns a RenderFlex overflow into
/// a failure, and intercepting `FlutterError.onError` would hide it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medistore/core/storage/local_store.dart';
import 'package:medistore/features/care/presentation/caretakers_screen.dart';
import 'package:medistore/features/shell/presentation/more_screen.dart';
import 'package:medistore/features/timeline/presentation/timeline_screen.dart';

import 'support/fake_api.dart';
import 'support/harness.dart';

/// The narrowest phone worth supporting. Tall so a lazy list builds every row
/// in one pass — scrolling at 2× is a ballistic simulation that never settles.
const _viewport = Size(320, 4000);

/// A settings file that already says Nepali, so the first frame is localised
/// rather than switching a moment later.
InMemoryLocalStore _nepali() => InMemoryLocalStore({
      'settings.v1': '{"locale":"ne","theme":"system","reminders":false}',
    });

Future<void> _pumpAt(
  WidgetTester tester,
  FakeApi api, {
  required Brightness brightness,
  bool nepali = false,
}) async {
  tester.view.physicalSize = _viewport;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // On the platform dispatcher, not in a MediaQuery wrapper: MaterialApp builds
  // its own from the view and would discard the wrapper.
  tester.platformDispatcher.textScaleFactorTestValue = 2.0;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  await pumpSignedIn(
    tester,
    api,
    health: caretakerHealth,
    store: nepali ? _nepali() : null,
  );
}

FakeApi _backend() => FakeApi()
  ..json('GET /api/medicines', {'medicines': const []})
  ..json('GET /api/vitals', {'vitals': const []})
  ..json('GET /api/care/links', {
    'links': [
      {
        'id': 'link-1',
        'user_id': '#hos077',
        'name': 'Sita Bahadur Shrestha',
        'created_at': '2026-08-01T04:00:00Z',
        'notify': true,
        'medicine_count': 4,
        'next_dose_name': 'Metformin hydrochloride',
        'next_dose_local': '08:00',
        'next_dose_is_today': false,
        'next_dose_timezone': 'Australia/Sydney',
      },
    ],
  })
  ..json('GET /api/medicines/audit', {
    'entries': [
      {
        'id': 1,
        'actor_id': '#hos077',
        'actor_name': 'Sita Bahadur Shrestha',
        'medicine_id': 'med-1',
        'medicine_name': 'Amlodipine besylate 5 mg',
        'action': 'delete',
        'created_at': '2026-08-05T10:00:00Z',
        'by_caretaker': true,
      },
    ],
  })
  ..json('GET /api/timeline', {
    'events': [
      {
        'type': 'appointment',
        'id': 'apt-1',
        'title': 'Appointment: Cardiology follow-up review',
        'description': 'Dr Asha Rai at Bir Hospital - CONFIRMED',
        'date': '2026-08-06 09:14:22',
      },
      {
        'type': 'vital',
        'id': 'vit-1',
        'title': 'Vitals Check',
        'description': 'BP: 120/80, HR: 72, Weight: 70kg, SpO2: 98%',
        'date': '2026-08-06 03:15:00',
      },
    ],
    'total': 2,
  })
  ..json('GET /api/search', {
    'query': 'a',
    'results': [
      {
        'type': 'report',
        'id': 'rep-1',
        'title': 'complete-blood-count-june-2026.pdf (BLOOD_TEST)',
        'snippet': 'Haemoglobin slightly below range; everything else normal.',
        'date': '2026-06-14 00:00:00',
      },
    ],
    'total': 1,
  });

Future<void> _openFromAccount(WidgetTester tester, String label) async {
  await openTab(tester, 'Account');
  await tapAfterScroll(
    tester,
    find.text(label),
    scrollable: scrollableIn(MoreScreen),
  );
}

void main() {
  for (final brightness in Brightness.values) {
    final theme = brightness.name;

    testWidgets('the timeline survives 2x text in $theme', (tester) async {
      await _pumpAt(tester, _backend(), brightness: brightness);
      await _openFromAccount(tester, 'Timeline');

      // The widest row on the screen: a badge, a time, a long title and a
      // four-part vitals description.
      expect(find.text('Vitals Check'), findsOneWidget);
    });

    testWidgets('search survives 2x text in $theme', (tester) async {
      await _pumpAt(tester, _backend(), brightness: brightness);
      await _openFromAccount(tester, 'Search');
      await tester.enterText(find.byType(TextField), 'a');
      await settle(tester);

      expect(find.text('1 result'), findsOneWidget);
    });

    testWidgets('the assistant survives 2x text in $theme', (tester) async {
      await _pumpAt(tester, _backend(), brightness: brightness);
      await _openFromAccount(tester, 'Health assistant');

      // The composer is the tight one: a field, a mic and a send button on one
      // line at 320px.
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('caretakers survive 2x text in $theme', (tester) async {
      await _pumpAt(tester, _backend(), brightness: brightness);
      await _openFromAccount(tester, 'Caretakers');
      await scrollTo(
        tester,
        find.text('Recent caretaker activity'),
        scrollable: scrollableIn(CaretakersScreen),
      );

      expect(find.text('Recent caretaker activity'), findsOneWidget);
    });

    testWidgets('settings survive 2x text in $theme', (tester) async {
      await _pumpAt(tester, _backend(), brightness: brightness);
      await _openFromAccount(tester, 'Settings');

      expect(find.text('Language'), findsOneWidget);
    });

    testWidgets('the dashboard\'s caretaker section survives 2x text in $theme',
        (tester) async {
      await _pumpAt(tester, _backend(), brightness: brightness);

      // A long name, a bell button, "(their time)" and a tomorrow dose all on
      // one card.
      await scrollTo(
        tester,
        find.text('Sita Bahadur Shrestha'),
        scrollable: scrollableIn(Scaffold),
      );
      expect(find.text('4 medicines'), findsOneWidget);
    });
  }

  group('in Nepali', () {
    testWidgets('the bottom bar relabels without clipping', (tester) async {
      await _pumpAt(tester, _backend(), brightness: Brightness.light,
          nepali: true);

      expect(find.text('गृहपृष्ठ'), findsOneWidget);
      expect(find.text('औषधिहरू'), findsOneWidget);
    });

    testWidgets('Account survives 2x Devanagari', (tester) async {
      await _pumpAt(tester, _backend(), brightness: Brightness.light,
          nepali: true);
      await openTab(tester, 'खाता');

      expect(find.text('सेटिङ'), findsOneWidget);
    });

    testWidgets('the timeline survives 2x Devanagari', (tester) async {
      await _pumpAt(tester, _backend(), brightness: Brightness.light,
          nepali: true);
      await openTab(tester, 'खाता');
      await tapAfterScroll(
        tester,
        find.text('समयरेखा'),
        scrollable: scrollableIn(MoreScreen),
      );

      expect(find.byType(TimelineScreen), findsOneWidget);
      // The badge is a translated word beside a formatted time.
      expect(find.text('नाप'), findsOneWidget);
    });
  });

  group('the language switch', () {
    testWidgets('changes the app without a restart', (tester) async {
      final store = InMemoryLocalStore();
      await pumpSignedIn(tester, _backend(),
          health: caretakerHealth, store: store);
      await _openFromAccount(tester, 'Settings');

      await tester.tap(find.text('नेपाली'));
      await settle(tester);

      expect(find.text('भाषा'), findsOneWidget);
      // And it survives the next launch.
      expect(store.contents['settings.v1'], contains('"locale":"ne"'));
    });

    testWidgets('"match my phone" clears the stored choice', (tester) async {
      final store = _nepali();
      await pumpSignedIn(tester, _backend(),
          health: caretakerHealth, store: store);
      await openTab(tester, 'खाता');
      await tapAfterScroll(
        tester,
        find.text('सेटिङ'),
        scrollable: scrollableIn(MoreScreen),
      );

      await tester.tap(find.text('फोनले जे भन्छ').first);
      await settle(tester);

      expect(find.text('Language'), findsOneWidget);
      expect(store.contents['settings.v1'], contains('"locale":null'));
    });
  });
}
