/// `context.l10n.navHome` — the same short read as `context.colors`.
///
/// `AppL10n.of(context)!` is nullable because a widget can in principle sit
/// above the delegate. In this app nothing does: every screen is below the
/// `MaterialApp.router` in `app.dart`, and a null here would be a wiring bug
/// worth failing on rather than a case worth handling.
library;

import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

extension AppL10nContext on BuildContext {
  AppL10n get l10n => AppL10n.of(this)!;
}
