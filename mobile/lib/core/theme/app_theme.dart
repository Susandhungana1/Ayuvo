/// The semantic and component layers of the design system.
///
/// `AppTheme.light` / `AppTheme.dark` are the only ThemeData in the app. Widgets
/// read colours through `Theme.of(context).colorScheme`, text through
/// `.textTheme`, and everything Material 3 has no slot for through the two
/// extensions below:
///
///   context.status    — in-range / borderline / out-of-range
///   context.chart     — the validated categorical series colours
///
/// See DESIGN.md for the contrast measurements behind every value here.
library;

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Status colours. Material 3 has `error` and nothing else, but this product is
/// mostly numbers judged against reference ranges, so it needs three states.
///
/// Colour says how urgent; a direction glyph (▲ / ▼) says which way. Never
/// colour alone — every chip carries its label too.
@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  const AppStatusColors({
    required this.ok,
    required this.okContainer,
    required this.caution,
    required this.cautionContainer,
    required this.alert,
    required this.alertContainer,
  });

  final Color ok;
  final Color okContainer;
  final Color caution;
  final Color cautionContainer;
  final Color alert;
  final Color alertContainer;

  static const light = AppStatusColors(
    ok: AppPalette.okLight,
    okContainer: AppPalette.okLightContainer,
    caution: AppPalette.cautionLight,
    cautionContainer: AppPalette.cautionLightContainer,
    alert: AppPalette.alertLight,
    alertContainer: AppPalette.alertLightContainer,
  );

  static const dark = AppStatusColors(
    ok: AppPalette.okDark,
    okContainer: AppPalette.okDarkContainer,
    caution: AppPalette.cautionDark,
    cautionContainer: AppPalette.cautionDarkContainer,
    alert: AppPalette.alertDark,
    alertContainer: AppPalette.alertDarkContainer,
  );

  @override
  AppStatusColors copyWith({
    Color? ok,
    Color? okContainer,
    Color? caution,
    Color? cautionContainer,
    Color? alert,
    Color? alertContainer,
  }) {
    return AppStatusColors(
      ok: ok ?? this.ok,
      okContainer: okContainer ?? this.okContainer,
      caution: caution ?? this.caution,
      cautionContainer: cautionContainer ?? this.cautionContainer,
      alert: alert ?? this.alert,
      alertContainer: alertContainer ?? this.alertContainer,
    );
  }

  @override
  AppStatusColors lerp(ThemeExtension<AppStatusColors>? other, double t) {
    if (other is! AppStatusColors) return this;
    return AppStatusColors(
      ok: Color.lerp(ok, other.ok, t)!,
      okContainer: Color.lerp(okContainer, other.okContainer, t)!,
      caution: Color.lerp(caution, other.caution, t)!,
      cautionContainer: Color.lerp(cautionContainer, other.cautionContainer, t)!,
      alert: Color.lerp(alert, other.alert, t)!,
      alertContainer: Color.lerp(alertContainer, other.alertContainer, t)!,
    );
  }
}

/// Chart series colours, assigned in fixed order and never cycled.
///
/// Validated with the dataviz skill's checker against both surfaces — lightness
/// band, chroma floor, CVD separation, normal-vision floor and contrast all
/// pass. Re-run it if any value changes; do not reason about ΔE by eye.
///
/// Status colours are deliberately absent: a series is never green, amber or
/// red, because those already mean something in this product.
@immutable
class AppChartColors extends ThemeExtension<AppChartColors> {
  const AppChartColors({required this.series, required this.band});

  /// Slot order is fixed. A 5th series folds into "Other" or becomes a small
  /// multiple — it is never a generated hue.
  final List<Color> series;

  /// The shaded normal band behind a trend line.
  final Color band;

  static const light = AppChartColors(
    series: [
      Color(0xFF0891B2),
      Color(0xFF7C3AED),
      Color(0xFFDB2777),
      Color(0xFF2563EB),
    ],
    band: AppPalette.okLightContainer,
  );

  static const dark = AppChartColors(
    series: [
      Color(0xFF0A98BA),
      Color(0xFF9363FF),
      Color(0xFFF60281),
      Color(0xFF4581FE),
    ],
    band: AppPalette.okDarkContainer,
  );

  @override
  AppChartColors copyWith({List<Color>? series, Color? band}) =>
      AppChartColors(series: series ?? this.series, band: band ?? this.band);

  @override
  AppChartColors lerp(ThemeExtension<AppChartColors>? other, double t) {
    if (other is! AppChartColors) return this;
    return AppChartColors(
      series: [
        for (var i = 0; i < series.length; i++)
          Color.lerp(series[i], other.series[i], t)!,
      ],
      band: Color.lerp(band, other.band, t)!,
    );
  }
}

/// Type styles Material 3 has no slot for.
@immutable
class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography({required this.numericLarge, required this.numericMedium});

  /// The reading on a vitals tile.
  final TextStyle numericLarge;

  /// Figures in a table, dose times, countdowns.
  final TextStyle numericMedium;

  /// Tabular figures so columns line up and a live countdown doesn't jitter as
  /// its digits change width.
  static const _tabular = [FontFeature.tabularFigures()];

  static const fallback = AppTypography(
    numericLarge: TextStyle(
      fontFamily: _heading,
      fontSize: 28,
      height: 34 / 28,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
      fontFeatures: _tabular,
    ),
    numericMedium: TextStyle(
      fontFamily: _heading,
      fontSize: 16,
      height: 22 / 16,
      fontWeight: FontWeight.w600,
      fontFeatures: _tabular,
    ),
  );

  @override
  AppTypography copyWith({TextStyle? numericLarge, TextStyle? numericMedium}) =>
      AppTypography(
        numericLarge: numericLarge ?? this.numericLarge,
        numericMedium: numericMedium ?? this.numericMedium,
      );

  @override
  AppTypography lerp(ThemeExtension<AppTypography>? other, double t) {
    if (other is! AppTypography) return this;
    return AppTypography(
      numericLarge: TextStyle.lerp(numericLarge, other.numericLarge, t)!,
      numericMedium: TextStyle.lerp(numericMedium, other.numericMedium, t)!,
    );
  }
}

/// Figtree for headings, Noto Sans for body — the `Medical Clean` pairing.
///
/// Noto Sans is not a default: the app ships Nepali and Noto is the only one of
/// the two with Devanagari coverage. Figtree has none, so Devanagari falls back
/// through the chain below and headings are Latin-only by design.
const _heading = 'Figtree';
const _body = 'Noto Sans';
const _fallback = <String>['Noto Sans Devanagari'];

TextTheme _textTheme(Color ink, Color inkVariant) {
  TextStyle h(double size, double lineHeight, {double tracking = 0}) => TextStyle(
        fontFamily: _heading,
        fontFamilyFallback: _fallback,
        fontSize: size,
        height: lineHeight / size,
        fontWeight: FontWeight.w600,
        letterSpacing: tracking,
        color: ink,
      );

  TextStyle b(double size, double lineHeight,
          {double tracking = 0, Color? color}) =>
      TextStyle(
        fontFamily: _body,
        fontFamilyFallback: _fallback,
        fontSize: size,
        height: lineHeight / size,
        fontWeight: FontWeight.w400,
        letterSpacing: tracking,
        color: color ?? ink,
      );

  return TextTheme(
    displaySmall: h(32, 40, tracking: -0.5),
    headlineMedium: h(24, 32, tracking: -0.3),
    titleLarge: h(20, 28, tracking: -0.2),
    titleMedium: h(16, 24),
    bodyLarge: b(16, 24),
    bodyMedium: b(14, 20),
    bodySmall: b(12, 16, tracking: 0.1, color: inkVariant),
    labelLarge: h(14, 20, tracking: 0.1),
    labelMedium: h(12, 16, tracking: 0.2),
    labelSmall: h(11, 16, tracking: 0.5),
  );
}

abstract final class AppTheme {
  static ThemeData get light => _build(_lightScheme, Brightness.light);
  static ThemeData get dark => _build(_darkScheme, Brightness.dark);

  // Seeded so every M3 role Flutter derives stays harmonious, then the roles
  // that carry text or an action are overridden with measured values. Seeding
  // alone would hand back a primary that fails AA against white.
  static final _lightScheme = ColorScheme.fromSeed(
    seedColor: AppPalette.cyan700,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppPalette.cyan700,
    onPrimary: AppPalette.white,
    surface: AppPalette.paper,
    onSurface: AppPalette.ink900,
    onSurfaceVariant: AppPalette.ink500,
    surfaceContainerLowest: AppPalette.card,
    surfaceContainerLow: AppPalette.card,
    surfaceContainer: AppPalette.card,
    surfaceContainerHigh: AppPalette.muted,
    surfaceContainerHighest: AppPalette.muted,
    // `outline` draws control boundaries (input borders, outlined buttons) and
    // owes 3:1; `outlineVariant` draws hairlines (cards, dividers) and owes
    // nothing. They were the same value, which put every input below the floor.
    outline: AppPalette.slateStrong,
    outlineVariant: AppPalette.slate,
    error: AppPalette.alertLight,
    onError: AppPalette.white,
    errorContainer: AppPalette.alertLightContainer,
    onErrorContainer: AppPalette.alertLight,
  );

  static final _darkScheme = ColorScheme.fromSeed(
    seedColor: AppPalette.cyan700,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppPalette.cyanDark,
    onPrimary: AppPalette.cyanDarkInk,
    surface: AppPalette.night,
    onSurface: AppPalette.nightInk,
    onSurfaceVariant: AppPalette.nightInkVariant,
    surfaceContainerLowest: AppPalette.night,
    surfaceContainerLow: AppPalette.nightCard,
    surfaceContainer: AppPalette.nightCard,
    surfaceContainerHigh: AppPalette.nightMuted,
    surfaceContainerHighest: AppPalette.nightMuted,
    outline: AppPalette.nightOutlineStrong,
    outlineVariant: AppPalette.nightOutline,
    error: AppPalette.alertDark,
    onError: AppPalette.alertDarkContainer,
    errorContainer: AppPalette.alertDarkContainer,
    onErrorContainer: AppPalette.alertDark,
  );

  static ThemeData _build(ColorScheme scheme, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final text = _textTheme(scheme.onSurface, scheme.onSurfaceVariant);
    final focus = isLight ? AppPalette.cyan600 : AppPalette.cyanDark;

    // Disabled controls, measured rather than inherited — see AppPalette.
    final disabledInk =
        isLight ? AppPalette.disabledInkLight : AppPalette.disabledInkDark;
    final disabledFill =
        isLight ? AppPalette.disabledFillLight : AppPalette.disabledFillDark;

    // Press feedback. Material's default overlay is 10% and all but invisible
    // on a white card; 16% reads as a press without reading as a selection.
    // Applied as a WidgetStateProperty so hover and focus keep their own steps.
    final pressOverlay = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.pressed)) {
        return scheme.onSurface.withValues(alpha: 0.16);
      }
      if (states.contains(WidgetState.hovered)) {
        return scheme.onSurface.withValues(alpha: 0.06);
      }
      if (states.contains(WidgetState.focused)) {
        return scheme.onSurface.withValues(alpha: 0.10);
      }
      return null;
    });

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text,
      fontFamily: _body,
      fontFamilyFallback: _fallback,

      extensions: <ThemeExtension<dynamic>>[
        isLight ? AppStatusColors.light : AppStatusColors.dark,
        isLight ? AppChartColors.light : AppChartColors.dark,
        AppTypography.fallback,
      ],

      // Cards are flat with a hairline. Shadow is reserved for things that
      // genuinely float — and it is invisible on a near-black surface anyway.
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.md,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: scheme.surfaceTint,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),

      // The height is the touch target; the width is a minimum, not a demand.
      // `Size.fromHeight` sets minWidth to infinity, which makes every button
      // in the app full-width — and *crashes* any button in a Row or another
      // horizontally unbounded parent, because an infinite minWidth cannot be
      // satisfied there. A form that wants a full-width button says so with a
      // `SizedBox(width: double.infinity)` or a stretching Column, which is
      // what every one of them already does.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(AppTouch.minTarget, AppTouch.target),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.sm),
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          disabledBackgroundColor: disabledFill,
          disabledForegroundColor: disabledInk,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(AppTouch.minTarget, AppTouch.target),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.sm),
          textStyle: text.labelLarge,
          side: BorderSide(color: scheme.outline),
          disabledForegroundColor: disabledInk,
        ).copyWith(overlayColor: pressOverlay),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(AppTouch.minTarget, AppTouch.minTarget),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.sm),
          textStyle: text.labelLarge,
          disabledForegroundColor: disabledInk,
        ).copyWith(overlayColor: pressOverlay),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.sm,
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.sm,
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.sm,
          borderSide: BorderSide(color: focus, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.sm,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.sm,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        labelStyle: text.bodyMedium,
        hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        // Always reserve the line, so validating a form never shifts the layout.
        helperMaxLines: 2,
        errorMaxLines: 2,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        side: BorderSide.none,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.full),
        labelStyle: text.labelSmall,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        // Always visible: an icon-only bar makes people guess.
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        actionTextColor: scheme.inversePrimary,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sm),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: AppSpacing.listRow,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodySmall,
        minVerticalPadding: AppSpacing.sm,
        // Settings rows, report rows and activity rows are all ListTiles, and
        // the stock 10% ripple is invisible on a white card in daylight.
        splashColor: scheme.onSurface.withValues(alpha: 0.12),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Short reads for the theme extensions, so a widget says what it means.
extension AppThemeContext on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get texts => Theme.of(this).textTheme;
  AppStatusColors get status => Theme.of(this).extension<AppStatusColors>()!;
  AppChartColors get chart => Theme.of(this).extension<AppChartColors>()!;
  AppTypography get numerals => Theme.of(this).extension<AppTypography>()!;
}
