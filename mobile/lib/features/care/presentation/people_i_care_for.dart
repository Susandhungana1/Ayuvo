/// The dashboard section for someone who looks after another person's
/// medicines.
///
/// **It has to be invisible to everyone else.** Most people are not caretakers,
/// and a permanent "People I care for (0)" heading on their home screen is a
/// feature advertising itself at the expense of the screen it sits on. With no
/// links there is one quiet line of text; with the feature switched off on the
/// server there is nothing at all.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/health/health_providers.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/states.dart';
import '../data/care_repository.dart';
import '../domain/care_link.dart';
import 'care_controllers.dart';
import 'care_medicines_screen.dart';
import 'redeem_code_sheet.dart';

class PeopleICareFor extends ConsumerWidget {
  const PeopleICareFor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Checked before the provider so a server with caretakers off costs no
    // request and renders no space.
    if (!ref.watch(caretakerEnabledProvider)) return const SizedBox.shrink();

    final links = ref.watch(careLinksProvider(CareRole.caretaker));

    return switch (links) {
      AsyncData(:final value) when value.isEmpty => const _QuietPrompt(),
      AsyncData(:final value) => _Clients(links: value),
      // Never an error card. This section is a bonus on somebody else's
      // dashboard; a red box for a feature they may not even use is noise.
      _ => const SizedBox.shrink(),
    };
  }
}

class _QuietPrompt extends StatelessWidget {
  const _QuietPrompt();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => showRedeemCodeSheet(context),
          icon: const Icon(Icons.add, size: 18),
          label: Text(context.l10n.careMinePrompt),
        ),
      ),
    );
  }
}

class _Clients extends StatelessWidget {
  const _Clients({required this.links});

  final List<CareLink> links;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A Wrap rather than a Row with an Expanded title: a Row measures a
        // non-flex child against unbounded width and hands it whatever it
        // asks for, so at 2× text the button runs off the edge instead of
        // moving to its own line. Both fit beside each other at normal scale,
        // where `spaceBetween` puts them at the two edges.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            Text(
              context.l10n.careMineTitle,
              style: context.texts.titleLarge,
            ),
            TextButton(
              onPressed: () => showRedeemCodeSheet(context),
              child: Text(context.l10n.careMineAdd),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final link in links)
          Padding(
            key: ValueKey(link.id),
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _ClientCard(link: link),
          ),
      ],
    );
  }
}

class _ClientCard extends ConsumerWidget {
  const _ClientCard({required this.link});

  final CareLink link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openCareMedicines(context, link.userId),
        child: Padding(
          padding: AppSpacing.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(link.name, style: context.texts.titleMedium),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          context.l10n.careMedicineCount(link.medicineCount ?? 0),
                          style: context.texts.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _toggleMute(context, ref),
                    tooltip: link.notify
                        ? context.l10n.careMute
                        : context.l10n.careUnmute,
                    icon: Icon(
                      link.notify
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_off_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                context.l10n.careNextDose(nextDoseLabel(context, link)),
                style: context.texts.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => openCareMedicines(context, link.userId),
                  child: Text(context.l10n.careManage),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleMute(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(careLinksProvider(CareRole.caretaker).notifier)
          .setNotify(link.id, !link.notify);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(_messageFor(error))));
    }
  }
}

/// The dose time, rendered **verbatim**.
///
/// `next_dose_local` is the patient's own wall clock. Parsing it into a
/// `DateTime` would re-express it in the caretaker's zone and show a time
/// neither of them acts on — a daughter in Sydney does not need to know that
/// her father's 8am is her 1:15pm, she needs to know it is 8am there. The zone
/// is named only when the two differ, because otherwise it is noise.
String nextDoseLabel(BuildContext context, CareLink link) {
  if (!link.hasNextDose) return context.l10n.careNoDoses;

  final clock = link.nextDoseLocal!;
  final when = (link.nextDoseIsToday ?? true)
      ? clock
      : context.l10n.careDoseTomorrow(clock);
  final label = context.l10n.careDoseAt(link.nextDoseName!, when);

  final theirs = link.nextDoseTimezone;
  final here = DateTime.now().timeZoneName;
  // A conservative comparison: `timeZoneName` is an abbreviation ("+0545",
  // "GMT") and the server sends an IANA id ("Asia/Kathmandu"), so they rarely
  // match textually. Erring towards showing the note is the safe direction —
  // a redundant "(their time)" is harmless, a missing one is a wrong time.
  final elsewhere = theirs != null && theirs.isNotEmpty && !theirs.contains(here);
  return elsewhere ? '$label ${context.l10n.careTheirTime}' : label;
}

String _messageFor(Object error) => error is CareFailure
    ? error.message
    : ErrorText.of(error);
