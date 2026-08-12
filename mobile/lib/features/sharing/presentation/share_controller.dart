/// Share links as state.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../data/share_repository.dart';
import '../domain/share_link.dart';

final shareLinksProvider =
    AsyncNotifierProvider<ShareLinksController, List<ShareLink>>(
  ShareLinksController.new,
);

class ShareLinksController extends AsyncNotifier<List<ShareLink>> {
  ShareRepository get _repository => ref.read(shareRepositoryProvider);

  @override
  Future<List<ShareLink>> build() async {
    if (ref.watch(currentUserProvider) == null) return const [];
    return _repository.list();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repository.list);
  }

  Future<ShareLink> shareReport(
    String reportId, {
    ShareWindow window = ShareWindow.day,
  }) async {
    final grant = await _repository.shareReport(reportId, window: window);
    return _remember(grant.asLink(reportId: reportId));
  }

  Future<ShareLink> shareEverything({
    ShareWindow window = ShareWindow.day,
  }) async {
    final grant = await _repository.shareEverything(window: window);
    return _remember(grant.asLink(reportId: ShareLink.wholeRecord));
  }

  ShareLink _remember(ShareLink link) {
    state = AsyncData([link, ...state.valueOrNull ?? const []]);
    return link;
  }

  Future<void> revoke(String token) async {
    await _repository.revoke(token);
    state = AsyncData([
      for (final link in state.valueOrNull ?? const <ShareLink>[])
        if (link.token != token) link,
    ]);
  }
}

/// Live links, soonest to expire first, and the expired ones behind them.
///
/// `GET /api/share` hands back both with nothing to tell them apart. Sorting a
/// link that stopped working yesterday in among the ones that still do is how
/// somebody hands out a dead URL and does not find out until the person on the
/// other end says so.
typedef SplitShareLinks = ({List<ShareLink> live, List<ShareLink> expired});

SplitShareLinks splitShareLinks(List<ShareLink> all, {DateTime? now}) {
  final at = now ?? DateTime.now();
  final live = <ShareLink>[];
  final expired = <ShareLink>[];
  for (final link in all) {
    (link.hasExpired(now: at) ? expired : live).add(link);
  }
  live.sort(_byExpiry);
  // Most recently dead first — the one just missed is the one being looked for.
  expired.sort((a, b) => _byExpiry(b, a));
  return (live: live, expired: expired);
}

int _byExpiry(ShareLink a, ShareLink b) {
  final left = a.expires;
  final right = b.expires;
  if (left == null || right == null) return 0;
  return left.compareTo(right);
}
