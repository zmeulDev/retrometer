import 'package:flutter/material.dart';

/// Centralized design system for Retrometer — a restomod rally cockpit theme
/// (warm charcoal night + warm bone day, amber LCD accent, stencil labels,
/// Roboto Mono digits). All screens read colors and text styles from here
/// instead of inlining `Colors.xxx` literals, so the palette/typography stays
/// consistent across iOS and Android and can be tuned in one place.
///
/// Two parallel surfaces expose the system:
/// - **Static namespaces** (`RetrometerColors`, `RetrometerTextStyles`,
///   `RetrometerRadii` …) hold the **dark** palette as `const` values. These
///   are used in `const` contexts (e.g. `const _PermStatus('…', col)`,
///   `const TextStyle(color: …)` defaults) and as the universal fallback.
/// - **`RetrometerPalette extends ThemeExtension`** + `RetrometerTypography`
///   carry the **mode-aware** (dark/light) values, read at runtime via
///   `context.colors` / `context.text` (with a `RetrometerPalette.dark()`
///   fallback when no theme extension is registered — e.g. bare-MaterialApp
///   test pumps). Dart forbids a static and instance field with the same name,
///   so the adaptive values live on a dedicated class rather than on
///   `RetrometerColors` itself.

// ---------------------------------------------------------------------------
// Palette — static dark namespace (source of truth for the dark values).
// ---------------------------------------------------------------------------

class RetrometerColors {
  const RetrometerColors._();

  // Surfaces — warm charcoal for night driving. Depth comes from the color
  // step between layers (background → surface → surfaceElevated), not from
  // borders, so panels read as stacked cards on a dashboard.
  static const Color background = Color(0xFF161210); // warm charcoal
  static const Color surface = Color(0xFF1D1916);
  static const Color surfaceElevated = Color(0xFF251F1A); // surface2
  static const Color surfaceHeader = Color(0xFF0C0A07); // LCD well background
  static const Color sheet = Color(0xFF221D18);

  // Brand accents — amber LCD as the primary instrument accent (retro rally),
  // warm amber for the "delay" state, red for danger.
  static const Color primary = Color(0xFFFF9B21); // amber LCD accent
  static const Color secondary = Color(0xFFE8B53F); // warn amber (Δ delay)
  static const Color danger = Color(0xFFE8533F); // alert red

  // Δ indicator band backgrounds + foregrounds. Backgrounds are deep tints so
  // the band reads as a zone; foregrounds stay vivid as the at-a-glance signal.
  // onTime = teal-green (calm), advance = red (flash), delay = amber (flash).
  static const Color onTimeBg = Color(0xFF0E3D2E); // dark teal
  static const Color advanceBg = Color(0xFF3A1410); // dark red
  static const Color delayBg = Color(0xFF3A2C0D); // dark amber
  static const Color onTimeFg = Color(0xFF34D399); // teal-green
  static const Color advanceFg = Color(0xFFE8533F); // red
  static const Color delayFg = Color(0xFFE8B53F); // amber

  // Stage status colors.
  static const Color running = Color(0xFF34D399); // teal-green (on-time)
  static const Color started = Color(0xFFA99D88); // ink-dim
  static const Color waiting = Color(0xFFE8B53F); // warn amber

  // Text on dark surfaces — warm ink scale.
  static const Color textPrimary = Color(0xFFEFE6D6); // ink
  static const Color textSecondary = Color(0xFFC9BDA5);
  static const Color textTertiary = Color(0xFFA99D88); // ink-dim
  static const Color textMuted = Color(0xFF6B6052); // ink-faint
  static const Color textFaint = Color(0xFF4F4337); // line-strong
  static const Color hint = Color(0xFF6B6052);

  // Lines & borders.
  static const Color divider = Color(0xFF3A3128); // line
  static const Color dividerStrong = Color(0xFF4F4337); // line-strong
  static const Color fieldBorder = Color(0xFF4F4337);
  static const Color scrim = Colors.black54;

  // Action button fills (START/STOP/RESET).
  static const Color startFill = Color(0xFFFF9B21); // amber
  static const Color stopFill = Color(0xFFE8533F); // red
  static const Color resetFill = Color(0xFF251F1A); // surfaceElevated
  static const Color onActionFill = Color(0xFF1A0F04); // accent-ink (near-black)

  // Materiality tokens (restomod details).
  static const Color signal = Color(0xFFE08612); // deeper amber for active tags
  static const Color lcdBg = Color(0xFF0C0A07); // LCD readout well
  static const Color accentInk = Color(0xFF1A0F04); // text on amber fills
  static const Color lcdSoft = Color(0x29FF9B21); // amber @ ~16% (LED on / press)
  static const Color labelPlate = Color(0xFF251F1A); // etched label plate fill
  static const Color labelInk = Color(0xFFA99D88); // etched label plate text
  static const Color warn = Color(0xFFE8B53F);

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
// Adaptive palette — ThemeExtension (dark / light).
// ---------------------------------------------------------------------------

/// Mode-aware palette. The dark instance mirrors [RetrometerColors] (the
/// static dark namespace); the light instance is the warm-bone day palette.
/// Read via `context.colors`; falls back to [dark] when no extension is
/// registered (e.g. a bare `MaterialApp(home: …)` test pump).
class RetrometerPalette extends ThemeExtension<RetrometerPalette> {
  const RetrometerPalette({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceHeader,
    required this.sheet,
    required this.primary,
    required this.secondary,
    required this.danger,
    required this.onTimeBg,
    required this.advanceBg,
    required this.delayBg,
    required this.onTimeFg,
    required this.advanceFg,
    required this.delayFg,
    required this.running,
    required this.started,
    required this.waiting,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textMuted,
    required this.textFaint,
    required this.hint,
    required this.divider,
    required this.dividerStrong,
    required this.fieldBorder,
    required this.scrim,
    required this.startFill,
    required this.stopFill,
    required this.resetFill,
    required this.onActionFill,
    required this.signal,
    required this.lcdBg,
    required this.accentInk,
    required this.lcdSoft,
    required this.labelPlate,
    required this.labelInk,
    required this.warn,
  });

  /// Dark palette — equals the [RetrometerColors] static namespace.
  const RetrometerPalette.dark()
      : this(
          background: RetrometerColors.background,
          surface: RetrometerColors.surface,
          surfaceElevated: RetrometerColors.surfaceElevated,
          surfaceHeader: RetrometerColors.surfaceHeader,
          sheet: RetrometerColors.sheet,
          primary: RetrometerColors.primary,
          secondary: RetrometerColors.secondary,
          danger: RetrometerColors.danger,
          onTimeBg: RetrometerColors.onTimeBg,
          advanceBg: RetrometerColors.advanceBg,
          delayBg: RetrometerColors.delayBg,
          onTimeFg: RetrometerColors.onTimeFg,
          advanceFg: RetrometerColors.advanceFg,
          delayFg: RetrometerColors.delayFg,
          running: RetrometerColors.running,
          started: RetrometerColors.started,
          waiting: RetrometerColors.waiting,
          textPrimary: RetrometerColors.textPrimary,
          textSecondary: RetrometerColors.textSecondary,
          textTertiary: RetrometerColors.textTertiary,
          textMuted: RetrometerColors.textMuted,
          textFaint: RetrometerColors.textFaint,
          hint: RetrometerColors.hint,
          divider: RetrometerColors.divider,
          dividerStrong: RetrometerColors.dividerStrong,
          fieldBorder: RetrometerColors.fieldBorder,
          scrim: RetrometerColors.scrim,
          startFill: RetrometerColors.startFill,
          stopFill: RetrometerColors.stopFill,
          resetFill: RetrometerColors.resetFill,
          onActionFill: RetrometerColors.onActionFill,
          signal: RetrometerColors.signal,
          lcdBg: RetrometerColors.lcdBg,
          accentInk: RetrometerColors.accentInk,
          lcdSoft: RetrometerColors.lcdSoft,
          labelPlate: RetrometerColors.labelPlate,
          labelInk: RetrometerColors.labelInk,
          warn: RetrometerColors.warn,
        );

  /// Light palette — warm bone, deep amber accents for sun legibility.
  const RetrometerPalette.light()
      : this(
          background: const Color(0xFFF1EAD9),
          surface: const Color(0xFFFBF6E9),
          surfaceElevated: const Color(0xFFECE3CD),
          surfaceHeader: const Color(0xFFE7DCC2),
          sheet: const Color(0xFFFBF6E9),
          primary: const Color(0xFFB8620A),
          secondary: const Color(0xFF8A6510),
          danger: const Color(0xFFB8392B),
          onTimeBg: const Color(0xFFD8F0E4),
          advanceBg: const Color(0xFFF6DCD8),
          delayBg: const Color(0xFFF3E6C4),
          onTimeFg: const Color(0xFF1F8A5C),
          advanceFg: const Color(0xFFB8392B),
          delayFg: const Color(0xFF8A6510),
          running: const Color(0xFF1F8A5C),
          started: const Color(0xFF6F6452),
          waiting: const Color(0xFF8A6510),
          textPrimary: const Color(0xFF221B12),
          textSecondary: const Color(0xFF4A3F30),
          textTertiary: const Color(0xFF6F6452),
          textMuted: const Color(0xFF8A7F6B),
          textFaint: const Color(0xFFBDAE90),
          hint: const Color(0xFF8A7F6B),
          divider: const Color(0xFFD8CCB2),
          dividerStrong: const Color(0xFFBDAE90),
          fieldBorder: const Color(0xFFBDAE90),
          scrim: Colors.black54,
          startFill: const Color(0xFFC2700F),
          stopFill: const Color(0xFFB8392B),
          resetFill: const Color(0xFFECE3CD),
          onActionFill: const Color(0xFF1A0F04),
          signal: const Color(0xFFC2700F),
          lcdBg: const Color(0xFFE7DCC2),
          accentInk: const Color(0xFF1A0F04),
          lcdSoft: const Color(0x29C2700F),
          labelPlate: const Color(0xFFECE3CD),
          labelInk: const Color(0xFF6F6452),
          warn: const Color(0xFF8A6510),
        );

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceHeader;
  final Color sheet;
  final Color primary;
  final Color secondary;
  final Color danger;
  final Color onTimeBg;
  final Color advanceBg;
  final Color delayBg;
  final Color onTimeFg;
  final Color advanceFg;
  final Color delayFg;
  final Color running;
  final Color started;
  final Color waiting;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textMuted;
  final Color textFaint;
  final Color hint;
  final Color divider;
  final Color dividerStrong;
  final Color fieldBorder;
  final Color scrim;
  final Color startFill;
  final Color stopFill;
  final Color resetFill;
  final Color onActionFill;
  final Color signal;
  final Color lcdBg;
  final Color accentInk;
  final Color lcdSoft;
  final Color labelPlate;
  final Color labelInk;
  final Color warn;

  /// A translucent fill + matching border for status/standing pills, tinted by
  /// [color] — the instance twin of [RetrometerColors.pillDecoration].
  BoxDecoration pillDecoration(Color color, {double radius = 6}) => BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      );

  @override
  RetrometerPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceHeader,
    Color? sheet,
    Color? primary,
    Color? secondary,
    Color? danger,
    Color? onTimeBg,
    Color? advanceBg,
    Color? delayBg,
    Color? onTimeFg,
    Color? advanceFg,
    Color? delayFg,
    Color? running,
    Color? started,
    Color? waiting,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textMuted,
    Color? textFaint,
    Color? hint,
    Color? divider,
    Color? dividerStrong,
    Color? fieldBorder,
    Color? scrim,
    Color? startFill,
    Color? stopFill,
    Color? resetFill,
    Color? onActionFill,
    Color? signal,
    Color? lcdBg,
    Color? accentInk,
    Color? lcdSoft,
    Color? labelPlate,
    Color? labelInk,
    Color? warn,
  }) =>
      RetrometerPalette(
        background: background ?? this.background,
        surface: surface ?? this.surface,
        surfaceElevated: surfaceElevated ?? this.surfaceElevated,
        surfaceHeader: surfaceHeader ?? this.surfaceHeader,
        sheet: sheet ?? this.sheet,
        primary: primary ?? this.primary,
        secondary: secondary ?? this.secondary,
        danger: danger ?? this.danger,
        onTimeBg: onTimeBg ?? this.onTimeBg,
        advanceBg: advanceBg ?? this.advanceBg,
        delayBg: delayBg ?? this.delayBg,
        onTimeFg: onTimeFg ?? this.onTimeFg,
        advanceFg: advanceFg ?? this.advanceFg,
        delayFg: delayFg ?? this.delayFg,
        running: running ?? this.running,
        started: started ?? this.started,
        waiting: waiting ?? this.waiting,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textTertiary: textTertiary ?? this.textTertiary,
        textMuted: textMuted ?? this.textMuted,
        textFaint: textFaint ?? this.textFaint,
        hint: hint ?? this.hint,
        divider: divider ?? this.divider,
        dividerStrong: dividerStrong ?? this.dividerStrong,
        fieldBorder: fieldBorder ?? this.fieldBorder,
        scrim: scrim ?? this.scrim,
        startFill: startFill ?? this.startFill,
        stopFill: stopFill ?? this.stopFill,
        resetFill: resetFill ?? this.resetFill,
        onActionFill: onActionFill ?? this.onActionFill,
        signal: signal ?? this.signal,
        lcdBg: lcdBg ?? this.lcdBg,
        accentInk: accentInk ?? this.accentInk,
        lcdSoft: lcdSoft ?? this.lcdSoft,
        labelPlate: labelPlate ?? this.labelPlate,
        labelInk: labelInk ?? this.labelInk,
        warn: warn ?? this.warn,
      );

  @override
  RetrometerPalette lerp(RetrometerPalette? other, double t) {
    if (other == null) return this;
    return RetrometerPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceHeader: Color.lerp(surfaceHeader, other.surfaceHeader, t)!,
      sheet: Color.lerp(sheet, other.sheet, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onTimeBg: Color.lerp(onTimeBg, other.onTimeBg, t)!,
      advanceBg: Color.lerp(advanceBg, other.advanceBg, t)!,
      delayBg: Color.lerp(delayBg, other.delayBg, t)!,
      onTimeFg: Color.lerp(onTimeFg, other.onTimeFg, t)!,
      advanceFg: Color.lerp(advanceFg, other.advanceFg, t)!,
      delayFg: Color.lerp(delayFg, other.delayFg, t)!,
      running: Color.lerp(running, other.running, t)!,
      started: Color.lerp(started, other.started, t)!,
      waiting: Color.lerp(waiting, other.waiting, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      hint: Color.lerp(hint, other.hint, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      dividerStrong: Color.lerp(dividerStrong, other.dividerStrong, t)!,
      fieldBorder: Color.lerp(fieldBorder, other.fieldBorder, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      startFill: Color.lerp(startFill, other.startFill, t)!,
      stopFill: Color.lerp(stopFill, other.stopFill, t)!,
      resetFill: Color.lerp(resetFill, other.resetFill, t)!,
      onActionFill: Color.lerp(onActionFill, other.onActionFill, t)!,
      signal: Color.lerp(signal, other.signal, t)!,
      lcdBg: Color.lerp(lcdBg, other.lcdBg, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      lcdSoft: Color.lerp(lcdSoft, other.lcdSoft, t)!,
      labelPlate: Color.lerp(labelPlate, other.labelPlate, t)!,
      labelInk: Color.lerp(labelInk, other.labelInk, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
    );
  }
}

// ---------------------------------------------------------------------------
// Radii.
// ---------------------------------------------------------------------------

/// Named corner-radii for the recurring surface shapes. Each token's value
/// EQUALS the literal it replaces — adding a token here is a zero-behavior
/// change. Only radii that actually repeat in the codebase get a token;
/// one-off literals stay inline.
class RetrometerRadii {
  const RetrometerRadii._();

  static const double pill = 6;
  static const double field = 8;
  static const double chip = 10;
  static const double control = 12;
  static const double card = 16;
  static const double sheet = 20;
  static const double tile = 20;
  static const double band = 28;
  static const double appIcon = 22;
}

// ---------------------------------------------------------------------------
// Spacing / icon sizes / durations.
// ---------------------------------------------------------------------------

/// Named spacing scale for the recurring paddings.
class RetrometerSpacing {
  const RetrometerSpacing._();

  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s24 = 24;
  static const double s32 = 32;
}

/// Named icon-size scale for the recurring icons.
class RetrometerIconSizes {
  const RetrometerIconSizes._();

  static const double sm = 15;
  static const double md = 18;
  static const double lg = 22;
  static const double xl = 46;
  static const double empty = 56;
}

/// Named animation durations.
class RetrometerDurations {
  const RetrometerDurations._();

  static const Duration bandTransition = Duration(milliseconds: 200);
  static const Duration deltaFlash = Duration(milliseconds: 700);
  static const Duration overSpeedPulse = Duration(milliseconds: 500);
  static const Duration ledPulse = Duration(milliseconds: 1100);
}

// ---------------------------------------------------------------------------
// Typography — static dark namespace (font families + dark palette).
// ---------------------------------------------------------------------------

/// Font families bundled as assets (see pubspec). Digits use Roboto Mono
/// (fixed-width + tabular figures, has `+ - . :`), labels/titles use Saira
/// Stencil One (restomod signature, Latin Extended for RO diacritics), and
/// body/UI use Roboto. All three ship under the SIL Open Font License 1.1.
class _Fonts {
  const _Fonts._();
  static const String mono = 'RobotoMono';
  static const String stencil = 'SairaStencil';
  static const String body = 'Roboto';
}

/// Named text styles used across screens. The static members carry the dark
/// palette (used in `const` contexts and as the universal fallback); for
/// mode-aware styles read `context.text.<name>` instead.
class RetrometerTextStyles {
  const RetrometerTextStyles._();

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  // Cockpit Δ zone.
  static TextStyle bandLabel(Color c) => TextStyle(
        color: c,
        fontFamily: _Fonts.stencil,
        fontSize: 44,
        fontWeight: FontWeight.bold,
        letterSpacing: 4,
      );
  static const TextStyle deltaNumber = TextStyle(
    fontFamily: _Fonts.mono,
    color: RetrometerColors.textPrimary,
    fontSize: 180,
    fontWeight: FontWeight.bold,
    fontFeatures: _tabular,
    height: 1,
  );
  static TextStyle deltaNumberColored(Color c) =>
      deltaNumber.copyWith(color: c);
  static const TextStyle deltaSubtitle = TextStyle(
    color: RetrometerColors.textSecondary,
    fontFamily: _Fonts.body,
    fontSize: 22,
  );
  static const TextStyle deltaStageName = TextStyle(
    color: RetrometerColors.primary, // amber — stage identity
    fontFamily: _Fonts.stencil,
    fontSize: 22,
    fontWeight: FontWeight.bold,
    fontFeatures: _tabular,
  );

  // Trip-meter.
  static const TextStyle distanceNumber = TextStyle(
    color: RetrometerColors.textPrimary,
    fontFamily: _Fonts.mono,
    fontSize: 120,
    fontWeight: FontWeight.bold,
    fontFeatures: _tabular,
    height: 1,
  );
  static const TextStyle distanceUnit = TextStyle(
    color: RetrometerColors.textTertiary,
    fontFamily: _Fonts.stencil,
    fontSize: 28,
    letterSpacing: 1.2,
  );
  static const TextStyle adjustSign = TextStyle(
    color: RetrometerColors.textPrimary,
    fontFamily: _Fonts.mono,
    fontSize: 72,
    fontWeight: FontWeight.bold,
    height: 1,
  );
  static const TextStyle adjustAmount = TextStyle(
    color: RetrometerColors.textSecondary,
    fontFamily: _Fonts.stencil,
    fontSize: 20,
    letterSpacing: 0.8,
  );
  static const TextStyle adjustLong = TextStyle(
    color: RetrometerColors.textMuted,
    fontFamily: _Fonts.body,
    fontSize: 13,
  );

  // Top bar.
  static TextStyle topBarText({bool compact = false}) => TextStyle(
        color: RetrometerColors.textPrimary,
        fontFamily: _Fonts.body,
        fontSize: compact ? 15 : 18,
        fontWeight: FontWeight.bold,
        fontFeatures: _tabular,
      );
  static TextStyle competitionRow = TextStyle(
    color: RetrometerColors.primary,
    fontFamily: _Fonts.stencil,
    fontSize: 13,
    letterSpacing: 0.6,
  );

  /// The big elapsed-time readout in the cockpit top bar. Hoisted here from
  /// `cockpit_top_bar.dart` so it is `const` and lives with the rest of the
  /// type system.
  static const TextStyle topBarElapsed = TextStyle(
    color: RetrometerColors.primary, // amber LCD
    fontFamily: _Fonts.mono,
    fontSize: 30,
    fontWeight: FontWeight.bold,
    fontFeatures: _tabular,
    height: 1,
  );

  // Control buttons (START/STOP/RESET).
  static const TextStyle controlLabel = TextStyle(
    color: RetrometerColors.onActionFill,
    fontFamily: _Fonts.body,
    fontWeight: FontWeight.bold,
    fontSize: 14,
    letterSpacing: 0.6,
  );

  // Over-speed alert.
  static const TextStyle overSpeed = TextStyle(
    color: RetrometerColors.danger,
    fontFamily: _Fonts.stencil,
    fontSize: 22,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.2,
  );

  // Tiles / list.
  static const TextStyle tileTitle = TextStyle(
    color: RetrometerColors.textPrimary,
    fontFamily: _Fonts.stencil,
    fontSize: 18,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.4,
  );
  static const TextStyle headerTitle = TextStyle(
    color: RetrometerColors.textPrimary,
    fontFamily: _Fonts.stencil,
    fontSize: 20,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.4,
  );
  static const TextStyle meta = TextStyle(
    color: RetrometerColors.textTertiary,
    fontFamily: _Fonts.body,
    fontSize: 13,
  );
  static const TextStyle metaStrong = TextStyle(
    color: RetrometerColors.textSecondary,
    fontFamily: _Fonts.body,
    fontSize: 13,
  );
  static const TextStyle metaMuted = TextStyle(
    color: RetrometerColors.textMuted,
    fontFamily: _Fonts.body,
    fontSize: 13,
  );
  static const TextStyle tileTime = TextStyle(
    color: RetrometerColors.textSecondary,
    fontFamily: _Fonts.body,
    fontSize: 14,
  );

  // Badges / pills.
  static const TextStyle badge = TextStyle(
    fontFamily: _Fonts.stencil,
    fontSize: 11,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.8,
  );

  // Section labels inside sheets.
  static const TextStyle sectionLabel = TextStyle(
    color: RetrometerColors.primary,
    fontFamily: _Fonts.stencil,
    fontSize: 16,
    letterSpacing: 0.8,
  );
  static const TextStyle sheetTitle = TextStyle(
    color: RetrometerColors.textPrimary,
    fontFamily: _Fonts.stencil,
    fontSize: 22,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.4,
  );

  // Field rows.
  static const TextStyle fieldLabel = TextStyle(
    color: RetrometerColors.textSecondary,
    fontFamily: _Fonts.body,
    fontSize: 16,
  );
  static const TextStyle fieldLabelSmall = TextStyle(
    color: RetrometerColors.textSecondary,
    fontFamily: _Fonts.body,
    fontSize: 15,
  );
  static const TextStyle fieldInput = TextStyle(
    color: RetrometerColors.textPrimary,
    fontFamily: _Fonts.body,
    fontSize: 20,
  );
  static const TextStyle fieldInputSmall = TextStyle(
    color: RetrometerColors.textPrimary,
    fontFamily: _Fonts.body,
    fontSize: 18,
  );
  static const TextStyle fieldHint = TextStyle(
    color: RetrometerColors.hint,
    fontFamily: _Fonts.body,
  );

  // Empty states.
  static const TextStyle emptyTitle = TextStyle(
    color: RetrometerColors.textTertiary,
    fontFamily: _Fonts.body,
    fontSize: 16,
    height: 1.4,
  );
  static const TextStyle emptyTitleSmall = TextStyle(
    color: RetrometerColors.textTertiary,
    fontFamily: _Fonts.body,
    fontSize: 15,
    height: 1.4,
  );

  // Error / inline notice.
  static const TextStyle fieldError = TextStyle(
    color: RetrometerColors.danger,
    fontFamily: _Fonts.body,
    fontSize: 12,
  );

  // Guide.
  static const TextStyle guideSection = TextStyle(
    color: RetrometerColors.primary,
    fontFamily: _Fonts.stencil,
    fontSize: 18,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.6,
  );
  static const TextStyle guideRow = TextStyle(
    color: RetrometerColors.textSecondary,
    fontFamily: _Fonts.body,
    fontSize: 15,
    height: 1.35,
  );
}

// ---------------------------------------------------------------------------
// Adaptive typography — built from a RetrometerPalette.
// ---------------------------------------------------------------------------

/// Mode-aware text styles. Read via `context.text`; each getter builds the
/// same style as its [RetrometerTextStyles] twin but with the active palette's
/// colors. The static namespace remains the `const` / dark fallback.
class RetrometerTypography {
  const RetrometerTypography(this.colors);

  final RetrometerPalette colors;

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  // Cockpit Δ zone.
  TextStyle bandLabel(Color c) => TextStyle(
        color: c,
        fontFamily: _Fonts.stencil,
        fontSize: 44,
        fontWeight: FontWeight.bold,
        letterSpacing: 4,
      );
  TextStyle get deltaNumber => TextStyle(
        fontFamily: _Fonts.mono,
        color: colors.textPrimary,
        fontSize: 180,
        fontWeight: FontWeight.bold,
        fontFeatures: _tabular,
        height: 1,
      );
  TextStyle deltaNumberColored(Color c) => deltaNumber.copyWith(color: c);
  TextStyle get deltaSubtitle => TextStyle(
        color: colors.textSecondary,
        fontFamily: _Fonts.body,
        fontSize: 32,
      );
  TextStyle get deltaStageName => TextStyle(
        color: colors.primary,
        fontFamily: _Fonts.stencil,
        fontSize: 32,
        fontWeight: FontWeight.bold,
        fontFeatures: _tabular,
      );

  // Trip-meter.
  TextStyle get distanceNumber => TextStyle(
        color: colors.textPrimary,
        fontFamily: _Fonts.mono,
        fontSize: 120,
        fontWeight: FontWeight.bold,
        fontFeatures: _tabular,
        height: 1,
      );
  TextStyle get distanceUnit => TextStyle(
        color: colors.textTertiary,
        fontFamily: _Fonts.stencil,
        fontSize: 28,
        letterSpacing: 1.2,
      );
  TextStyle get adjustSign => TextStyle(
        color: colors.textPrimary,
        fontFamily: _Fonts.mono,
        fontSize: 72,
        fontWeight: FontWeight.bold,
        height: 1,
      );
  TextStyle get adjustAmount => TextStyle(
        color: colors.textSecondary,
        fontFamily: _Fonts.stencil,
        fontSize: 20,
        letterSpacing: 0.8,
      );
  TextStyle get adjustLong => TextStyle(
        color: colors.textMuted,
        fontFamily: _Fonts.body,
        fontSize: 13,
      );

  // Top bar.
  TextStyle topBarText({bool compact = false}) => TextStyle(
        color: colors.textPrimary,
        fontFamily: _Fonts.body,
        fontSize: compact ? 15 : 18,
        fontWeight: FontWeight.bold,
        fontFeatures: _tabular,
      );
  TextStyle get competitionRow => TextStyle(
        color: colors.primary,
        fontFamily: _Fonts.stencil,
        fontSize: 13,
        letterSpacing: 0.6,
      );
  TextStyle get topBarElapsed => TextStyle(
        color: colors.primary,
        fontFamily: _Fonts.mono,
        fontSize: 30,
        fontWeight: FontWeight.bold,
        fontFeatures: _tabular,
        height: 1,
      );

  // Control buttons.
  TextStyle get controlLabel => TextStyle(
        color: colors.onActionFill,
        fontFamily: _Fonts.body,
        fontWeight: FontWeight.bold,
        fontSize: 14,
        letterSpacing: 0.6,
      );

  // Over-speed alert.
  TextStyle get overSpeed => TextStyle(
        color: colors.danger,
        fontFamily: _Fonts.stencil,
        fontSize: 22,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      );

  // Tiles / list.
  TextStyle get tileTitle => TextStyle(
        color: colors.textPrimary,
        fontFamily: _Fonts.stencil,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.4,
      );
  TextStyle get headerTitle => TextStyle(
        color: colors.textPrimary,
        fontFamily: _Fonts.stencil,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.4,
      );
  TextStyle get meta => TextStyle(
        color: colors.textTertiary,
        fontFamily: _Fonts.body,
        fontSize: 13,
      );
  TextStyle get metaStrong => TextStyle(
        color: colors.textSecondary,
        fontFamily: _Fonts.body,
        fontSize: 13,
      );
  TextStyle get metaMuted => TextStyle(
        color: colors.textMuted,
        fontFamily: _Fonts.body,
        fontSize: 13,
      );
  TextStyle get tileTime => TextStyle(
        color: colors.textSecondary,
        fontFamily: _Fonts.body,
        fontSize: 14,
      );

  // Badges / pills.
  TextStyle get badge => TextStyle(
        fontFamily: _Fonts.stencil,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
      );

  // Section labels inside sheets.
  TextStyle get sectionLabel => TextStyle(
        color: colors.primary,
        fontFamily: _Fonts.stencil,
        fontSize: 16,
        letterSpacing: 0.8,
      );
  TextStyle get sheetTitle => TextStyle(
        color: colors.textPrimary,
        fontFamily: _Fonts.stencil,
        fontSize: 22,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.4,
      );

  // Field rows.
  TextStyle get fieldLabel => TextStyle(
        color: colors.textSecondary,
        fontFamily: _Fonts.body,
        fontSize: 16,
      );
  TextStyle get fieldLabelSmall => TextStyle(
        color: colors.textSecondary,
        fontFamily: _Fonts.body,
        fontSize: 15,
      );
  TextStyle get fieldInput => TextStyle(
        color: colors.textPrimary,
        fontFamily: _Fonts.body,
        fontSize: 20,
      );
  TextStyle get fieldInputSmall => TextStyle(
        color: colors.textPrimary,
        fontFamily: _Fonts.body,
        fontSize: 18,
      );
  TextStyle get fieldHint => TextStyle(
        color: colors.hint,
        fontFamily: _Fonts.body,
      );

  // Empty states.
  TextStyle get emptyTitle => TextStyle(
        color: colors.textTertiary,
        fontFamily: _Fonts.body,
        fontSize: 16,
        height: 1.4,
      );
  TextStyle get emptyTitleSmall => TextStyle(
        color: colors.textTertiary,
        fontFamily: _Fonts.body,
        fontSize: 15,
        height: 1.4,
      );

  // Error / inline notice.
  TextStyle get fieldError => TextStyle(
        color: colors.danger,
        fontFamily: _Fonts.body,
        fontSize: 12,
      );

  // Guide.
  TextStyle get guideSection => TextStyle(
        color: colors.primary,
        fontFamily: _Fonts.stencil,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.6,
      );
  TextStyle get guideRow => TextStyle(
        color: colors.textSecondary,
        fontFamily: _Fonts.body,
        fontSize: 15,
        height: 1.35,
      );
}

// ---------------------------------------------------------------------------
// ThemeData.
// ---------------------------------------------------------------------------

ThemeData retrometerTheme() => _buildTheme(
      brightness: Brightness.dark,
      palette: const RetrometerPalette.dark(),
    );

ThemeData retrometerLightTheme() => _buildTheme(
      brightness: Brightness.light,
      palette: const RetrometerPalette.light(),
    );

ThemeData _buildTheme({
  required Brightness brightness,
  required RetrometerPalette palette,
}) {
  final colorScheme = (brightness == Brightness.dark
          ? const ColorScheme.dark()
          : const ColorScheme.light())
      .copyWith(
        primary: palette.primary,
        onPrimary: palette.accentInk,
        secondary: palette.secondary,
        surface: palette.background,
        onSurface: palette.textPrimary,
        error: palette.danger,
        onError: palette.textPrimary,
      );

  final fieldBorder = UnderlineInputBorder(
    borderSide: BorderSide(color: palette.fieldBorder),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: palette.background,
    colorScheme: colorScheme,
    canvasColor: palette.background,
    extensions: [palette],

    // Refined AppBar: surface, no elevation, hairline bottom divider so it
    // reads as a header rather than a floating bar.
    appBarTheme: AppBarTheme(
      backgroundColor: palette.surface,
      foregroundColor: palette.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: palette.textPrimary,
        fontFamily: _Fonts.stencil,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        minimumSize: const Size.fromHeight(0),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RetrometerRadii.control)),
        textStyle: TextStyle(
          fontFamily: _Fonts.body,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: palette.startFill,
      foregroundColor: palette.onActionFill,
      elevation: 2,
      shape: const CircleBorder(),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: palette.textSecondary,
        shape: const CircleBorder(),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      labelStyle: TextStyle(
        color: palette.textSecondary,
        fontFamily: _Fonts.body,
        fontSize: 16,
      ),
      hintStyle: TextStyle(color: palette.hint, fontFamily: _Fonts.body),
      enabledBorder: fieldBorder,
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: palette.primary, width: 1.5),
      ),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.sheet,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      showDragHandle: true,
      dragHandleColor: palette.textFaint,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: palette.sheet,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      titleTextStyle: TextStyle(
        color: palette.textPrimary,
        fontFamily: _Fonts.stencil,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.4,
      ),
      contentTextStyle: TextStyle(
        color: palette.textSecondary,
        fontFamily: _Fonts.body,
        fontSize: 14,
      ),
    ),

    dividerTheme: DividerThemeData(
      color: palette.divider,
      thickness: 1,
      space: 1,
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return palette.primary;
        return palette.textTertiary;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return palette.primary.withValues(alpha: 0.4);
        }
        return palette.textFaint;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.transparent;
        return palette.textFaint;
      }),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(color: palette.primary),

    textTheme: (brightness == Brightness.dark
            ? Typography.whiteCupertino
            : Typography.blackCupertino)
        .copyWith(
          displayLarge: TextStyle(
            fontWeight: FontWeight.bold,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          displayMedium: TextStyle(
            fontWeight: FontWeight.bold,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: palette.primary),
    ),
  );
}

// ---------------------------------------------------------------------------
// BuildContext helpers.
// ---------------------------------------------------------------------------

/// Convenience accessors. `colors` / `text` read the mode-aware
/// [RetrometerPalette] (with a `dark()` fallback when no extension is
/// registered — e.g. a bare `MaterialApp(home: …)` test pump, which never
/// crashes). The static namespaces (`RetrometerColors`, `RetrometerTextStyles`)
/// remain importable for `const` contexts.
extension RetrometerContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Mode-aware palette; falls back to the dark palette when the theme has no
  /// `RetrometerPalette` extension (so bare-MaterialApp test pumps stay green).
  RetrometerPalette get colors =>
      Theme.of(this).extension<RetrometerPalette>() ?? const RetrometerPalette.dark();

  /// Mode-aware typography, derived from the active palette.
  RetrometerTypography get text => RetrometerTypography(colors);
}