/// Design tokens — the primitive layer.
///
/// The only file in the app allowed to contain a raw colour or a raw dimension.
/// Everything else reads these through `Theme.of(context)` or one of the theme
/// extensions in `app_theme.dart`. See `DESIGN.md` for the reasoning and the
/// measured contrast ratios behind each value.
library;

import 'package:flutter/widgets.dart';

/// Raw ramp steps. Semantic meaning is assigned in `app_theme.dart` — a widget
/// should never reach for these directly.
abstract final class AppPalette {
  // Brand cyan. cyan700 is the action colour: white on cyan600 measures 3.68:1
  // and fails AA for a button label, while cyan700 reaches 5.36:1. cyan600
  // survives as the focus ring, where the 3:1 non-text threshold applies.
  static const cyan600 = Color(0xFF0891B2);
  static const cyan700 = Color(0xFF0E7490);
  static const cyan800 = Color(0xFF155E75);
  static const cyanDark = Color(0xFF5CD3EC);
  static const cyanDarkInk = Color(0xFF00323E);

  // Status. Reserved: a chart series never uses these.
  static const okLight = Color(0xFF046A4E);
  static const okLightContainer = Color(0xFFE3F6EE);
  static const okDark = Color(0xFF4ADBA4);
  static const okDarkContainer = Color(0xFF0C2A20);

  static const cautionLight = Color(0xFF8A4B08);
  static const cautionLightContainer = Color(0xFFFDF0DC);
  static const cautionDark = Color(0xFFF0B252);
  static const cautionDarkContainer = Color(0xFF2E2009);

  static const alertLight = Color(0xFFB91C1C);
  static const alertLightContainer = Color(0xFFFDE7E7);
  static const alertDark = Color(0xFFFF8A8A);
  static const alertDarkContainer = Color(0xFF33140F);

  // Cool-cast neutrals.
  static const ink900 = Color(0xFF0F2B33);
  static const ink700 = Color(0xFF2C4A54);
  static const ink500 = Color(0xFF4A6670);
  static const paper = Color(0xFFFBFCFD);
  static const card = Color(0xFFFFFFFF);
  static const muted = Color(0xFFEEF3F5);
  static const slate = Color(0xFFC3D4DA);

  static const night = Color(0xFF0F1417);
  static const nightCard = Color(0xFF161D21);
  static const nightMuted = Color(0xFF1E272C);
  static const nightOutline = Color(0xFF32424A);
  static const nightInk = Color(0xFFE6EEF1);
  static const nightInkVariant = Color(0xFF9DB2BA);

  static const white = Color(0xFFFFFFFF);
}

/// 4pt spacing scale. Density 6/10 — see DESIGN.md §4.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;

  /// Screen gutter and card padding. The default answer.
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  static const EdgeInsets screen = EdgeInsets.all(lg);
  static const EdgeInsets screenHorizontal = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets card = EdgeInsets.all(lg);
  static const EdgeInsets listRow =
      EdgeInsets.symmetric(horizontal: lg, vertical: md);
}

abstract final class AppRadius {
  static const Radius smR = Radius.circular(8);
  static const Radius mdR = Radius.circular(12);
  static const Radius lgR = Radius.circular(20);

  static const BorderRadius sm = BorderRadius.all(smR);
  static const BorderRadius md = BorderRadius.all(mdR);
  static const BorderRadius lg = BorderRadius.all(lgR);
  static const BorderRadius full = BorderRadius.all(Radius.circular(999));
  static const BorderRadius sheet =
      BorderRadius.only(topLeft: lgR, topRight: lgR);
}

/// Motion dial 3/10. No bounce, no spring. Exit is faster than entrance so
/// going back feels snappier than going forward.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 280);
  static const Duration exit = Duration(milliseconds: 160);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve standard = Curves.easeInOut;
  static const Curve leave = Curves.easeIn;

  /// Collapse every duration when the platform asks for reduced motion.
  /// Call this instead of passing a token straight to an animation.
  static Duration of(BuildContext context, Duration duration) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false
          ? Duration.zero
          : duration;
}

/// Minimum tap target. Material asks for 48; 44 is the floor for a text-only
/// affordance sitting inside a larger row.
abstract final class AppTouch {
  static const double target = 48;
  static const double minTarget = 44;
}
