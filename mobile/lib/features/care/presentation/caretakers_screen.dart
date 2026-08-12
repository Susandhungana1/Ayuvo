/// The patient's side: hand somebody a code, see who holds one, and see what
/// they have changed.
///
/// The screen exists because giving another person write access to your
/// medicines is a serious thing to do, and it should be as easy to undo and to
/// audit as it is to grant.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/time/medi_time.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/states.dart';
import '../../medicines/domain/medicine.dart';
import '../../medicines/presentation/medicines_controller.dart';
import '../data/care_repository.dart';
import '../domain/care_link.dart';
import 'care_controllers.dart';

class CaretakersScreen extends ConsumerWidget {
  const CaretakersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(careLinksProvider(CareRole.patient));

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.caretakersTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(careLinksProvider(CareRole.patient).notifier).refresh();
          ref.invalidate(caretakerAuditProvider);
        },
        child: switch (links) {
          AsyncData(:final value) => _Caretakers(links: value),
          // The one failure with an actionable cause: the flag is off. Saying
          // "not available on your account" would be wrong — it is not about
          // the account at all.
          AsyncError(error: final CareFailure failure) =>
            _Blocked(failure: failure),
          AsyncError(:final error) => ListView(
              padding: AppSpacing.screen,
              children: [
                ErrorView(
                  error: error,
                  onRetry: () => ref
                      .read(careLinksProvider(CareRole.patient).notifier)
                      .refresh(),
                ),
              ],
            ),
          _ => const _Loading(),
        },
      ),
    );
  }
}

class _Caretakers extends ConsumerWidget {
  const _Caretakers({required this.links});

  final List<CareLink> links;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        Text(
          context.l10n.caretakersBlurb,
          style: context.texts.bodyMedium
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xl),
        _IssueCode(linkCount: links.length),
        const SizedBox(height: AppSpacing.xl),
        Text(context.l10n.caretakersYours, style: context.texts.titleLarge),
        const SizedBox(height: AppSpacing.md),
        if (links.isEmpty)
          Card(
            child: Padding(
              padding: AppSpacing.card,
              child: Text(
                context.l10n.caretakersNone,
                style: context.texts.bodyMedium
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ),
          )
        else
          for (final link in links)
            Padding(
              key: ValueKey(link.id),
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _CaretakerRow(link: link),
            ),
        const SizedBox(height: AppSpacing.xl),
        Text(context.l10n.caretakersActivity, style: context.texts.titleLarge),
        const SizedBox(height: AppSpacing.md),
        const _Activity(),
      ],
    );
  }
}

/// Generate, show, count down, forget.
///
/// The countdown is not decoration: the code dies after 15 minutes and the
/// patient is usually reading it out loud to somebody. Knowing there are 40
/// seconds left is the difference between "say it again" and "make a new one".
class _IssueCode extends ConsumerStatefulWidget {
  const _IssueCode({required this.linkCount});

  final int linkCount;

  @override
  ConsumerState<_IssueCode> createState() => _IssueCodeState();
}

class _IssueCodeState extends ConsumerState<_IssueCode> {
  Timer? _ticker;
  Object? _error;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Runs only while a code is on screen — a timer ticking behind a screen
  /// nobody is looking at is a battery bug waiting to be filed.
  void _startTicking() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      ref.read(issuedInviteProvider.notifier).expireIfSpent(
            now: DateTime.now(),
            linkCount: widget.linkCount,
          );
      setState(() {});
    });
  }

  Future<void> _issue() async {
    setState(() => _error = null);
    try {
      await ref.read(issuedInviteProvider.notifier).issue(widget.linkCount);
      _startTicking();
    } catch (error) {
      setState(() => _error = error is CareFailure ? error.message : error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(issuedInviteProvider);
    final invite = state.invite;
    if (invite == null) _ticker?.cancel();

    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.caretakersAddTitle,
                style: context.texts.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.l10n.caretakersAddBlurb,
              style: context.texts.bodyMedium
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_error != null) ...[
              MessageBanner(message: _error is String ? '$_error' : ErrorText.of(_error!)),
              const SizedBox(height: AppSpacing.md),
            ],
            if (invite == null)
              FilledButton(
                onPressed: state.issuing ? null : _issue,
                child: Text(
                  state.issuing
                      ? context.l10n.caretakersGenerating
                      : context.l10n.caretakersGenerate,
                ),
              )
            else
              _LiveCode(invite: invite),
          ],
        ),
      ),
    );
  }
}

class _LiveCode extends ConsumerWidget {
  const _LiveCode({required this.invite});

  final CareInvite invite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final left = invite.remaining(DateTime.now());
    final dead = left == Duration.zero;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          decoration: BoxDecoration(
            color: context.colors.primaryContainer,
            borderRadius: AppRadius.md,
          ),
          child: Center(
            child: SelectableText(
              invite.code,
              style: context.numerals.numericLarge.copyWith(
                letterSpacing: 6,
                color: context.colors.onPrimaryContainer,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Wrap, not Row: three controls and a countdown do not fit on one line
        // at large text sizes, and none of them is droppable.
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: invite.code));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.copied)),
                  );
                }
              },
              icon: const Icon(Icons.copy, size: 18),
              label: Text(context.l10n.copy),
            ),
            TextButton(
              onPressed: () => ref.read(issuedInviteProvider.notifier).forget(),
              child: Text(context.l10n.caretakersHide),
            ),
            Text(
              dead
                  ? context.l10n.caretakersExpired
                  : context.l10n.caretakersExpiresIn(_mmss(left)),
              // Tabular figures, so a countdown does not jitter as its digits
              // change width.
              style: context.numerals.numericMedium.copyWith(
                color: dead ? context.status.alert : context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          context.l10n.caretakersCodeWarning,
          style: context.texts.bodySmall?.copyWith(color: context.status.caution),
        ),
      ],
    );
  }

  static String _mmss(Duration left) {
    final minutes = left.inMinutes;
    final seconds = left.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _CaretakerRow extends ConsumerWidget {
  const _CaretakerRow({required this.link});

  final CareLink link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final added = link.created;

    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(link.name, style: context.texts.titleMedium),
                  if (added != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      context.l10n.caretakersAdded(MediTime.date(added)),
                      style: context.texts.bodySmall
                          ?.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              onPressed: () => _confirmRemove(context, ref),
              child: Text(
                context.l10n.remove,
                style: TextStyle(color: context.colors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.caretakersRemoveTitle(link.name)),
        content: Text(l10n.caretakersRemoveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.remove),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(careLinksProvider(CareRole.patient).notifier)
          .revoke(link.id);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error is CareFailure ? error.message : ErrorText.of(error)),
        ),
      );
    }
  }
}

/// What a caretaker has done, and the one thing worth being able to undo.
class _Activity extends ConsumerWidget {
  const _Activity();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audit = ref.watch(caretakerAuditProvider);

    return switch (audit) {
      AsyncData(:final value) when value.isEmpty => Card(
          child: Padding(
            padding: AppSpacing.card,
            child: Text(
              context.l10n.caretakersActivityNone,
              style: context.texts.bodyMedium
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ),
        ),
      AsyncData(:final value) => Card(
          child: Column(
            children: [
              for (final entry in value)
                _AuditRow(key: ValueKey(entry.id), entry: entry),
            ],
          ),
        ),
      // Quiet on failure: the audit trail is context, and a red card under
      // "Recent caretaker activity" reads as though a caretaker did something
      // alarming.
      _ => const SizedBox.shrink(),
    };
  }
}

class _AuditRow extends ConsumerWidget {
  const _AuditRow({super.key, required this.entry});

  final MedicineAuditEntry entry;

  static const _verbs = {
    'create': 'added',
    'update': 'updated',
    'delete': 'removed',
    'restore': 'restored',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final when = entry.created;
    final verb = _verbs[entry.action] ?? entry.action;

    return ListTile(
      title: Text(
        '${entry.actorName} $verb ${entry.medicineName ?? 'a medicine'}',
      ),
      subtitle: when == null ? null : Text(MediTime.dateTime(when)),
      // Only a delete is undoable, and only by the patient — which is exactly
      // who is reading this screen.
      trailing: entry.action == 'delete' && entry.medicineId != null
          ? TextButton(
              onPressed: () => _restore(context, ref),
              child: Text(context.l10n.caretakersRestore),
            )
          : null,
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final restored = await ref
          .read(medicinesProvider(null).notifier)
          .undoRemove(entry.medicineId!);
      ref.invalidate(caretakerAuditProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('${restored.name} is back on your list')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorText.of(error))));
    }
  }
}

class _Blocked extends StatelessWidget {
  const _Blocked({required this.failure});

  final CareFailure failure;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
        EmptyState(
          icon: Icons.toggle_off_outlined,
          title: context.l10n.caretakersOffTitle,
          message: context.l10n.caretakersOffBody,
        ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.screen,
      children: const [
        SkeletonCard(lines: 3),
        SizedBox(height: AppSpacing.md),
        SkeletonCard(lines: 2),
      ],
    );
  }
}
