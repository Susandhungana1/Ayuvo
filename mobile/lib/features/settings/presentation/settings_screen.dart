/// Language, appearance and dose reminders.
///
/// Deliberately three things and not a dumping ground. Profile editing
/// (`PUT /api/users/me`) and two-factor setup are account operations that
/// belong with the account, and are phase 8 — a settings screen that mixes
/// "how the app looks" with "change my password" makes both harder to find.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/notifications/reminder_sync.dart';
import '../../../core/notifications/reminders.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: const [
          _Language(),
          SizedBox(height: AppSpacing.xl),
          _Appearance(),
          SizedBox(height: AppSpacing.xl),
          _Reminders(),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, this.blurb, required this.child});

  final String title;
  final String? blurb;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.texts.titleLarge),
        if (blurb != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            blurb!,
            style: context.texts.bodyMedium
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Card(child: child),
      ],
    );
  }
}

/// "Follow the phone" is a real choice, not the absence of one — so it gets a
/// name rather than being represented by a null locale in the radio group.
/// A nullable `RadioGroup<Locale?>` would make "unselected" and "system"
/// indistinguishable.
enum _LanguageChoice { system, english, nepali }

class _Language extends ConsumerWidget {
  const _Language();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(currentSettingsProvider).locale;
    final controller = ref.read(settingsProvider.notifier);
    final chosen = switch (locale?.languageCode) {
      'en' => _LanguageChoice.english,
      'ne' => _LanguageChoice.nepali,
      _ => _LanguageChoice.system,
    };

    return _Section(
      title: context.l10n.settingsLanguage,
      // Says plainly how far the translation goes. Claiming the app speaks
      // Nepali and then showing English on every second screen is worse than
      // saying which parts are done.
      blurb: context.l10n.settingsLanguageBlurb,
      child: RadioGroup<_LanguageChoice>(
        groupValue: chosen,
        onChanged: (value) => controller.setLocale(switch (value) {
          _LanguageChoice.english => const Locale('en'),
          _LanguageChoice.nepali => const Locale('ne'),
          _ => null,
        }),
        child: Column(
          children: [
            RadioListTile<_LanguageChoice>(
              value: _LanguageChoice.system,
              title: Text(context.l10n.themeSystem),
            ),
            RadioListTile<_LanguageChoice>(
              value: _LanguageChoice.english,
              title: Text(context.l10n.languageEnglish),
            ),
            RadioListTile<_LanguageChoice>(
              value: _LanguageChoice.nepali,
              title: Text(context.l10n.languageNepali),
            ),
          ],
        ),
      ),
    );
  }
}

class _Appearance extends ConsumerWidget {
  const _Appearance();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(currentSettingsProvider).themeMode;
    final controller = ref.read(settingsProvider.notifier);

    return _Section(
      title: context.l10n.settingsAppearance,
      child: RadioGroup<ThemeMode>(
        groupValue: mode,
        onChanged: (chosen) =>
            chosen == null ? null : controller.setThemeMode(chosen),
        child: Column(
          children: [
            for (final (value, label) in <(ThemeMode, String)>[
              (ThemeMode.system, context.l10n.themeSystem),
              (ThemeMode.light, context.l10n.themeLight),
              (ThemeMode.dark, context.l10n.themeDark),
            ])
              RadioListTile<ThemeMode>(value: value, title: Text(label)),
          ],
        ),
      ),
    );
  }
}

class _Reminders extends ConsumerWidget {
  const _Reminders();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(currentSettingsProvider).remindersEnabled;
    final scheduled = ref.watch(reminderSyncProvider);
    final setupNote = ref.watch(remindersProvider).setupNote;

    return _Section(
      title: context.l10n.settingsReminders,
      blurb: context.l10n.settingsRemindersBlurb,
      child: Column(
        children: [
          SwitchListTile(
            value: enabled,
            onChanged: (wanted) => _toggle(context, ref, wanted),
            title: Text(context.l10n.settingsRemindersOn),
            subtitle: enabled
                ? Text(
                    '${context.l10n.settingsRemindersScheduled(scheduled.valueOrNull ?? 0)}'
                    ' · ${context.l10n.settingsRemindersHorizon}',
                  )
                : null,
          ),
          // When nothing is scheduled and the browser refused to arm push, say
          // why — the read-back message is how an iPhone reports the actual
          // blocker (tab vs Home Screen app, permission, worker state).
          if (enabled && (scheduled.valueOrNull ?? 0) == 0 && setupNote != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                0,
              ),
              child: Text(
                setupNote,
                style: context.texts.bodySmall?.copyWith(
                  color: context.status.caution,
                ),
              ),
            ),
          if (enabled) ...[
            const _PermissionNotice(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _sendTest(context, ref),
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: Text(context.l10n.settingsRemindersTest),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Schedules a notification ten seconds from now so the user can check
  /// delivery without waiting for a dose time. Reports success or the reason it
  /// could not happen in a snackbar.
  Future<void> _sendTest(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final reminders = ref.read(remindersProvider);
    // Also the finishing step for iOS: the very first enable has no gesture
    // left after the permission prompt, so the subscription completes on this
    // tap instead, and only then does the test push go out.
    await reminders.ensureSubscribed();
    final sent = await reminders.sendTest();
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          sent ? l10n.settingsRemindersTestSent : l10n.settingsRemindersTestFailed,
        ),
      ),
    );
  }

  /// Permission is asked for at the moment the switch goes on, not on launch.
  /// A user who has just said "remind me" understands what the system dialog is
  /// for; the same dialog on first open is the one everybody refuses.
  Future<void> _toggle(BuildContext context, WidgetRef ref, bool wanted) async {
    final settings = ref.read(settingsProvider.notifier);
    if (!wanted) {
      await settings.setRemindersEnabled(false);
      return;
    }

    final reminders = ref.read(remindersProvider);

    // The push subscription has to be created inside this tap. On iOS it only
    // survives as the first awaited call of the gesture, so when permission is
    // already granted we must not await anything else first.
    if (reminders.permissionNow() != true) {
      final status = await reminders.status();
      if (status == ReminderPermission.unknown ||
          status == ReminderPermission.denied) {
        await reminders.request();
      }
    }

    // On the very first enable the permission dialog just consumed this tap's
    // gesture on iOS, so this can still fail; the Send-test button (or the next
    // tap) retries it, and until then the subtitle honestly reads "0
    // scheduled".
    await reminders.ensureSubscribed();

    await settings.setRemindersEnabled(true);
    // The graph reacts to the setting, but not to a permission that changed
    // underneath it — so nudge the sync explicitly.
    await ref.read(reminderSyncProvider.notifier).resync();
  }
}

/// Only appears when the OS has actually refused. Explains where to fix it,
/// because nothing in the app can.
class _PermissionNotice extends ConsumerWidget {
  const _PermissionNotice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(reminderPermissionProvider).valueOrNull;
    if (status != ReminderPermission.denied) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Text(
        context.l10n.settingsRemindersDenied,
        style: context.texts.bodySmall?.copyWith(color: context.status.caution),
      ),
    );
  }
}

/// Re-read whenever the reminder sync runs, so granting the permission in
/// system settings and coming back clears the notice.
final reminderPermissionProvider =
    FutureProvider<ReminderPermission>((ref) async {
  await ref.watch(reminderSyncProvider.future);
  return ref.watch(remindersProvider).status();
});
