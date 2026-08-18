/// `/api/share` in Dart — a link that lets someone without an account read
/// part of your record, until it expires.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/config/env.dart';
import '../../../core/time/medi_time.dart';

part 'share_link.freezed.dart';
part 'share_link.g.dart';

@freezed
abstract class ShareLink with _$ShareLink {
  const factory ShareLink({
    /// The secret. 32 random bytes, URL-safe — it *is* the credential, so it is
    /// never logged and never put in an error message.
    required String token,

    /// The report this opens, or the sentinel [wholeRecord].
    @JsonKey(name: 'report_id') required String reportId,

    /// Naive UTC, like every other server timestamp. `"2026-08-07T09:14:22"`.
    @JsonKey(name: 'expires_at') required String expiresAt,

    /// The 6-digit PIN of a whole-record link, if one exists. Only the create
    /// response carries it — the server stores a hash, not the value, so a link
    /// fetched from the list later never has one.
    String? pin,
  }) = _ShareLink;

  const ShareLink._();

  factory ShareLink.fromJson(Map<String, dynamic> json) =>
      _$ShareLinkFromJson(json);

  /// What `GET /api/share` puts in `report_id` for a whole-record link, where
  /// the column is actually null.
  static const wholeRecord = '__ALL_REPORTS__';

  bool get isWholeRecord => reportId == wholeRecord;

  DateTime? get expires => MediTime.parseUtc(expiresAt);

  /// `GET /api/share` returns expired rows alongside live ones and says nothing
  /// about which is which — the web app listed them all as live until this was
  /// fixed (`FEATURE_MAP.md` §7.5). A link whose expiry cannot be parsed is
  /// treated as expired: claiming a share is live is the dangerous direction of
  /// that guess.
  bool hasExpired({DateTime? now}) {
    final at = expires;
    if (at == null) return true;
    return !at.isAfter(now ?? DateTime.now());
  }

  /// The URL a recipient opens. The public reader is a `front/` page, not a
  /// screen in this app: whoever you share with does not have MediStore
  /// installed, which is the entire point of sharing.
  String get url => isWholeRecord
      ? '${Env.webBaseUrl}/share/qr-code/$token'
      : '${Env.webBaseUrl}/share/$token';
}

/// `POST /api/share/{report_id}` and `POST /api/share/qr-code` both answer with
/// this, and neither echoes back which report it was for.
@freezed
abstract class ShareGrant with _$ShareGrant {
  const factory ShareGrant({
    required String token,
    @JsonKey(name: 'expires_at') required String expiresAt,

    /// Whole-record creates answer with the PIN that guards the link.
    String? pin,
  }) = _ShareGrant;

  const ShareGrant._();

  factory ShareGrant.fromJson(Map<String, dynamic> json) =>
      _$ShareGrantFromJson(json);

  /// Turns the create response into the list row it will become, so a new link
  /// appears with the same shape as the ones that came from the server.
  ShareLink asLink({required String reportId}) => ShareLink(
        token: token,
        reportId: reportId,
        expiresAt: expiresAt,
        pin: pin,
      );
}

/// How long a new link should live. The API takes `?expires_hours=` and
/// defaults to 24; the web app never offered a choice, so every link it made
/// lasted exactly a day whether that was a consultation or a second opinion.
enum ShareWindow {
  hour(1, 'For an hour'),
  day(24, 'For a day'),
  week(168, 'For a week');

  const ShareWindow(this.hours, this.label);

  final int hours;
  final String label;
}
