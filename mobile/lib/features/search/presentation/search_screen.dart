/// One box over reports, medicines and visits.
///
/// The web app could only send a hit back to a list page (`/reports?highlight=`,
/// or just `/medicines`). Here every kind lands on the thing itself: a report
/// opens its detail screen, a medicine opens its edit sheet, a visit opens its
/// card already expanded.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/time/medi_time.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/states.dart';
import '../../documents/presentation/documents_screen.dart';
import '../../medicines/domain/medicine.dart';
import '../../medicines/presentation/medicine_form_sheet.dart';
import '../../medicines/presentation/medicines_controller.dart';
import '../../reports/presentation/report_detail_screen.dart';
import '../domain/search_hit.dart';
import 'search_controller.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _field;

  @override
  void initState() {
    super.initState();
    // Seeded from the provider so leaving the tab and coming back shows the
    // query and its results rather than an empty box over stale rows.
    _field = TextEditingController(text: ref.read(searchQueryProvider));
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);
    final query = ref.watch(searchQueryProvider).trim();

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.searchTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: TextField(
              controller: _field,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: ref.read(searchQueryProvider.notifier).set,
              decoration: InputDecoration(
                hintText: context.l10n.searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: MaterialLocalizations.of(context)
                            .deleteButtonTooltip,
                        onPressed: () {
                          _field.clear();
                          ref.read(searchQueryProvider.notifier).clear();
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: switch ((query, results)) {
              ('', _) => const _Prompt(),
              // Keeps the previous results on screen while the next query is in
              // flight: a list that blanks on every keystroke is unreadable.
              (_, AsyncValue(:final value?)) when value.results.isNotEmpty =>
                _Results(results: value, stale: results.isLoading),
              (_, AsyncLoading()) => const _Loading(),
              (_, AsyncError(:final error)) => ListView(
                  padding: AppSpacing.screen,
                  children: [
                    ErrorView(
                      error: error,
                      onRetry: () =>
                          ref.read(searchResultsProvider.notifier).retry(),
                    ),
                  ],
                ),
              _ => _NoResults(query: query),
            },
          ),
        ],
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.results, required this.stale});

  final SearchResults results;

  /// True while a newer query is still running. Dims the list rather than
  /// replacing it, so the answer to what was typed a moment ago stays readable.
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Text(
          context.l10n.searchResultCount(results.total),
          style: context.texts.bodySmall
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
      ),
      for (final kind in SearchKind.values)
        if (results.of(kind) case final hits when hits.isNotEmpty) ...[
          _GroupHeading(kind: kind, count: hits.length),
          for (final hit in hits) _HitCard(key: ValueKey(hit.rowKey), hit: hit),
          const SizedBox(height: AppSpacing.lg),
        ],
    ];

    return AnimatedOpacity(
      opacity: stale ? 0.5 : 1,
      duration: AppMotion.of(context, AppMotion.fast),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        itemCount: rows.length,
        itemBuilder: (context, index) => rows[index],
      ),
    );
  }
}

class _GroupHeading extends StatelessWidget {
  const _GroupHeading({required this.kind, required this.count});

  final SearchKind kind;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        '${_labelFor(context, kind).toUpperCase()} · $count',
        style: context.texts.labelSmall
            ?.copyWith(color: context.colors.onSurfaceVariant),
      ),
    );
  }
}

String _labelFor(BuildContext context, SearchKind kind) => switch (kind) {
      SearchKind.report => context.l10n.searchTypeReport,
      SearchKind.medicine => context.l10n.searchTypeMedicine,
      SearchKind.document => context.l10n.searchTypeDocument,
      SearchKind.other => '—',
    };

class _HitCard extends ConsumerWidget {
  const _HitCard({super.key, required this.hit});

  final SearchHit hit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(context, ref),
          child: Padding(
            padding: AppSpacing.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hit.title, style: context.texts.titleMedium),
                if (hit.snippet?.trim().isNotEmpty ?? false) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    hit.snippet!.trim(),
                    style: context.texts.bodyMedium
                        ?.copyWith(color: context.colors.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (hit.when case final moment?) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    MediTime.date(moment),
                    style: context.texts.bodySmall
                        ?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    switch (hit.kind) {
      case SearchKind.report:
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => ReportDetailScreen(reportId: hit.id),
          ),
        );
      case SearchKind.document:
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => DocumentsScreen(highlightId: hit.id),
          ),
        );
      case SearchKind.medicine:
        await _openMedicine(context, ref);
      case SearchKind.other:
        break;
    }
  }

  /// The search endpoint returns the medicine's id but not the medicine, so the
  /// row is found in the list the app already holds.
  ///
  /// It may not be there: `GET /api/search` does **not** filter out
  /// soft-deleted medicines the way it does documents, so a medicine you
  /// removed still turns up here (`BACKEND_NOTES.md` §15). Rather than
  /// pretending it is gone, the app says what happened and offers to put it
  /// back — which is the one thing the id is good for.
  Future<void> _openMedicine(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final medicines = ref.read(medicinesProvider(null)).valueOrNull ?? const [];
    final match = medicines.where((m) => m.id == hit.id);

    if (match.isNotEmpty) {
      await showMedicineSheet(context, existing: match.first);
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text('${hit.title} is not on your list — it was removed.'),
        action: SnackBarAction(
          label: 'Restore',
          onPressed: () => _restore(ref, messenger),
        ),
      ),
    );
  }

  Future<void> _restore(WidgetRef ref, ScaffoldMessengerState messenger) async {
    try {
      final Medicine restored =
          await ref.read(medicinesProvider(null).notifier).undoRemove(hit.id);
      messenger.showSnackBar(
        SnackBar(content: Text('${restored.name} is back on your list')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorText.of(error))));
    }
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt();

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.search,
      title: context.l10n.searchPromptTitle,
      message: context.l10n.searchPromptBody,
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.search_off,
      title: context.l10n.searchNoResultsTitle,
      message: context.l10n.searchNoResultsBody(query),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.screenHorizontal,
      children: const [
        SkeletonCard(lines: 2),
        SizedBox(height: AppSpacing.md),
        SkeletonCard(lines: 2),
      ],
    );
  }
}
