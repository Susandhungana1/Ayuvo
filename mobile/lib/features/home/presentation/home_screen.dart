/// The signed-in landing screen.
///
/// Phase 3 scope: it proves the round trip — who the token says you are, and
/// whether the backend this build points at is actually answering. The real
/// dashboard (next dose, latest vitals, today's medicines) lands in phase 4 and
/// replaces the connection card below.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/health/health_providers.dart';
import '../../../core/health/health_status.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/range_bar.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/states.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(healthProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            Text(
              user == null ? 'Hello' : 'Hello, ${user.shortName}',
              style: context.texts.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Your medicines, vitals and reports arrive here in the next '
              'phase. For now this screen confirms the app and the server '
              'agree about who you are.',
              style: context.texts.bodyMedium
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xl),
            const _ConnectionCard(),
          ],
        ),
      ),
    );
  }
}

/// Which server this build talks to, and whether it is answering.
class _ConnectionCard extends ConsumerWidget {
  const _ConnectionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(healthProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Connection', style: context.texts.titleLarge),
        const SizedBox(height: AppSpacing.md),
        health.when(
          loading: () => const SkeletonCard(lines: 3),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(healthProvider),
          ),
          data: (status) => _HealthCard(status: status),
        ),
      ],
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.status});

  final HealthStatus status;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Server', style: context.texts.bodySmall),
            const SizedBox(height: AppSpacing.xxs),
            // The base URL is a build setting, not anyone's data — showing it
            // is how you tell a local run from a production one at a glance.
            Text(Env.apiBaseUrl, style: context.numerals.numericMedium),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                StatusChip(
                  label: status.isHealthy ? 'Answering' : 'Degraded',
                  status: status.isHealthy ? RangeStatus.ok : RangeStatus.alert,
                ),
                StatusChip(
                  label: status.database ? 'Database up' : 'Database down',
                  status: status.database ? RangeStatus.ok : RangeStatus.alert,
                ),
                StatusChip(
                  label: status.canSendEmail
                      ? 'Email via ${status.email}'
                      : 'Email not configured',
                  status: status.canSendEmail
                      ? RangeStatus.ok
                      : RangeStatus.caution,
                ),
                StatusChip(
                  label: status.caretaker ? 'Caretakers on' : 'Caretakers off',
                  status:
                      status.caretaker ? RangeStatus.ok : RangeStatus.caution,
                ),
              ],
            ),
            if (!status.canSendEmail) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Password reset needs a mail transport. Without one the server '
                'still answers, but no code ever arrives.',
                style: context.texts.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
