/// Every `/api/share*` call this app makes.
///
/// Only the owner's half is here. The five public reader routes
/// (`GET /{token}`, `/qr-code/{token}`, `/{token}/ai-report`,
/// `/{token}/lab-analysis`, `/{token}/explain`) belong to `front/` and are
/// deliberately not implemented: a share link exists so that someone *without*
/// this app can read it.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/network_providers.dart';
import '../domain/share_link.dart';
import '../domain/shared_record.dart';

final shareRepositoryProvider = Provider<ShareRepository>(
  (ref) => ShareRepository(ref.watch(apiClientProvider)),
);

class ShareRepository {
  const ShareRepository(this._client);

  final ApiClient _client;

  static const _base = '/api/share';

  /// `GET /api/share` — every link I own, **expired ones included**. The server
  /// does no filtering, so the screen sorts the live from the dead.
  Future<List<ShareLink>> list() async {
    final json = await _client.get<Map<String, dynamic>>(_base);
    final rows = json['links'] as List<dynamic>? ?? const [];
    return [
      for (final row in rows) ShareLink.fromJson(row as Map<String, dynamic>),
    ];
  }

  /// `POST /api/share/{report_id}?expires_hours=` — one report.
  Future<ShareGrant> shareReport(
    String reportId, {
    ShareWindow window = ShareWindow.day,
  }) async {
    final json = await _client.post<Map<String, dynamic>>(
      '$_base/$reportId?expires_hours=${window.hours}',
    );
    return ShareGrant.fromJson(json);
  }

  /// `POST /api/share/qr-code?expires_hours=` — the whole record: every report,
  /// every medicine, and the emergency profile behind one link.
  ///
  /// 400 "Nothing to share" when the account holds none of those. That is a
  /// real answer, not a failure, and the screen says so in its own words.
  Future<ShareGrant> shareEverything({
    ShareWindow window = ShareWindow.day,
  }) async {
    final json = await _client.post<Map<String, dynamic>>(
      '$_base/qr-code?expires_hours=${window.hours}',
    );
    return ShareGrant.fromJson(json);
  }

  /// `DELETE /api/share/{token}` — revoke. Immediate: the next reader gets a
  /// 404 rather than a cached page.
  Future<void> revoke(String token) => _client.delete<void>('$_base/$token');

  /// `GET /api/share/qr-code/{token}` — read a shared whole record. **No auth:**
  /// the token is the credential, exactly as the web reader treats it.
  Future<SharedRecord> fetchSharedRecord(String token) async {
    final json = await _client.get<Map<String, dynamic>>(
      '$_base/qr-code/$token',
      options: unauthenticated,
    );
    return SharedRecord.fromJson(json);
  }

  /// `GET /api/share/{token}` — read one shared report. **No auth.**
  Future<SharedReportPage> fetchSharedReport(String token) async {
    final json = await _client.get<Map<String, dynamic>>(
      '$_base/$token',
      options: unauthenticated,
    );
    return SharedReportPage.fromJson(json);
  }
}
