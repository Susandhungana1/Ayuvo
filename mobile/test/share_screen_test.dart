/// Sharing, driven through the real app.
///
/// Two things are worth this much setup: that a live link and a dead one are
/// never shown as the same thing, and that the URL handed to a recipient
/// points at the web app rather than at an API route no browser can render.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ayuvo/core/config/env.dart';
import 'package:ayuvo/features/sharing/domain/share_link.dart';
import 'package:ayuvo/features/sharing/presentation/share_screen.dart';
import 'package:ayuvo/features/shell/presentation/more_screen.dart';

import 'support/fake_api.dart';
import 'support/harness.dart';

FakeApi backend({
  List<Map<String, Object?>> links = const [],
  List<Map<String, Object?>> reports = const [],
}) =>
    FakeApi()
      ..json('GET /api/medicines', {'medicines': const []})
      ..json('GET /api/vitals', {'vitals': const []})
      ..json('GET /api/reports', {'reports': reports})
      ..json('GET /api/share', {'links': links});

Future<void> openSharing(WidgetTester tester, FakeApi api) async {
  await pumpSignedIn(tester, api);
  await openTab(tester, 'Account');
  // Account grew a second group of tiles in phase 6, so Sharing is below the
  // fold on a small viewport.
  await tapAfterScroll(
    tester,
    find.text('Sharing'),
    scrollable: scrollableIn(MoreScreen),
  );
}

const _live = '2030-08-08T09:14:22';
const _dead = '2020-01-01T00:00:00';

void main() {
  testWidgets('the whole-record card names what a stranger would see',
      (tester) async {
    await openSharing(tester, backend());

    // Not "share your record" — the blood type and the next-of-kin number go
    // with it, and that is the part somebody would not expect.
    expect(
      find.textContaining('every report, every medicine, and your emergency '
          'details'),
      findsOneWidget,
    );
    expect(find.text('Nothing is shared right now.'), findsOneWidget);
  });

  testWidgets('with no reports uploaded, the per-report section says so',
      (tester) async {
    await openSharing(tester, backend());

    expect(find.text('You have not uploaded a report yet.'), findsOneWidget);
  });

  testWidgets('a live link and an expired one are never shown alike',
      (tester) async {
    await openSharing(
      tester,
      backend(links: [
        shareLinkRow(token: 'alive', expiresAt: _live),
        shareLinkRow(token: 'dead', expiresAt: _dead),
      ]),
    );

    expect(find.text('Live'), findsOneWidget);
    expect(find.text('Expired'), findsNWidgets(2)); // the chip and the heading
    expect(find.widgetWithText(TextButton, 'Revoke'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Remove'), findsOneWidget);
  });

  testWidgets('an expired link is not offered a Show button', (tester) async {
    await openSharing(
      tester,
      backend(links: [shareLinkRow(token: 'dead', expiresAt: _dead)]),
    );

    expect(find.widgetWithText(TextButton, 'Show'), findsNothing);
  });

  testWidgets('the whole-record sentinel is labelled, not printed',
      (tester) async {
    await openSharing(
      tester,
      backend(links: [
        shareLinkRow(reportId: ShareLink.wholeRecord, expiresAt: _live),
      ]),
    );

    expect(find.text('Whole record'), findsOneWidget);
    expect(find.textContaining('__ALL_REPORTS__'), findsNothing);
  });

  testWidgets('creating a whole-record link sends the chosen window, shows '
      'the URL, and surfaces the PIN the reader will ask for', (tester) async {
    final api = backend()
      ..json('POST /api/share/qr-code',
          {'token': 'tok-new', 'expires_at': _live, 'pin': '123456'});
    await openSharing(tester, api);

    await tester.tap(find.widgetWithText(ChoiceChip, 'For a week'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Create a link'));
    await settle(tester);

    final request = api.requestFor('POST /api/share/qr-code')!;
    expect(request.options.uri.queryParameters['expires_hours'], '168');

    // The sheet shows the whole URL, and it is a web page — not an API route.
    expect(
      find.text('${Env.webBaseUrl}/share/qr-code/tok-new'),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Copy link'), findsOneWidget);

    // A whole-record link is PIN-guarded: the owner must see the PIN at the
    // one moment it exists (the server stores a hash, never the value).
    expect(find.text('6-digit PIN: 123456'), findsOneWidget);
    expect(find.textContaining('do not print it beside the QR'), findsOneWidget);
    expect(api.unmatched, isEmpty);
  });

  testWidgets('"Nothing to share" is answered in the app\'s own words, not as '
      'a failure', (tester) async {
    final api = backend()
      ..fails('POST /api/share/qr-code', 400, 'Nothing to share');
    await openSharing(tester, api);

    await tester.tap(find.widgetWithText(FilledButton, 'Create a link'));
    await settle(tester);

    expect(find.text('Nothing to share'), findsOneWidget);
  });

  testWidgets('sharing one report defaults to a day and lists the new link',
      (tester) async {
    final api = backend(reports: [reportRow()])
      ..json('POST /api/share/rep-1', {'token': 'tok-1', 'expires_at': _live});
    await openSharing(tester, api);

    expect(find.text('cbc-june.pdf'), findsOneWidget);

    await tapAfterScroll(
      tester,
      find.byTooltip('Share this report'),
      scrollable: scrollableIn(ShareScreen),
    );

    final request = api.requestFor('POST /api/share/rep-1')!;
    expect(request.options.uri.queryParameters['expires_hours'], '24');
    expect(find.text('${Env.webBaseUrl}/share/tok-1'), findsOneWidget);
  });

  testWidgets('revoking says what it does to whoever is holding the link',
      (tester) async {
    final api = backend(links: [shareLinkRow(token: 'tok-1', expiresAt: _live)])
      ..json('DELETE /api/share/tok-1', null);
    await openSharing(tester, api);

    await tapAfterScroll(
      tester,
      find.widgetWithText(TextButton, 'Revoke'),
      scrollable: scrollableIn(ShareScreen),
    );

    expect(
      find.textContaining('Anyone holding it stops being able to read '
          'anything'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Revoke'));
    await settle(tester);

    expect(api.requestFor('DELETE /api/share/tok-1'), isNotNull);
    expect(find.text('Link revoked'), findsOneWidget);
    expect(find.text('Nothing is shared right now.'), findsOneWidget);
  });
}
