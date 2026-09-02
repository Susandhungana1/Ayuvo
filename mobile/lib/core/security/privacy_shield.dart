/// What the OS task switcher is allowed to photograph.
///
/// Both platforms snapshot the top of the app when it leaves the foreground,
/// and that snapshot lives in the recent-apps carousel until the process dies.
/// For this app the top of the screen is a medicine list, a lab result or a
/// next-dose countdown — a health record sitting in a thumbnail that anyone
/// holding the phone can flick to without unlocking anything.
///
/// So the last thing drawn before the snapshot is taken is a blank cover.
///
/// **Which lifecycle states, and why both.** Android snapshots on `paused`.
/// iOS snapshots on `inactive` — by `paused` it is already too late — and
/// `inactive` also fires for a Control Centre pull-down or a permission
/// dialog, so the cover flashes occasionally on iOS. That is the intended
/// trade: a spurious cover costs a blink, a missed one leaks the record.
///
/// **What this is not.** It hides the *snapshot*. It does not stop a
/// screenshot or a screen recording taken while the app is in front — that
/// needs `FLAG_SECURE` on Android and a screen-capture observer on iOS, both
/// of which are platform-channel work outside this widget.
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

class PrivacyShield extends StatefulWidget {
  const PrivacyShield({super.key, required this.child});

  final Widget child;

  @override
  State<PrivacyShield> createState() => _PrivacyShieldState();
}

class _PrivacyShieldState extends State<PrivacyShield>
    with WidgetsBindingObserver {
  bool _covered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cover = switch (state) {
      // `hidden` is the newer state every platform passes through on its way
      // out; covering it too means the cover is up before either snapshot.
      AppLifecycleState.inactive ||
      AppLifecycleState.paused ||
      AppLifecycleState.hidden =>
        true,
      AppLifecycleState.resumed => false,
      // Detached is a process on its way out with no surface left to draw on.
      AppLifecycleState.detached => _covered,
    };
    if (cover != _covered && mounted) setState(() => _covered = cover);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_covered)
          // Excluded from semantics: a screen reader user has not left the app,
          // and announcing a cover they cannot see would be nonsense.
          const ExcludeSemantics(child: _Cover()),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover();

  @override
  Widget build(BuildContext context) {
    // Opaque, and the theme's own surface, so it reads as the app between
    // screens rather than as a crash or a blank frame.
    return Material(
      color: context.colors.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.health_and_safety_outlined,
              size: 40,
              color: context.colors.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Ayuvo', style: context.texts.titleLarge),
          ],
        ),
      ),
    );
  }
}
