/// The medicine list: what you are taking, what you have finished, and what
/// the interaction check makes of it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/notifications/pending_intakes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/load_more_button.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/states.dart';
import '../data/medicine_repository.dart';
import '../domain/medicine.dart';
import 'medicine_form_sheet.dart';
import 'medicine_history_screen.dart';
import 'medicines_controller.dart';
import 'widgets/interaction_banner.dart';
import 'widgets/medicine_card.dart';

class MedicinesScreen extends ConsumerStatefulWidget {
  const MedicinesScreen({
    super.key,
    this.patientId,
    this.title,
    this.banner,
    this.onScopeLost,
  });

  /// Set only when a caretaker is acting for someone else. Null is the
  /// patient's own list.
  final String? patientId;

  /// Overridden by the caretaker view, which names whose list this is.
  final String? title;

  /// Sits between the app bar and the list. The caretaker view puts its scope
  /// banner here so the attribution stays on screen while the list scrolls —
  /// a column of Remove buttons with no reminder of whose they are is exactly
  /// the confusion the banner exists to prevent.
  final Widget? banner;

  /// Called when the server says the care link is gone. Only the caretaker
  /// view passes this; a patient's own list cannot lose scope.
  final void Function(Object error)? onScopeLost;

  @override
  ConsumerState<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends ConsumerState<MedicinesScreen> {
  bool _pendingConsumed = false;

  @override
  void initState() {
    super.initState();
    // Consume any pending intake from a notification tap (cold start).
    // Only applies to the patient's own list.
    if (widget.patientId == null && !_pendingConsumed) {
      _pendingConsumed = true;
      final pending = consumePendingIntakes();
      if (pending.isNotEmpty) {
        // Delay until the controller is ready (first frame).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final repo = ref.read(medicineRepositoryProvider);
          for (final intake in pending) {
            repo.recordIntake(
              intake.medId,
              scheduledTime: intake.time,
              status: 'taken',
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final medicines = ref.watch(medicinesProvider(widget.patientId));

    if (widget.onScopeLost != null) {
      ref.listen(medicinesProvider(widget.patientId), (_, next) {
        if (next case AsyncError(:final error)
            when ApiException.from(error).kind == ApiErrorKind.forbidden) {
          widget.onScopeLost!(error);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Medicines'),
        // A different colour from the app's own, so a caretaker can never
        // mistake somebody else's list for their own. `front/` uses amber for
        // the same reason; this is the theme's caution container.
        backgroundColor:
            widget.patientId == null ? null : context.status.cautionContainer,
        actions: [
          IconButton(
            onPressed: () => _openHistory(context),
            icon: const Icon(Icons.history),
            tooltip: 'Changes and doses',
          ),
        ],
      ),
      floatingActionButton: medicines.hasValue && medicines.value!.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () =>
                  showMedicineSheet(context, patientId: widget.patientId),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            )
          : null,
      body: Column(
        children: [
          ?widget.banner,
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref
                  .read(medicinesProvider(widget.patientId).notifier)
                  .refresh(),
              child: switch (medicines) {
                AsyncData(:final value) when value.isEmpty => _Empty(
                    onAdd: () => showMedicineSheet(context,
                        patientId: widget.patientId),
                  ),
                AsyncData(:final value) => _List(
                    medicines: value, patientId: widget.patientId),
                AsyncError(:final error) => ListView(
                    padding: AppSpacing.screen,
                    children: [
                      ErrorView(
                        error: error,
                        onRetry: () => ref
                            .read(medicinesProvider(widget.patientId).notifier)
                            .refresh(),
                      ),
                    ],
                  ),
                _ => const _Loading(),
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openHistory(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MedicineHistoryScreen(patientId: widget.patientId),
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List({required this.medicines, required this.patientId});

  final List<Medicine> medicines;
  final String? patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = [for (final m in medicines) if (!m.hasEnded) m];
    final finished = [for (final m in medicines) if (m.hasEnded) m];

    // One flat list of pre-decided rows, so ListView.builder still does the
    // building and a long list of medicines never builds off-screen cards.
    final rows = <Widget>[
      _Interactions(patientId: patientId),
      if (active.isNotEmpty) const _SectionHeader('Currently taking'),
      for (final medicine in active)
        _Row(medicine: medicine, patientId: patientId),
      if (finished.isNotEmpty) ...[
        const _SectionHeader(
          'Finished',
          note: 'Kept for your records. Not included in the interaction check.',
        ),
        for (final medicine in finished)
          _Row(medicine: medicine, patientId: patientId),
      ],
      Consumer(
        builder: (context, ref, _) {
          final offset = ref.watch(medicinesOffsetProvider);
          final total = ref.watch(medicinesTotalProvider);
          final loadingMore = ref.watch(medicinesLoadingMoreProvider);
          return LoadMoreButton(
            offset: offset,
            total: total,
            loading: loadingMore,
            onTap: () =>
                ref.read(medicinesProvider(patientId).notifier).loadMore(),
          );
        },
      ),
      // Clears the FAB.
      const SizedBox(height: 88),
    ];

    return ListView.builder(
      padding: AppSpacing.screen,
      itemCount: rows.length,
      itemBuilder: (context, index) => rows[index],
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({required this.medicine, required this.patientId});

  final Medicine medicine;
  final String? patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      key: ValueKey(medicine.id),
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: MedicineCard(
        medicine: medicine,
        onEdit: () => showMedicineSheet(
          context,
          existing: medicine,
          patientId: patientId,
        ),
        onRemove: () => _confirmRemove(context, ref),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${medicine.name}?'),
        content: const Text(
          'It comes off your list and out of the interaction check. Your '
          'record of it is kept, and you can put it back.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(medicinesProvider(patientId).notifier);
    try {
      await controller.remove(medicine.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Removed ${medicine.name}'),
          // The delete is soft server-side, so Undo restores the same row with
          // the same id and the same history — not a copy of it.
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => controller.undoRemove(medicine.id),
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(ErrorText.of(error))),
      );
    }
  }
}

class _Interactions extends ConsumerWidget {
  const _Interactions({required this.patientId});

  final String? patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Deliberately quiet on loading and on failure: this banner is an extra
    // check, and a red error card where a warning would go reads as though
    // something is wrong with the medicines themselves.
    final check = ref.watch(interactionsProvider(patientId)).valueOrNull;
    if (check == null || check.interactions.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InteractionBanner(check: check),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.note});

  final String title;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: context.texts.labelSmall
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          if (note != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              note!,
              style: context.texts.bodySmall
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    // Inside a scroll view so pull-to-refresh still works on an empty list.
    return ListView(
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
        EmptyState(
          icon: Icons.medication_outlined,
          title: 'No medicines yet',
          message: 'Add what you take and when, and this becomes your '
              'schedule — with an interaction check across the whole list.',
          actionLabel: 'Add your first medicine',
          onAction: onAdd,
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
        SkeletonCard(lines: 3),
        SizedBox(height: AppSpacing.md),
        SkeletonCard(lines: 2),
      ],
    );
  }
}
