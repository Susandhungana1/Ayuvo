/// Share links: expiry, the whole-record sentinel, and the URL a stranger
/// opens.
///
/// `GET /api/share` returns dead links alongside live ones and says nothing
/// about which is which, so every judgement here is the client's — and getting
/// it wrong in the optimistic direction means handing somebody a URL that
/// already stopped working.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:medistore/core/config/env.dart';
import 'package:medistore/features/sharing/domain/share_link.dart';
import 'package:medistore/features/sharing/presentation/share_controller.dart';

ShareLink _link({
  String token = 'tok-1',
  String reportId = 'rep-1',
  String expiresAt = '2030-08-08T09:14:22',
}) =>
    ShareLink(token: token, reportId: reportId, expiresAt: expiresAt);

void main() {
  group('expiry', () {
    test('expires_at is naive UTC and is read as UTC', () {
      // 09:14 UTC, not 09:14 wherever the device is.
      final at = _link(expiresAt: '2030-08-08T09:14:22').expires!;
      expect(at.toUtc(), DateTime.utc(2030, 8, 8, 9, 14, 22));
    });

    test('a past expiry is expired', () {
      final link = _link(expiresAt: '2020-01-01T00:00:00');
      expect(link.hasExpired(now: DateTime(2026, 8, 7)), isTrue);
    });

    test('the exact moment of expiry counts as expired', () {
      final link = _link(expiresAt: '2030-08-08T09:14:22');
      expect(link.hasExpired(now: link.expires), isTrue);
    });

    test('an unreadable expiry is treated as expired, never as live', () {
      expect(_link(expiresAt: 'whenever').hasExpired(), isTrue);
    });
  });

  group('what the link opens', () {
    test('the sentinel means the whole record, and takes the qr-code path', () {
      final link = _link(reportId: ShareLink.wholeRecord);
      expect(link.isWholeRecord, isTrue);
      expect(link.url, '${Env.webBaseUrl}/share/qr-code/tok-1');
    });

    test('a report id takes the single-report path', () {
      expect(_link().url, '${Env.webBaseUrl}/share/tok-1');
      expect(_link().isWholeRecord, isFalse);
    });

    test('the URL points at the web app, not at this app', () {
      expect(_link().url, startsWith('http'));
      expect(_link().url, isNot(contains('127.0.0.1:3001')));
    });
  });

  test('a create response becomes a list row without another fetch', () {
    const grant = ShareGrant(token: 'new', expiresAt: '2030-08-09T00:00:00');
    final link = grant.asLink(reportId: 'rep-2');
    expect(link.token, 'new');
    expect(link.reportId, 'rep-2');
    expect(link.expires, isNotNull);
  });

  group('splitShareLinks', () {
    final now = DateTime(2026, 8, 7, 12);

    test('live sorts by what expires soonest', () {
      final split = splitShareLinks(
        [
          _link(token: 'later', expiresAt: '2026-08-09T12:00:00'),
          _link(token: 'sooner', expiresAt: '2026-08-08T12:00:00'),
        ],
        now: now,
      );
      expect(split.live.map((l) => l.token), ['sooner', 'later']);
      expect(split.expired, isEmpty);
    });

    test('expired sorts by what died most recently', () {
      final split = splitShareLinks(
        [
          _link(token: 'ancient', expiresAt: '2026-01-01T12:00:00'),
          _link(token: 'yesterday', expiresAt: '2026-08-06T12:00:00'),
        ],
        now: now,
      );
      expect(split.live, isEmpty);
      expect(split.expired.map((l) => l.token), ['yesterday', 'ancient']);
    });

    test('a mixed list separates rather than interleaving', () {
      final split = splitShareLinks(
        [
          _link(token: 'dead', expiresAt: '2026-08-06T12:00:00'),
          _link(token: 'alive', expiresAt: '2026-08-08T12:00:00'),
        ],
        now: now,
      );
      expect(split.live.single.token, 'alive');
      expect(split.expired.single.token, 'dead');
    });
  });

  test('a share window carries the hours the API wants', () {
    expect(ShareWindow.hour.hours, 1);
    expect(ShareWindow.day.hours, 24);
    expect(ShareWindow.week.hours, 168);
  });
}
