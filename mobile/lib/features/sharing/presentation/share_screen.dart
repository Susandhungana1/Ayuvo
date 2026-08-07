/// Links that let a doctor read part of your record without an account.
///
/// Everything here is written from the recipient's side, because that is where
/// the consequences are: what they will see, and for how long. A link is a
/// credential — anyone holding it is in, no sign-in — so the screen never hides
/// a live link behind a summary, and revoking one is always one tap away.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/time/medi_time.dart';
import '../../../core/widgets/card_header.dart';
import '../../../core/widgets/link_card.dart';
import '../../../core/widgets/range_bar.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/states.dart';
import '../../reports/domain/report.dart';
import '../../reports/presentation/reports_controller.dart';
import '../domain/share_link.dart';
import 'share_controller.dart';

class ShareScreen extends ConsumerWidget {
  const ShareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(shareLinksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sharing')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(reportsProvider);
          await ref.read(shareLinksProvider.notifier).refresh();
        },
        child: ListView(
          padding: AppSpacing.screen,
          children: [
            const _WholeRecordCard(),
            const SizedBox(height: AppSpacing.xl),
            Text('One report at a time', style: context.texts.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'A link to a single result, for a second opinion.',
              style: context.texts.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            const _ReportPicker(),
            const SizedBox(height: AppSpacing.xl),
            Text('Links you have made', style: context.texts.titleMedium),
            const SizedBox(height: AppSpacing.md),
            switch (links) {
              AsyncData(:final value) when value.isEmpty => Text(
                  'Nothing is shared right now.',
                  style: context.texts.bodyMedium
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              AsyncData(:final value) => _Links(split: splitShareLinks(value)),
              AsyncError(:final error) => ErrorView(
                  error: error,
                  onRetry: () =>
                      ref.read(shareLinksProvider.notifier).refresh(),
                ),
              _ => const SkeletonCard(lines: 2),
            },
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _WholeRecordCard extends ConsumerStatefulWidget {
  const _WholeRecordCard();

  @override
  ConsumerState<_WholeRecordCard> createState() => _WholeRecordCardState();
}

class _WholeRecordCardState extends ConsumerState<_WholeRecordCard> {
  ShareWindow _window = ShareWindow.day;
  bool _busy = false;

  Future<void> _create() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final link = await ref
          .read(shareLinksProvider.notifier)
          .shareEverything(window: _window);
      if (mounted) await showLinkSheet(context, link: link);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorText.of(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your whole record', style: context.texts.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            // Naming the contents is the point of this paragraph. "Share your
            // record" hides that a stranger will also see the blood type and
            // the next-of-kin phone number.
            Text(
              'One link showing every report, every medicine, and your '
              'emergency details — blood type, allergies, conditions and your '
              'contacts. Anyone with the link can read it, with no sign-in.',
              style: context.texts.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            _WindowChips(
              value: _window,
              onChanged: (window) => setState(() => _window = window),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _create,
                icon: const Icon(Icons.qr_code_2, size: 18),
                label: Text(_busy ? 'Creating…' : 'Create a link'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowChips extends StatelessWidget {
  const _WindowChips({required this.value, required this.onChanged});

  final ShareWindow value;
  final ValueChanged<ShareWindow> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (final window in ShareWindow.values)
          ChoiceChip(
            label: Text(window.label),
            selected: window == value,
            onSelected: (_) => onChanged(window),
          ),
      ],
    );
  }
}

class _ReportPicker extends ConsumerWidget {
  const _ReportPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(reportsProvider);

    return switch (reports) {
      AsyncData(:final value) when value.isEmpty => Text(
          'You have not uploaded a report yet.',
          style: context.texts.bodyMedium
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
      AsyncData(:final value) => Card(
          child: Column(
            children: [
              for (final report in value)
                _ReportRow(key: ValueKey(report.id), report: report),
            ],
          ),
        ),
      AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(reportsProvider),
        ),
      _ => const SkeletonCard(lines: 2),
    };
  }
}

class _ReportRow extends ConsumerStatefulWidget {
  const _ReportRow({super.key, required this.report});

  final MedicalReport report;

  @override
  ConsumerState<_ReportRow> createState() => _ReportRowState();
}

class _ReportRowState extends ConsumerState<_ReportRow> {
  bool _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final link = await ref
          .read(shareLinksProvider.notifier)
          .shareReport(widget.report.id);
      if (mounted) await showLinkSheet(context, link: link);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorText.of(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dated = widget.report.dated;

    return ListTile(
      title: Text(widget.report.fileName, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          widget.report.typeLabel,
          if (dated != null) MediTime.date(dated),
        ].join(' · '),
      ),
      trailing: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              tooltip: 'Share this report',
              icon: const Icon(Icons.ios_share),
              onPressed: _share,
            ),
    );
  }
}

class _Links extends StatelessWidget {
  const _Links({required this.split});

  final SplitShareLinks split;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final link in split.live)
          Padding(
            key: ValueKey(link.token),
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _LinkRow(link: link),
          ),
        if (split.expired.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text('Expired', style: context.texts.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          for (final link in split.expired)
            Padding(
              key: ValueKey(link.token),
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _LinkRow(link: link),
            ),
        ],
      ],
    );
  }
}

class _LinkRow extends ConsumerWidget {
  const _LinkRow({required this.link});

  final ShareLink link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expires = link.expires;
    final dead = link.hasExpired();

    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CardHeader(
              title: link.isWholeRecord ? 'Whole record' : 'One report',
              trailing: StatusChip(
                label: dead ? 'Expired' : 'Live',
                status: dead ? RangeStatus.alert : RangeStatus.ok,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              switch ((dead, expires)) {
                (_, null) => 'Expiry unreadable',
                (true, final at?) => 'Expired ${MediTime.ago(at)}',
                (false, final at?) =>
                  'Expires ${MediTime.until(at.difference(DateTime.now()))} '
                      '· ${MediTime.dateTime(at)}',
              },
              style: context.texts.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            // A Wrap rather than a Row with a Spacer: at large text sizes the
            // two labels together are wider than the card, and the destructive
            // one is the last thing that should be pushed off-screen. Both fit
            // on one line at normal scale, where `spaceBetween` puts them at
            // the two edges exactly as the Spacer did — the gap between Show
            // and Revoke is deliberate.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                if (!dead)
                  TextButton.icon(
                    onPressed: () => showLinkSheet(context, link: link),
                    icon: const Icon(Icons.qr_code_2, size: 18),
                    label: const Text('Show'),
                  ),
                TextButton(
                  onPressed: () => _confirmRevoke(context, ref),
                  child: Text(
                    dead ? 'Remove' : 'Revoke',
                    style: TextStyle(color: context.colors.error),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRevoke(BuildContext context, WidgetRef ref) async {
    final dead = link.hasExpired();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(dead ? 'Remove this link?' : 'Revoke this link?'),
        content: Text(
          dead
              ? 'It already stopped working. This just clears it from the list.'
              : 'Anyone holding it stops being able to read anything, straight '
                  'away. You cannot bring the same link back.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Leave it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(dead ? 'Remove' : 'Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(shareLinksProvider.notifier).revoke(link.token);
      messenger.showSnackBar(
        SnackBar(content: Text(dead ? 'Link removed' : 'Link revoked')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorText.of(error))));
    }
  }
}

/// The QR and the URL, in a sheet. Shown the moment a link is created, because
/// a link nobody can see is a link nobody can use.
Future<void> showLinkSheet(
  BuildContext context, {
  required ShareLink link,
}) {
  final expires = link.expires;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              link.isWholeRecord ? 'Your whole record' : 'One report',
              style: context.texts.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              expires == null
                  ? 'Expiry unreadable.'
                  : 'Works until ${MediTime.dateTime(expires)}, then stops on '
                      'its own.',
              style: context.texts.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            LinkCard(
              url: link.url,
              shareSubject: 'My MediStore record',
              caption: 'Scanning this opens it in a browser — no app needed.',
            ),
          ],
        ),
      ),
    ),
  );
}
