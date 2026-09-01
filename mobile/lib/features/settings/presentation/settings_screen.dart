/// Language, appearance, dose reminders and the account's erasure.
///
/// Deliberately four things and not a dumping ground. Profile editing
/// (`PUT /api/users/me`) and two-factor setup are account operations that
/// belong with the account, and are phase 8 — a settings screen that mixes
/// "how the app looks" with "change my password" makes both harder to find.
/// Deletion lives here because the Play Store review requirement names this
/// screen: a user must be able to erase the account from inside the app.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/notifications/reminder_sync.dart';
import '../../../core/notifications/reminders.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/states.dart';
import '../../auth/data/auth_repository.dart';

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
          SizedBox(height: AppSpacing.xl),
          _TwoFactorAuth(),
          SizedBox(height: AppSpacing.xl),
          _ChangePassword(),
          SizedBox(height: AppSpacing.xl),
          _DeleteAccount(),
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

/// Change the signed-in user's password using the server's authenticated
/// endpoint. This mirrors the web settings flow and keeps the session in place
/// when the update succeeds.
class _ChangePassword extends ConsumerWidget {
  const _ChangePassword();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Section(
      title: 'Change password',
      blurb: 'Use your current password to set a new one.',
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _prompt(context, ref),
            icon: const Icon(Icons.lock_reset_outlined),
            label: const Text('Change password'),
          ),
        ),
      ),
    );
  }

  Future<void> _prompt(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change password'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentController,
                  decoration: const InputDecoration(
                    labelText: 'Current password',
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: newController,
                  decoration: const InputDecoration(
                    labelText: 'New password',
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: confirmController,
                  decoration: const InputDecoration(
                    labelText: 'Confirm new password',
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => Navigator.of(context).pop(true),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final currentPassword = currentController.text.trim();
    final newPassword = newController.text.trim();
    final confirmPassword = confirmController.text.trim();

    if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please fill in all password fields.')),
      );
      return;
    }
    if (newPassword != confirmPassword) {
      messenger.showSnackBar(
        const SnackBar(content: Text('New passwords do not match.')),
      );
      return;
    }
    if (newPassword.length < 8) {
      messenger.showSnackBar(
        const SnackBar(content: Text('New password must be at least 8 characters.')),
      );
      return;
    }

    try {
      final message = await ref.read(authRepositoryProvider).changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorText.of(error))));
    }
  }
}

/// Two-factor auth (TOTP) management for the signed-in user.
class _TwoFactorAuth extends ConsumerStatefulWidget {
  const _TwoFactorAuth();

  @override
  ConsumerState<_TwoFactorAuth> createState() => _TwoFactorAuthState();
}

class _TwoFactorAuthState extends ConsumerState<_TwoFactorAuth> {
  bool _loading = true;
  bool _enabled = false;
  bool _busy = false;
  bool _setupMode = false;
  Map<String, String>? _setup;
  final _codeController = TextEditingController();
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final enabled = await ref.read(authRepositoryProvider).twoFactorStatus();
      if (mounted) setState(() => _enabled = enabled);
    } catch (_) {
      // Leave the default as off if the server is unreachable.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _startSetup() async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final setup = await ref.read(authRepositoryProvider).setupTwoFactor();
      if (!mounted) return;
      setState(() {
        _setup = setup;
        _setupMode = true;
        _codeController.clear();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = ErrorText.of(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyEnable() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from your authenticator app.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final enabled = await ref.read(authRepositoryProvider).verifyTwoFactor(code: code);
      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _setupMode = false;
        _setup = null;
        _codeController.clear();
        _notice = enabled ? 'Two-factor authentication is on.' : 'Two-factor authentication could not be enabled.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = ErrorText.of(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disable() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter a current 6-digit code to confirm.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final enabled = await ref.read(authRepositoryProvider).disableTwoFactor(code: code);
      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _setupMode = false;
        _setup = null;
        _codeController.clear();
        _notice = enabled ? 'Two-factor authentication is still on.' : 'Two-factor authentication is off.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = ErrorText.of(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Two-factor authentication',
      blurb: 'Extra protection for your health records. You will need a code from your authenticator app when you sign in.',
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _enabled ? Icons.shield_outlined : Icons.shield_rounded,
                  color: _enabled ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    _enabled ? 'Enabled' : 'Disabled',
                    style: context.texts.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.md),
                child: SizedBox(
                  height: 20,
                  width: 120,
                  child: LinearProgressIndicator(minHeight: 4),
                ),
              )
            else ...[
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Text(
                    _error!,
                    style: context.texts.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_notice != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Text(
                    _notice!,
                    style: context.texts.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              if (_setupMode && _setup != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan this QR code with your authenticator app, then enter the code it shows to confirm.',
                        style: context.texts.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Image.memory(
                          Uint8List.fromList(
                            (Uri.parse(_setup!['qr_code_data_uri'] ?? '').data?.contentAsBytes as List<int>?) ?? const <int>[],
                          ),
                          width: 160,
                          height: 160,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Manual key: ${_setup!['secret']}',
                        style: context.texts.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          labelText: '6-digit code',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton.icon(
                        onPressed: _busy ? null : _verifyEnable,
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(_busy ? 'Verifying…' : 'Verify and enable'),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed: _busy ? null : (_enabled ? () async {
                    final code = _codeController.text.trim();
                    if (code.length != 6) {
                      setState(() => _error = 'Enter a current 6-digit code to confirm.');
                      return;
                    }
                    await _disable();
                  } : _startSetup),
                  icon: Icon(_enabled ? Icons.shield : Icons.shield_outlined),
                  label: Text(_busy ? 'Working…' : (_enabled ? 'Disable 2FA' : 'Enable 2FA')),
                ),
                if (_enabled) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Current authenticator code',
                    ),
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Erase the account, for real.
///
/// Deliberately at the bottom and styled as a danger: a two-step confirm with
/// the erasure spelled out, because the server really does delete everything
/// and nothing here can undo it. On success the session ends the way a
/// sign-out does — tokens cleared locally — but with the notice that the
/// account is gone, not just the session.
class _DeleteAccount extends ConsumerWidget {
  const _DeleteAccount();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return _Section(
      title: l10n.settingsDeleteAccount,
      blurb: l10n.settingsDeleteBlurb,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _confirm(context, ref),
            icon: Icon(Icons.delete_forever_outlined,
                color: Theme.of(context).colorScheme.error),
            label: Text(
              l10n.settingsDeleteAccount,
              style: context.texts.bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteAccountTitle),
        content: Text(l10n.deleteAccountBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.deleteAccountKeep),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(l10n.deleteAccountConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      // The account is gone; the local session must not survive it. signOut
      // revokes the refresh token best-effort (a dead token answers 401, which
      // signOut ignores) and clears everything local.
      await ref.read(sessionControllerProvider.notifier).signOut();
      navigator.popUntil((route) => route.isFirst);
      messenger.showSnackBar(SnackBar(content: Text(l10n.accountDeleted)));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorText.of(error))));
    }
  }
}
