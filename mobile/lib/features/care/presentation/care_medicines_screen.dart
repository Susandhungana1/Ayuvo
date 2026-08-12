/// A caretaker's view of one person's medicines.
///
/// Medicines and nothing else — not rendered, and not fetched. There is no
/// vitals tab here, no reports, no assistant and no share sheet, because the
/// care link authorises exactly one resource and a screen that quietly loads
/// something else would be a data leak that no server check would catch.
///
/// Access is verified twice on purpose. This screen matches the patient id
/// against the caller's own links so it can name whose list it is and refuse to
/// open at all when the link is gone; `resolve_medicine_scope` on the server is
/// the one that actually decides, and its 403 lands mid-session through
/// [MedicinesScreen.onScopeLost].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/states.dart';
import '../../medicines/presentation/medicines_screen.dart';
import 'care_controllers.dart';

class CareMedicinesScreen extends ConsumerWidget {
  const CareMedicinesScreen({super.key, required this.patientId});

  /// The patient's account id, already decoded. It contains a `#`; it only ever
  /// reaches a URL through `ScopedUrl`.
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(careLinkForProvider(patientId));

    return switch (link) {
      AsyncData(value: final link?) => MedicinesScreen(
          patientId: patientId,
          title: '${link.name} · ${context.l10n.navMedicines}',
          banner: _ScopeBanner(name: link.name),
          onScopeLost: (_) => _leave(context, link.name),
        ),
      // Loaded, and this person is not on the list. Either the link was
      // revoked or the id was never ours.
      AsyncData() => const _Gone(),
      AsyncError() => const _Gone(),
      _ => const _Loading(),
    };
  }

  void _leave(BuildContext context, String name) {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text(context.l10n.careRevoked(name))),
    );
    if (navigator.canPop()) navigator.pop();
  }
}

/// Amber, not the app's own colour, and it does not scroll away.
class _ScopeBanner extends StatelessWidget {
  const _ScopeBanner({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: context.status.cautionContainer,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.careScopeBanner(name),
            style: context.texts.bodyMedium
                ?.copyWith(color: context.status.caution),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            context.l10n.careScopeOnly,
            style: context.texts.bodySmall
                ?.copyWith(color: context.status.caution),
          ),
        ],
      ),
    );
  }
}

class _Gone extends StatelessWidget {
  const _Gone();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.careGoneTitle)),
      body: EmptyState(
        icon: Icons.link_off,
        title: context.l10n.careGoneTitle,
        message: context.l10n.careGoneBody,
        actionLabel: context.l10n.careBackToMine,
        onAction: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.navMedicines)),
      body: ListView(
        padding: AppSpacing.screen,
        children: const [
          SkeletonCard(lines: 2),
          SizedBox(height: AppSpacing.md),
          SkeletonCard(lines: 3),
        ],
      ),
    );
  }
}

/// Opens the caretaker view. A push rather than a `go`, so Back returns to
/// wherever the caretaker was — the dashboard, usually — instead of unwinding
/// to a tab root.
Future<void> openCareMedicines(BuildContext context, String patientId) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CareMedicinesScreen(patientId: patientId),
    ),
  );
}
