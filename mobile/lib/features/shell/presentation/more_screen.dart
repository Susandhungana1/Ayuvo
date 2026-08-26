/// The account tab: who you are signed in as, everything that is not a
/// bottom-bar tab, and the way out.
///
/// Two versions of the same screen, because the two roles own different
/// things. A doctor has no medicines, no reports and no emergency card — the
/// router keeps them out of `/more/*` entirely — so showing them a Documents
/// tile that redirects home would be worse than not showing it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/health/health_providers.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/range_bar.dart';
import '../../../l10n/app_localizations.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  /// Grouped, not one long list: "my record" and "everything else" are
  /// different kinds of thing, and eleven undifferentiated rows is a menu
  /// nobody reads twice.
  static List<_Destination> _record(AppL10n l10n) => [
        _Destination(
          route: Routes.appointments,
          icon: Icons.event_outlined,
          title: l10n.navAppointments,
          subtitle: l10n.moreAppointmentsBlurb,
        ),
        _Destination(
          route: Routes.documents,
          icon: Icons.folder_outlined,
          title: l10n.navDocuments,
          subtitle: l10n.moreDocumentsBlurb,
        ),
        _Destination(
          route: Routes.search,
          icon: Icons.search,
          title: l10n.navSearch,
          subtitle: l10n.moreSearchBlurb,
        ),
      ];

  static List<_Destination> _help(AppL10n l10n) => [
        _Destination(
          route: Routes.nearby,
          icon: Icons.map_outlined,
          title: l10n.navNearby,
          subtitle: l10n.moreNearbyBlurb,
        ),
        _Destination(
          route: Routes.share,
          icon: Icons.ios_share,
          title: l10n.navSharing,
          subtitle: l10n.moreSharingBlurb,
        ),
        _Destination(
          route: Routes.emergency,
          icon: Icons.emergency_outlined,
          title: l10n.navEmergency,
          subtitle: l10n.moreEmergencyBlurb,
        ),
      ];

  static List<_Destination> _doctorDestinations(AppL10n l10n) => [
        _Destination(
          route: Routes.doctorProfile,
          icon: Icons.badge_outlined,
          title: l10n.navDoctorProfile,
          subtitle: l10n.moreDoctorProfileBlurb,
        ),
        _Destination(
          route: Routes.doctorSettings,
          icon: Icons.tune,
          title: l10n.navSettings,
          subtitle: l10n.moreSettingsBlurb,
        ),
      ];

  static List<_Destination> _legal(AppL10n l10n) => [
        _Destination(
          route: Routes.about,
          icon: Icons.business_outlined,
          title: 'About Us',
          subtitle: 'Quorlyn and the team behind Ayuvo',
        ),
        _Destination(
          route: Routes.contact,
          icon: Icons.mail_outline,
          title: 'Contact',
          subtitle: 'Get help with your account',
        ),
        _Destination(
          route: Routes.faq,
          icon: Icons.help_outline,
          title: 'FAQ',
          subtitle: 'Answers to common questions',
        ),
        _Destination(
          route: Routes.privacy,
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          subtitle: 'How we handle your data',
        ),
        _Destination(
          route: Routes.terms,
          icon: Icons.description_outlined,
          title: 'Terms of Service',
          subtitle: 'Rules for using Ayuvo',
        ),
      ];

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.signOutTitle),
        content: Text(l10n.signOutBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.signOutStay),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.signOut),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      // The router is listening to the session; it moves to sign-in by itself.
      await ref.read(sessionControllerProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final user = ref.watch(currentUserProvider);
    final isDoctor = user?.isDoctor ?? false;
    // Only offered when the server has the feature on. A tile that leads to
    // "this is switched off" is a tile that should not be there.
    final showCaretakers = !isDoctor && ref.watch(caretakerEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navAccount)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          if (user != null)
            Card(
              child: Padding(
                padding: AppSpacing.card,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name, style: context.texts.titleLarge),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(user.email, style: context.texts.bodyMedium),
                    const SizedBox(height: AppSpacing.md),
                    StatusChip(
                      label: isDoctor ? 'Doctor account' : 'Patient',
                      status: RangeStatus.ok,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          if (isDoctor) ...[
            _Group(destinations: _doctorDestinations(l10n)),
            const SizedBox(height: AppSpacing.lg),
            _Group(destinations: _legal(l10n)),
          ] else ...[
            _Group(destinations: _record(l10n)),
            const SizedBox(height: AppSpacing.lg),
            _Group(destinations: _help(l10n)),
            const SizedBox(height: AppSpacing.lg),
            _Group(
              destinations: [
                if (showCaretakers)
                  _Destination(
                    route: Routes.caretakers,
                    icon: Icons.people_outline,
                    title: l10n.navCaretakers,
                    subtitle: l10n.moreCaretakersBlurb,
                  ),
                _Destination(
                  route: Routes.settings,
                  icon: Icons.tune,
                  title: l10n.navSettings,
                  subtitle: l10n.moreSettingsBlurb,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _Group(destinations: _legal(l10n)),
          ],
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton.icon(
            onPressed: () => _confirmSignOut(context, ref),
            icon: const Icon(Icons.logout, size: 18),
            label: Text(l10n.signOut),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.destinations});

  final List<_Destination> destinations;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (final destination in destinations)
            ListTile(
              key: ValueKey(destination.route),
              leading: Icon(destination.icon),
              title: Text(destination.title),
              subtitle: Text(destination.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(destination.route),
            ),
        ],
      ),
    );
  }
}

class _Destination {
  const _Destination({
    required this.route,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final String route;
  final IconData icon;
  final String title;

  /// What is behind the tile, in one line. A list of nouns makes people tap
  /// each one to find out; a sentence does not.
  final String subtitle;
}
