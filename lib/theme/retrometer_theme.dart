import 'package:flutter/material.dart';

/// Centralized design system for Retrometer — a dark, high-contrast motorsport
/// cockpit theme. All screens read colors and text styles from here instead of
/// inlining `Colors.xxx` literals, so the palette/typography stays consistent
/// across iOS and Android and can be tuned in one place.
///
/// The palette is derived from the original hardcoded colors (preserved brand
/// identity: greenAccent primary, yellowAccent secondary, redAccent danger,
/// the three Δ-band backgrounds) but unified into a small, named surface scale.

// ---------------------------------------------------------------------------
// Palette.
// ---------------------------------------------------------------------------

class RetrometerColors {
  const RetrometerColors._();

  // Surfaces — Rally's desaturated dark blue-gray scale. Depth comes from the
  // color step between layers (background → surface → surfaceElevated), not
  // from borders, so panels read as stacked cards on a dashboard.
  static const Color background = Color(0xFF2D2E36); // Rally #33333D, darkened for night drive
  static const Color surface = Color(0xFF363740); // Rally surface
  static const Color surfaceElevated = Color(0xFF42434D); // Rally surface variant
  static const Color surfaceHeader = Color(0xFF1F2A26); // teal-tinted panel
  static const Color sheet = Color(0xFF3A3B44);

  // Brand accents — Rally teal as primary (calmer than neon greenAccent) +
  // Rally red for danger. Yellow stays for the Δ "late" state (Rally only has
  // two semantic colors; this app has three Δ bands, so the third is kept).
  static const Color primary = Color(0xFF41DFB4); // Rally teal
  static const Color secondary = Color(0xFFFFEE58); // yellow (Δ delay)
  static const Color danger = Color(0xFFFF5252); // Rally negative red

  // Δ indicator band backgrounds + foregrounds. Backgrounds kept vivid enough
  // to remain the at-a-glance signal; onTime retuned to teal to match primary.
  static const Color onTimeBg = Color(0xFF0E4D38); // teal-dark
  static const Color advanceBg = Color(0xFFB71C1C);
  static const Color delayBg = Color(0xFFF57F17);
  static const Color onTimeFg = Color(0xFF41DFB4); // teal
  static const Color advanceFg = Color(0xFFFF5252); // Rally red
  static const Color delayFg = Color(0xFFFFEE58); // yellow

  // Stage status colors.
  static const Color running = Color(0xFF41DFB4); // teal
  static const Color started = Colors.white54;
  static const Color waiting = Colors.amberAccent;

  // Text on dark surfaces — the same white-opacity scale the app already used.
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;
  static const Color textTertiary = Colors.white54;
  static const Color textMuted = Colors.white38;
  static const Color textFaint = Colors.white24;
  static const Color hint = Colors.white30;

  // Lines & borders.
  static const Color divider = Colors.white12;
  static const Color dividerStrong = Colors.white24;
  static const Color fieldBorder = Colors.white38;
  static const Color scrim = Colors.black54;

  // Action button fills (START/STOP/RESET).
  static const Color startFill = Color(0xFF41DFB4); // teal
  static const Color stopFill = Color(0xFFFF5252); // Rally red
  static const Color resetFill = Color(0xFF42434D); // surfaceElevated (secondary button)
  static const Color onActionFill = Colors.black;

  /// A translucent fill + matching border for status/standing pills, tinted by
  /// [color] — the chip pattern used by `_StandingBadge` and stage status.
  static BoxDecoration pillDecoration(Color color, {double radius = 6}) =>
      BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      );
}

// ---------------------------------------------------------------------------
// Typography.
// ---------------------------------------------------------------------------

/// Named text styles used across screens. Font family is left to the platform
/// default (San Francisco on iOS, Roboto on Android) per the design decision.
class RetrometerTextStyles {
  const RetrometerTextStyles._();

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  // Cockpit Δ zone.
  static TextStyle bandLabel(Color c) => TextStyle(
        color: c,
        fontSize: 44,
        fontWeight: FontWeight.bold,
        letterSpacing: 4,
      );
  static const TextStyle deltaNumber = TextStyle(
    fontSize: 180,
    fontWeight: FontWeight.bold,
    fontFeatures: _tabular,
    height: 1,
  );
  static TextStyle deltaNumberColored(Color c) =>
      deltaNumber.copyWith(color: c);
  static const TextStyle deltaSubtitle = TextStyle(
    color: RetrometerColors.textSecondary,
    fontSize: 22,
  );
  static const TextStyle deltaStageName = TextStyle(
    color: RetrometerColors.primary, // teal — stage identity
    fontSize: 22,
    fontWeight: FontWeight.bold,
    fontFeatures: _tabular,
  );

  // Trip-meter.
  static const TextStyle distanceNumber = TextStyle(
    color: RetrometerColors.textPrimary,
    fontSize: 120,
    fontWeight: FontWeight.bold,
    fontFeatures: _tabular,
    height: 1,
  );
  static const TextStyle distanceUnit = TextStyle(
    color: RetrometerColors.textTertiary,
    fontSize: 28,
  );
  static const TextStyle adjustSign = TextStyle(
    color: RetrometerColors.textPrimary,
    fontSize: 72,
    fontWeight: FontWeight.bold,
    height: 1,
  );
  static const TextStyle adjustAmount = TextStyle(
    color: RetrometerColors.textSecondary,
    fontSize: 20,
  );
  static const TextStyle adjustLong = TextStyle(
    color: RetrometerColors.textMuted,
    fontSize: 13,
  );

  // Top bar.
  static TextStyle topBarText({bool compact = false}) => TextStyle(
        color: RetrometerColors.textPrimary,
        fontSize: compact ? 15 : 18,
        fontWeight: FontWeight.bold,
        fontFeatures: _tabular,
      );
  static TextStyle competitionRow = const TextStyle(
    color: RetrometerColors.primary,
    fontSize: 13,
  );

  // Control buttons (START/STOP/RESET).
  static const TextStyle controlLabel = TextStyle(
    color: RetrometerColors.onActionFill,
    fontWeight: FontWeight.bold,
    fontSize: 14,
  );

  // Over-speed alert.
  static const TextStyle overSpeed = TextStyle(
    color: Colors.red,
    fontSize: 22,
    fontWeight: FontWeight.bold,
  );

  // Tiles / list.
  static const TextStyle tileTitle = TextStyle(
    color: RetrometerColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );
  static const TextStyle headerTitle = TextStyle(
    color: RetrometerColors.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );
  static const TextStyle meta = TextStyle(
    color: RetrometerColors.textTertiary,
    fontSize: 13,
  );
  static const TextStyle metaStrong = TextStyle(
    color: RetrometerColors.textSecondary,
    fontSize: 13,
  );
  static const TextStyle metaMuted = TextStyle(
    color: RetrometerColors.textMuted,
    fontSize: 13,
  );
  static const TextStyle tileTime = TextStyle(
    color: RetrometerColors.textSecondary,
    fontSize: 14,
  );

  // Badges / pills.
  static const TextStyle badge = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.bold,
  );

  // Section labels inside sheets.
  static const TextStyle sectionLabel = TextStyle(
    color: RetrometerColors.primary,
    fontSize: 16,
  );
  static const TextStyle sheetTitle = TextStyle(
    color: RetrometerColors.textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.bold,
  );

  // Field rows.
  static const TextStyle fieldLabel = TextStyle(
    color: RetrometerColors.textSecondary,
    fontSize: 16,
  );
  static const TextStyle fieldLabelSmall = TextStyle(
    color: RetrometerColors.textSecondary,
    fontSize: 15,
  );
  static const TextStyle fieldInput = TextStyle(
    color: RetrometerColors.textPrimary,
    fontSize: 20,
  );
  static const TextStyle fieldInputSmall = TextStyle(
    color: RetrometerColors.textPrimary,
    fontSize: 18,
  );
  static const TextStyle fieldHint = TextStyle(
    color: RetrometerColors.hint,
  );

  // Empty states.
  static const TextStyle emptyTitle = TextStyle(
    color: RetrometerColors.textTertiary,
    fontSize: 16,
    height: 1.4,
  );
  static const TextStyle emptyTitleSmall = TextStyle(
    color: RetrometerColors.textTertiary,
    fontSize: 15,
    height: 1.4,
  );

  // Error / inline notice.
  static const TextStyle fieldError = TextStyle(
    color: RetrometerColors.danger,
    fontSize: 12,
  );

  // Guide.
  static const TextStyle guideSection = TextStyle(
    color: RetrometerColors.primary,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );
  static const TextStyle guideRow = TextStyle(
    color: RetrometerColors.textSecondary,
    fontSize: 15,
    height: 1.35,
  );
}

// ---------------------------------------------------------------------------
// ThemeData.
// ---------------------------------------------------------------------------

ThemeData retrometerTheme() {
  const colorScheme = ColorScheme.dark(
    primary: RetrometerColors.primary,
    onPrimary: RetrometerColors.onActionFill,
    secondary: RetrometerColors.secondary,
    surface: RetrometerColors.background,
    onSurface: RetrometerColors.textPrimary,
    error: RetrometerColors.danger,
    onError: RetrometerColors.textPrimary,
  );

  const fieldBorder = UnderlineInputBorder(
    borderSide: BorderSide(color: RetrometerColors.fieldBorder),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: RetrometerColors.background,
    colorScheme: colorScheme,
    canvasColor: RetrometerColors.background,

    // Refined AppBar: dark surface, no elevation, hairline bottom divider so
    // it reads as a header rather than a floating bar.
    appBarTheme: const AppBarTheme(
      backgroundColor: RetrometerColors.surface,
      foregroundColor: RetrometerColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: RetrometerColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        minimumSize: const Size.fromHeight(0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: RetrometerColors.startFill,
      foregroundColor: RetrometerColors.onActionFill,
      elevation: 2,
      shape: CircleBorder(),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: RetrometerColors.textSecondary,
        shape: const CircleBorder(),
      ),
    ),

    inputDecorationTheme: const InputDecorationTheme(
      labelStyle: RetrometerTextStyles.fieldLabel,
      hintStyle: RetrometerTextStyles.fieldHint,
      enabledBorder: fieldBorder,
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: RetrometerColors.primary, width: 1.5),
      ),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: RetrometerColors.sheet,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      showDragHandle: true,
      dragHandleColor: RetrometerColors.textFaint,
    ),

    dialogTheme: const DialogThemeData(
      backgroundColor: RetrometerColors.sheet,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      titleTextStyle: TextStyle(
        color: RetrometerColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      contentTextStyle: TextStyle(
        color: RetrometerColors.textSecondary,
        fontSize: 14,
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: RetrometerColors.divider,
      thickness: 1,
      space: 1,
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return RetrometerColors.primary;
        }
        return RetrometerColors.textTertiary;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return RetrometerColors.primary.withValues(alpha: 0.4);
        }
        return RetrometerColors.textFaint;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.transparent;
        return RetrometerColors.textFaint;
      }),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: RetrometerColors.primary,
    ),

    textTheme: Typography.whiteCupertino.copyWith(
      displayLarge: const TextStyle(
        fontWeight: FontWeight.bold,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      displayMedium: const TextStyle(
        fontWeight: FontWeight.bold,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: RetrometerColors.primary),
    ),
  );
}

// ---------------------------------------------------------------------------
// BuildContext helpers.
// ---------------------------------------------------------------------------

/// Convenience accessors. The palette and text styles are static namespaces
/// (`RetrometerColors`, `RetrometerTextStyles`); screens import them directly.
/// This extension is reserved for any future per-context lookups.
extension RetrometerContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
}