/// Care links as state, plus the one piece of state that must never touch a
/// disk: the invite code.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/health/health_providers.dart';
import '../../../core/session/session_controller.dart';
import '../../medicines/data/medicine_repository.dart';
import '../../medicines/domain/medicine.dart';
import '../data/care_repository.dart';
import '../domain/care_link.dart';

/// `GET /api/care/links?role=`. Keyed by role, because the two answers are
/// different lists with different fields and sharing a cache entry between
/// them would be a bug waiting to happen.
final careLinksProvider =
    AsyncNotifierProvider.family<CareLinksController, List<CareLink>, CareRole>(
  CareLinksController.new,
);

class CareLinksController extends FamilyAsyncNotifier<List<CareLink>, CareRole> {
  CareRepository get _repository => ref.read(careRepositoryProvider);

  @override
  Future<List<CareLink>> build(CareRole role) async {
    if (ref.watch(currentUserProvider) == null) return const [];
    // The flag is checked before the call rather than after the 404, so a
    // server with caretakers off costs no request at all.
    if (!ref.watch(caretakerEnabledProvider)) throw CareFailure.featureOff;
    return _repository.links(role);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _repository.links(arg));
  }

  Future<CareLink> redeem(String code) async {
    final link = await _repository.redeem(code);
    state = AsyncData([link, ...state.valueOrNull ?? const []]);
    return link;
  }

  Future<void> revoke(String linkId) async {
    await _repository.revoke(linkId);
    state = AsyncData([
      for (final link in state.valueOrNull ?? const <CareLink>[])
        if (link.id != linkId) link,
    ]);
  }

  /// Optimistic: a bell icon should flip on the frame it is tapped. A failure
  /// puts it back by reloading rather than by guessing what the server did.
  Future<void> setNotify(String linkId, bool notify) async {
    final before = state.valueOrNull ?? const <CareLink>[];
    state = AsyncData([
      for (final link in before)
        if (link.id == linkId) link.copyWith(notify: notify) else link,
    ]);
    try {
      final updated = await _repository.setNotify(linkId, notify);
      state = AsyncData([
        for (final link in state.valueOrNull ?? const <CareLink>[])
          if (link.id == linkId) updated else link,
      ]);
    } catch (error) {
      debugPrint('Could not change notify: $error');
      state = AsyncData(before);
      rethrow;
    }
  }
}

/// The link for one patient a caretaker is acting for, or null.
///
/// This is the app's own check that the caretaker still has access; the
/// authoritative one is `resolve_medicine_scope`, which 403s. Both matter: this
/// one names the patient on screen, that one decides what is allowed.
final careLinkForProvider =
    Provider.family<AsyncValue<CareLink?>, String>((ref, patientId) {
  return ref.watch(careLinksProvider(CareRole.caretaker)).whenData((links) {
    for (final link in links) {
      if (link.userId == patientId) return link;
    }
    return null;
  });
});

/// `GET /api/medicines/audit`, filtered to changes a caretaker made.
///
/// The patient's own edits are already visible on their medicines screen; this
/// list answers "what has somebody else done to my list", which is the only
/// question this screen exists for.
final caretakerAuditProvider =
    FutureProvider<List<MedicineAuditEntry>>((ref) async {
  if (ref.watch(currentUserProvider) == null) return const [];
  if (!ref.watch(caretakerEnabledProvider)) return const [];
  // Deliberately unscoped: this is the caller's own audit trail.
  final entries = await ref.watch(medicineRepositoryProvider).audit();
  return [for (final entry in entries) if (entry.byCaretaker) entry];
});

/// The issued invite code, for as long as the app is open.
///
/// **In memory only, and deliberately.** The server keeps a SHA-256 hash, so
/// there is nothing to fetch this back from — it exists here or nowhere. The
/// web app keeps it in `sessionStorage`; this keeps it in a provider, which is
/// the same lifetime without a disk. Not secure storage either: a 15-minute
/// code does not belong in the keystore beside a bearer token.
final issuedInviteProvider =
    NotifierProvider<IssuedInvite, IssuedInviteState>(IssuedInvite.new);

@immutable
class IssuedInviteState {
  const IssuedInviteState({this.invite, this.linkCountAtIssue = 0, this.issuing = false});

  final CareInvite? invite;

  /// How many caretakers existed when the code was made. One more than this
  /// means somebody has redeemed it, and showing it again would invite the
  /// patient to read out a code that no longer works.
  final int linkCountAtIssue;

  final bool issuing;
}

class IssuedInvite extends Notifier<IssuedInviteState> {
  @override
  IssuedInviteState build() => const IssuedInviteState();

  Future<void> issue(int currentLinkCount) async {
    state = IssuedInviteState(issuing: true);
    try {
      final invite = await ref.read(careRepositoryProvider).createInvite();
      state = IssuedInviteState(
        invite: invite,
        linkCountAtIssue: currentLinkCount,
      );
    } catch (_) {
      state = const IssuedInviteState();
      rethrow;
    }
  }

  void forget() => state = const IssuedInviteState();

  /// Drops the code once it has expired or been redeemed. Called from the
  /// screen's ticker rather than on a timer here, so nothing keeps running when
  /// the screen is not open.
  void expireIfSpent({required DateTime now, required int linkCount}) {
    final invite = state.invite;
    if (invite == null) return;
    if (invite.isDead(now) || linkCount > state.linkCountAtIssue) forget();
  }
}
