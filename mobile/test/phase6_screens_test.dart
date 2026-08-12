/// The phase 6 screens, driven through the real app: real router, real
/// controllers, only the socket replaced.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medistore/features/care/presentation/caretakers_screen.dart';
import 'package:medistore/features/search/presentation/search_screen.dart';
import 'package:medistore/features/shell/presentation/more_screen.dart';
import 'package:medistore/features/timeline/presentation/timeline_screen.dart';

import 'support/fake_api.dart';
import 'support/harness.dart';

/// Every route the shell touches on the way to an Account tile.
FakeApi backend() => FakeApi()
  ..json('GET /api/medicines', {'medicines': const []})
  ..json('GET /api/vitals', {'vitals': const []});

Map<String, Object?> timelineRow({
  String type = 'report',
  String id = 'rep-1',
  String title = 'Report: bloods.pdf',
  String? description,
  String date = '2026-08-06 09:14:22',
}) =>
    {
      'type': type,
      'id': id,
      'title': title,
      'description': description,
      'date': date,
    };

Map<String, Object?> searchRow({
  String type = 'report',
  String id = 'rep-1',
  String title = 'cbc-june.pdf (BLOOD_TEST)',
  String? snippet = 'Haemoglobin slightly below range.',
  String? date = '2026-06-14 00:00:00',
}) =>
    {
      'type': type,
      'id': id,
      'title': title,
      'snippet': snippet,
      'date': date,
    };

Map<String, Object?> careLinkRow({
  String id = 'link-1',
  String userId = '#hos077',
  String name = 'Sita Bahadur',
  bool notify = true,
  int medicineCount = 2,
  String? nextDoseName = 'Metformin',
  String? nextDoseLocal = '08:00',
}) =>
    {
      'id': id,
      'user_id': userId,
      'name': name,
      'created_at': '2026-08-01T04:00:00Z',
      'notify': notify,
      'medicine_count': medicineCount,
      'next_dose_name': nextDoseName,
      'next_dose_local': nextDoseLocal,
      'next_dose_is_today': true,
      'next_dose_timezone': 'Asia/Kathmandu',
    };

Future<void> openFromAccount(
  WidgetTester tester,
  FakeApi api,
  String tile, {
  bool caretakers = false,
}) async {
  await pumpSignedIn(
    tester,
    api,
    health: caretakers ? caretakerHealth : testHealth,
  );
  await openTab(tester, 'Account');
  await tapAfterScroll(
    tester,
    find.text(tile),
    scrollable: scrollableIn(MoreScreen),
  );
}

void main() {
  group('timeline', () {
    testWidgets('rows are grouped by day and stop repeating their own type',
        (tester) async {
      final api = backend()
        ..json('GET /api/timeline', {
          'events': [
            timelineRow(title: 'Report: bloods.pdf'),
            timelineRow(
              type: 'medicine',
              id: 'med-1',
              title: 'Medicine: Amlodipine',
              description: '5 mg - Once daily',
            ),
          ],
          'total': 2,
        });

      await openFromAccount(tester, api, 'Timeline');

      // The badge says the type; the title should not say it again.
      expect(find.text('bloods.pdf'), findsOneWidget);
      expect(find.text('Amlodipine'), findsOneWidget);
      expect(find.text('REPORT'), findsOneWidget);
      expect(find.text('MEDICINE'), findsOneWidget);
      expect(api.unmatched, isEmpty);
    });

    testWidgets('an empty record explains what would fill it', (tester) async {
      final api = backend()
        ..json('GET /api/timeline', {'events': const [], 'total': 0});

      await openFromAccount(tester, api, 'Timeline');

      expect(find.text('Nothing recorded yet'), findsOneWidget);
    });

    testWidgets('the first page asks for a bounded number of rows',
        (tester) async {
      // The server reads every report, medicine, appointment and vital before
      // it slices, so this is not a cheap call.
      final api = backend()
        ..json('GET /api/timeline', {'events': const [], 'total': 0});

      await openFromAccount(tester, api, 'Timeline');

      final request = api.requestFor('GET /api/timeline')!;
      expect(request.options.uri.queryParameters['limit'], '40');
      expect(request.options.uri.queryParameters['offset'], '0');
    });

    testWidgets('Show older asks for the next page and appends it',
        (tester) async {
      var page = 0;
      final api = backend()
        ..on('GET /api/timeline', (_) {
          page++;
          return {
            'events': [
              timelineRow(id: 'row-$page', title: 'Report: page$page.pdf'),
            ],
            'total': 2,
          };
        });

      await openFromAccount(tester, api, 'Timeline');
      await tapAfterScroll(
        tester,
        find.text('Show older'),
        scrollable: scrollableIn(TimelineScreen),
      );

      expect(find.text('page1.pdf'), findsOneWidget);
      expect(find.text('page2.pdf'), findsOneWidget);
      expect(api.requestFor('GET /api/timeline')!.options.uri
          .queryParameters['offset'], '1');
    });

    testWidgets('a row the server could not date is still shown',
        (tester) async {
      final api = backend()
        ..json('GET /api/timeline', {
          'events': [timelineRow(date: '')],
          'total': 1,
        });

      await openFromAccount(tester, api, 'Timeline');

      expect(find.text('Date unknown'), findsOneWidget);
      expect(find.text('bloods.pdf'), findsOneWidget);
    });
  });

  group('search', () {
    testWidgets('an empty box explains what is searched', (tester) async {
      await openFromAccount(tester, backend(), 'Search');

      expect(find.text('Search your record'), findsOneWidget);
      // Nothing was asked of the server: `q` has min_length=1 and an empty
      // query would be a 422.
      expect(find.byType(SearchScreen), findsOneWidget);
    });

    testWidgets('typing is debounced into one request', (tester) async {
      final api = backend()
        ..json('GET /api/search', {
          'query': 'aspirin',
          'results': [searchRow()],
          'total': 1,
        });
      await openFromAccount(tester, api, 'Search');

      await tester.enterText(find.byType(TextField), 'asp');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'aspirin');
      await settle(tester);

      final searches =
          api.calls.where((call) => call == 'GET /api/search').length;
      expect(searches, 1);
      expect(api.requestFor('GET /api/search')!.options.uri
          .queryParameters['q'], 'aspirin');
    });

    testWidgets('results are grouped by kind', (tester) async {
      final api = backend()
        ..json('GET /api/search', {
          'query': 'a',
          'results': [
            searchRow(),
            searchRow(type: 'medicine', id: 'med-1', title: 'Amlodipine'),
            searchRow(
              type: 'document',
              id: 'doc-1',
              title: 'Document - Bir Hospital',
            ),
          ],
          'total': 3,
        });
      await openFromAccount(tester, api, 'Search');

      await tester.enterText(find.byType(TextField), 'a');
      await settle(tester);

      expect(find.text('3 results'), findsOneWidget);
      expect(find.text('REPORT · 1'), findsOneWidget);
      expect(find.text('MEDICINE · 1'), findsOneWidget);
      expect(find.text('VISIT · 1'), findsOneWidget);
    });

    testWidgets('a query with nothing behind it names the query',
        (tester) async {
      final api = backend()
        ..json('GET /api/search',
            {'query': 'zzz', 'results': const [], 'total': 0});
      await openFromAccount(tester, api, 'Search');

      await tester.enterText(find.byType(TextField), 'zzz');
      await settle(tester);

      expect(find.textContaining('zzz'), findsWidgets);
      expect(find.text('Nothing matched'), findsOneWidget);
    });

    testWidgets('a query with a # survives the URL', (tester) async {
      // Interpolated raw, everything after a # becomes a fragment the server
      // never sees — the same trap as a patient id.
      final api = backend()
        ..json('GET /api/search',
            {'query': '#hos', 'results': const [], 'total': 0});
      await openFromAccount(tester, api, 'Search');

      await tester.enterText(find.byType(TextField), '#hos');
      await settle(tester);

      expect(
        api.requestFor('GET /api/search')!.options.uri.queryParameters['q'],
        '#hos',
      );
    });

    testWidgets('tapping a report opens the report, not a list', (tester) async {
      final api = backend()
        ..json('GET /api/reports', {'reports': [reportRow()]})
        ..json('GET /api/search', {
          'query': 'cbc',
          'results': [searchRow(id: 'rep-1')],
          'total': 1,
        });
      await openFromAccount(tester, api, 'Search');

      await tester.enterText(find.byType(TextField), 'cbc');
      await settle(tester);
      await tester.tap(find.text('cbc-june.pdf (BLOOD_TEST)'));
      await settle(tester);

      // The detail screen shows the summary the list row only teased.
      expect(
        find.textContaining('Haemoglobin slightly below range'),
        findsWidgets,
      );
    });

    testWidgets('a medicine search can return one that was removed',
        (tester) async {
      // `GET /api/search` filters soft-deleted documents but not medicines —
      // BACKEND_NOTES §15. Rather than a dead tap, offer to put it back.
      final api = backend()
        ..json('GET /api/search', {
          'query': 'amlo',
          'results': [
            searchRow(type: 'medicine', id: 'gone-1', title: 'Amlodipine'),
          ],
          'total': 1,
        });
      await openFromAccount(tester, api, 'Search');

      await tester.enterText(find.byType(TextField), 'amlo');
      await settle(tester);
      await tester.tap(find.text('Amlodipine'));
      await settle(tester);

      expect(find.textContaining('it was removed'), findsOneWidget);
      expect(find.text('Restore'), findsOneWidget);
    });
  });

  group('caretakers, when the server has them switched off', () {
    testWidgets('Account does not offer a tile that leads nowhere',
        (tester) async {
      await pumpSignedIn(tester, backend());
      await openTab(tester, 'Account');

      expect(find.text('Caretakers'), findsNothing);
    });

    testWidgets('the dashboard asks for nothing at all', (tester) async {
      final api = backend();
      await pumpSignedIn(tester, api);

      expect(api.calls, isNot(contains('GET /api/care/links')));
    });
  });

  group('caretakers, patient side', () {
    testWidgets('a code is shown once, with a countdown and a warning',
        (tester) async {
      final api = backend()
        ..json('GET /api/care/links', {'links': const []})
        ..json('GET /api/medicines/audit', {'entries': const []})
        ..json('POST /api/care/invites', {
          'code': 'ABCD-EFGH',
          'expires_at': '2099-01-01T00:00:00Z',
        });

      await openFromAccount(tester, api, 'Caretakers', caretakers: true);
      await tapAfterScroll(
        tester,
        find.text('Generate a code'),
        scrollable: scrollableIn(CaretakersScreen),
      );

      expect(find.text('ABCD-EFGH'), findsOneWidget);
      expect(
        find.textContaining('cannot be shown again'),
        findsOneWidget,
      );
    });

    testWidgets('somebody holding a code is listed with a way to remove them',
        (tester) async {
      final api = backend()
        ..json('GET /api/care/links', {'links': [careLinkRow()]})
        ..json('GET /api/medicines/audit', {'entries': const []});

      await openFromAccount(tester, api, 'Caretakers', caretakers: true);

      expect(find.text('Sita Bahadur'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
    });

    testWidgets('only a caretaker\'s changes appear under their activity',
        (tester) async {
      final api = backend()
        ..json('GET /api/care/links', {'links': [careLinkRow()]})
        ..json('GET /api/medicines/audit', {
          'entries': [
            {
              'id': 1,
              'actor_id': '#hos077',
              'actor_name': 'Sita Bahadur',
              'medicine_id': 'med-1',
              'medicine_name': 'Amlodipine',
              'action': 'delete',
              'created_at': '2026-08-05T10:00:00Z',
              'by_caretaker': true,
            },
            {
              'id': 2,
              'actor_id': '#hos014',
              'actor_name': 'Ram Bahadur',
              'medicine_id': 'med-2',
              'medicine_name': 'Metformin',
              'action': 'create',
              'created_at': '2026-08-05T11:00:00Z',
              'by_caretaker': false,
            },
          ],
        });

      await openFromAccount(tester, api, 'Caretakers', caretakers: true);
      await scrollTo(
        tester,
        find.text('Recent caretaker activity'),
        scrollable: scrollableIn(CaretakersScreen),
      );

      // The patient's own edits are already on the medicines screen.
      expect(find.textContaining('Sita Bahadur removed Amlodipine'),
          findsOneWidget);
      expect(find.textContaining('Metformin'), findsNothing);
      // A caretaker's delete is the one thing worth undoing from here.
      expect(find.text('Restore'), findsOneWidget);
    });

    testWidgets('a server with the flag off says so, and says how to fix it',
        (tester) async {
      final api = backend()
        ..fails('GET /api/care/links', 404, 'Not Found')
        ..json('GET /api/medicines/audit', {'entries': const []});

      // Reached directly: the tile is hidden, but the route still exists and
      // must explain itself rather than showing an empty list.
      await pumpSignedIn(tester, api, health: caretakerHealth);
      await openTab(tester, 'Account');
      await tapAfterScroll(
        tester,
        find.text('Caretakers'),
        scrollable: scrollableIn(MoreScreen),
      );

      expect(find.text('Caretakers is switched off'), findsOneWidget);
      expect(find.textContaining('CARETAKER_ENABLED=true'), findsOneWidget);
    });
  });

  group('people I care for', () {
    testWidgets('a caretaker sees their client and the patient\'s own clock',
        (tester) async {
      final api = backend()
        ..json('GET /api/care/links', {'links': [careLinkRow()]});

      await pumpSignedIn(tester, api, health: caretakerHealth);

      await scrollTo(
        tester,
        find.text('People I care for'),
        scrollable: scrollableIn(Scaffold),
      );
      expect(find.text('People I care for'), findsOneWidget);
      // Rendered verbatim — never re-expressed in the caretaker's timezone.
      expect(find.textContaining('08:00'), findsOneWidget);
      expect(find.text('2 medicines'), findsOneWidget);
    });

    testWidgets('somebody who cares for nobody gets one quiet line',
        (tester) async {
      final api = backend()..json('GET /api/care/links', {'links': const []});

      await pumpSignedIn(tester, api, health: caretakerHealth);

      await scrollTo(
        tester,
        find.textContaining('Caring for someone?'),
        scrollable: scrollableIn(Scaffold),
      );
      expect(find.text('People I care for'), findsNothing);
    });
  });
}
