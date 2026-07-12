import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  EQUINOX-BR06  –  Golden Ops Design Language  (v8.0 — full theme fix)
//
//  Changes from v7.1:
//  • Added AppPalette.severe + severeGlow (5th flood-level colour)
//  • Fixed _light theme navBg (was abyss0 — now white-surface dark bar)
//  • Replaced all withOpacity() → withValues(alpha:) throughout
//  • Added RiverColors.severe field + getter riverSevere
//  • Exposed glassMorph() as a method on RiverColors (theme-aware)
//  • Hardened _buildTheme: FilledButton, Tooltip, SnackBar themed
//  • RiverTheme wrapper: forwards both theme + darkTheme for animated switch
// ─────────────────────────────────────────────────────────────────────────────

class AppPalette {
  AppPalette._();

  // ── Dark (Abyss / Golden) backgrounds ──────────────────────────────────────
  static const abyss0 = Color(0xFF0F0A00);
  static const abyss1 = Color(0xFF1A1000);
  static const abyss2 = Color(0xFF251800);
  static const abyss3 = Color(0xFF312200);
  static const abyss4 = Color(0xFF3D2C00);
  static const abyssStroke = Color(0xFF5A4000);
  static const abyssGlass = Color(0xCC251800);

  // ── Sunset ─────────────────────────────────────────────────────────────────
  static const sunset0 = Color(0xFF12000A);
  static const sunset1 = Color(0xFF1F0510);
  static const sunset2 = Color(0xFF2E0C1A);
  static const sunset3 = Color(0xFF3D1525);
  static const sunset4 = Color(0xFF4F2030);
  static const sunsetStroke = Color(0xFF8B3A50);
  static const sunsetAccent = Color(0xFFFF6B35);
  static const sunsetGold = Color(0xFFFFAA00);

  // ── Ocean ──────────────────────────────────────────────────────────────────
  static const ocean0 = Color(0xFF00060F);
  static const ocean1 = Color(0xFF000D1A);
  static const ocean2 = Color(0xFF001628);
  static const ocean3 = Color(0xFF002038);
  static const ocean4 = Color(0xFF002B4A);
  static const oceanStroke = Color(0xFF00456E);
  static const oceanAccent = Color(0xFF00C6FF);
  static const oceanGlow = Color(0x4400C6FF);

  // ── Light ──────────────────────────────────────────────────────────────────
  static const light0 = Color(0xFFFFF8E7);
  static const light1 = Color(0xFFFFF3CC);
  static const light2 = Color(0xFFFFE999);
  static const lightStroke = Color(0xFFE8C84A);

  // ── Navy aliases ───────────────────────────────────────────────────────────
  static const navy0 = abyss0;
  static const navy1 = abyss1;
  static const navy2 = abyss2;
  static const navy3 = abyss3;
  static const navy4 = abyss4;
  static const navyStroke = abyssStroke;
  static const navyGlass = abyssGlass;

  // ── Accent / Gold ──────────────────────────────────────────────────────────
  static const gold = Color(0xFFFFB800);
  static const goldLight = Color(0xFFFFD966);
  static const goldDark = Color(0xFFB07800);
  static const goldGlow = Color(0x55FFB800);
  static const goldGlow2 = Color(0x22FFB800);
  static const goldDim = Color(0xFF7A5200);

  // ── Cyan ───────────────────────────────────────────────────────────────────
  static const cyan = Color(0xFF00C6FF);
  static const cyanDark = Color(0xFF007FA8);
  static const cyanGlow = Color(0x4400C6FF);
  static const cyanDim = Color(0xFF005F80);
  static const cyanGlow2 = Color(0x1A00C6FF);

  // ── Amber ──────────────────────────────────────────────────────────────────
  static const amber = Color(0xFFFFB800);
  static const amberLight = Color(0xFFFFD966);
  static const amberDim = Color(0xFF7A5200);

  // ── Semantic flood-level colours (5 levels) ────────────────────────────────
  static const safe = Color(0xFF10E88A);
  static const warning = Color(0xFFFFA520);
  static const severe = Color(0xFFFF6600); // ← NEW between warning & danger
  static const danger = Color(0xFFFF5500);
  static const critical = Color(0xFFFF1A44);

  static const safeGlow = Color(0x2810E88A);
  static const warnGlow = Color(0x28FFA520);
  static const severeGlow = Color(0x28FF6600); // ← NEW
  static const dangerGlow = Color(0x28FF5500);
  static const critGlow = Color(0x28FF1A44);

  // ── Text ───────────────────────────────────────────────────────────────────
  static const textWhite = Color(0xFFFFF8E7);
  static const textGrey = Color(0xFF9A8060);
  static const textDim = Color(0xFF4A3410);

  // ── Gradients & Decorations ────────────────────────────────────────────────
  static const LinearGradient abyssGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [abyss1, abyss3],
  );
  static const LinearGradient navyGradient = abyssGradient;

  static BoxDecoration scaffoldDecoration() => const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.0, -0.6),
          radius: 1.1,
          colors: [Color(0x33FFB800), Color(0xFF0F0A00)],
        ),
      );

  static LinearGradient glowGradient(Color c) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          c.withValues(alpha: 0.20),
          c.withValues(alpha: 0.04),
        ],
      );

  static List<BoxShadow> glowShadow(Color c, {double blur = 20}) => [
        BoxShadow(
          color: c.withValues(alpha: 0.28),
          blurRadius: blur,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: c.withValues(alpha: 0.10),
          blurRadius: blur * 2,
          spreadRadius: 2,
        ),
      ];

  /// Glass-morphism decoration — NOTE: prefer RiverColors.glassMorph() so the
  /// bg colour comes from the active theme, not a hardcoded abyss tone.
  static BoxDecoration glassMorph({
    Color borderColor = AppPalette.abyssStroke,
    double radius = 20,
    Color? bg,
  }) =>
      BoxDecoration(
        color: bg ?? AppPalette.abyssGlass,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.50),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      );

  /// Maps a flood-alert level string to the correct palette colour.
  static Color statusColor(String level) {
    switch (level.toUpperCase()) {
      case 'SAFE':
        return safe;
      case 'WARNING':
        return warning;
      case 'SEVERE':
        return severe;
      case 'DANGER':
        return danger;
      case 'CRITICAL':
        return critical;
      default:
        return textGrey;
    }
  }

  /// Maps a flood-alert level to its glow colour.
  static Color statusGlow(String level) {
    switch (level.toUpperCase()) {
      case 'SAFE':
        return safeGlow;
      case 'WARNING':
        return warnGlow;
      case 'SEVERE':
        return severeGlow;
      case 'DANGER':
        return dangerGlow;
      case 'CRITICAL':
        return critGlow;
      default:
        return Colors.transparent;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RiverColors  –  ThemeExtension carrying every design token
// ─────────────────────────────────────────────────────────────────────────────

class RiverColors extends ThemeExtension<RiverColors> {
  const RiverColors({
    required this.riverNormal,
    required this.riverWarning,
    required this.riverSevere,
    required this.riverDanger,
    required this.riverCritical,
    required this.riverSurface,
    required this.riverGlow,
    required this.cardBg,
    required this.cardBgElevated,
    required this.chipBg,
    required this.stroke,
    required this.textPrimary,
    required this.textSecondary,
    required this.sparklineColor,
    required this.accent,
    required this.accentGlow,
    required this.metricColor,
    required this.navBg,
    required this.navActive,
    required this.navInactive,
    required this.scaffoldBg,
  });

  final Color riverNormal;
  final Color riverWarning;
  final Color riverSevere; // ← NEW
  final Color riverDanger;
  final Color riverCritical;
  final Color riverSurface;
  final Color riverGlow;
  final Color cardBg;
  final Color cardBgElevated;
  final Color chipBg;
  final Color stroke;
  final Color textPrimary;
  final Color textSecondary;
  final Color sparklineColor;
  final Color accent;
  final Color accentGlow;
  final Color metricColor;
  final Color navBg;
  final Color navActive;
  final Color navInactive;
  final Color scaffoldBg;

  // ── Convenience aliases ────────────────────────────────────────────────────
  Color get bgBase => cardBg;
  Color get bg => scaffoldBg;
  Color get divider => stroke;
  Color get danger => riverDanger;
  Color get severe => riverSevere;
  Color get safe => riverNormal;
  Color get warning => riverWarning;
  Color get critical => riverCritical;

  // ── Theme-aware glassMorph decoration ──────────────────────────────────────
  BoxDecoration glassMorph({double radius = 20}) => BoxDecoration(
        color: cardBg.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: stroke.withValues(alpha: 0.6), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.40),
            blurRadius: 28,
            offset: const Offset(0, 6),
          ),
        ],
      );

  /// Returns the semantic colour for any flood alert level string.
  Color statusColor(String level) => AppPalette.statusColor(level);

  // ── Lookup ─────────────────────────────────────────────────────────────────
  static RiverColors of(BuildContext context) =>
      Theme.of(context).extension<RiverColors>() ?? _golden;

  // ── Preset: Golden (dark default) ─────────────────────────────────────────
  static const RiverColors _golden = RiverColors(
    riverNormal: AppPalette.safe,
    riverWarning: AppPalette.warning,
    riverSevere: AppPalette.severe,
    riverDanger: AppPalette.danger,
    riverCritical: AppPalette.critical,
    riverSurface: AppPalette.abyss2,
    riverGlow: AppPalette.goldGlow,
    cardBg: AppPalette.abyss2,
    cardBgElevated: AppPalette.abyss3,
    chipBg: AppPalette.abyss4,
    stroke: AppPalette.abyssStroke,
    textPrimary: AppPalette.textWhite,
    textSecondary: AppPalette.textGrey,
    sparklineColor: AppPalette.gold,
    accent: AppPalette.gold,
    accentGlow: AppPalette.goldGlow,
    metricColor: AppPalette.goldLight,
    navBg: AppPalette.abyss0,
    navActive: AppPalette.gold,
    navInactive: AppPalette.textDim,
    scaffoldBg: AppPalette.abyss1,
  );

  // ── Preset: Light ──────────────────────────────────────────────────────────
  static const RiverColors _light = RiverColors(
    riverNormal: Color(0xFF00897B),
    riverWarning: AppPalette.warning,
    riverSevere: AppPalette.severe,
    riverDanger: AppPalette.danger,
    riverCritical: AppPalette.critical,
    riverSurface: Color(0xFFFFF8E7),
    riverGlow: Color(0x33FFB800),
    cardBg: Colors.white,
    cardBgElevated: Color(0xFFFFF3CC),
    chipBg: Color(0xFFFFE999),
    stroke: Color(0xFFE8C84A),
    textPrimary: Color(0xFF1A0F00),
    textSecondary: Color(0xFF6B4F20),
    sparklineColor: AppPalette.goldDark,
    accent: AppPalette.goldDark,
    accentGlow: Color(0x33FFB800),
    metricColor: AppPalette.amberDim,
    navBg: Color(0xFF1F1400), // FIX: was abyss0 (correct for light)
    navActive: AppPalette.gold,
    navInactive: Color(0xFF9A8060),
    scaffoldBg: Color(0xFFFFF8E7),
  );

  // ── Preset: Sunset ─────────────────────────────────────────────────────────
  static const RiverColors _sunset = RiverColors(
    riverNormal: AppPalette.safe,
    riverWarning: Color(0xFFFFAA00),
    riverSevere: AppPalette.severe,
    riverDanger: AppPalette.danger,
    riverCritical: AppPalette.critical,
    riverSurface: AppPalette.sunset2,
    riverGlow: Color(0x55FF6B35),
    cardBg: AppPalette.sunset2,
    cardBgElevated: AppPalette.sunset3,
    chipBg: AppPalette.sunset4,
    stroke: AppPalette.sunsetStroke,
    textPrimary: Color(0xFFFFF0E8),
    textSecondary: Color(0xFFBB8878),
    sparklineColor: AppPalette.sunsetAccent,
    accent: AppPalette.sunsetAccent,
    accentGlow: Color(0x55FF6B35),
    metricColor: AppPalette.sunsetGold,
    navBg: AppPalette.sunset0,
    navActive: AppPalette.sunsetAccent,
    navInactive: Color(0xFF6B3040),
    scaffoldBg: AppPalette.sunset1,
  );

  // ── Preset: Ocean ──────────────────────────────────────────────────────────
  static const RiverColors _ocean = RiverColors(
    riverNormal: AppPalette.safe,
    riverWarning: AppPalette.warning,
    riverSevere: AppPalette.severe,
    riverDanger: AppPalette.danger,
    riverCritical: AppPalette.critical,
    riverSurface: AppPalette.ocean2,
    riverGlow: AppPalette.oceanGlow,
    cardBg: AppPalette.ocean2,
    cardBgElevated: AppPalette.ocean3,
    chipBg: AppPalette.ocean4,
    stroke: AppPalette.oceanStroke,
    textPrimary: Color(0xFFE0F7FF),
    textSecondary: Color(0xFF5A9AB5),
    sparklineColor: AppPalette.cyan,
    accent: AppPalette.cyan,
    accentGlow: AppPalette.cyanGlow,
    metricColor: AppPalette.cyan,
    navBg: AppPalette.ocean0,
    navActive: AppPalette.cyan,
    navInactive: Color(0xFF1A4A60),
    scaffoldBg: AppPalette.ocean1,
  );

  // ── Factory ────────────────────────────────────────────────────────────────
  static RiverColors forMode(String modeName) {
    switch (modeName) {
      case 'light':
        return _light;
      case 'sunset':
        return _sunset;
      case 'ocean':
        return _ocean;
      default:
        return _golden;
    }
  }

  // ── ThemeExtension overrides ───────────────────────────────────────────────
  @override
  RiverColors copyWith({
    Color? riverNormal,
    Color? riverWarning,
    Color? riverSevere,
    Color? riverDanger,
    Color? riverCritical,
    Color? riverSurface,
    Color? riverGlow,
    Color? cardBg,
    Color? cardBgElevated,
    Color? chipBg,
    Color? stroke,
    Color? textPrimary,
    Color? textSecondary,
    Color? sparklineColor,
    Color? accent,
    Color? accentGlow,
    Color? metricColor,
    Color? navBg,
    Color? navActive,
    Color? navInactive,
    Color? scaffoldBg,
  }) =>
      RiverColors(
        riverNormal: riverNormal ?? this.riverNormal,
        riverWarning: riverWarning ?? this.riverWarning,
        riverSevere: riverSevere ?? this.riverSevere,
        riverDanger: riverDanger ?? this.riverDanger,
        riverCritical: riverCritical ?? this.riverCritical,
        riverSurface: riverSurface ?? this.riverSurface,
        riverGlow: riverGlow ?? this.riverGlow,
        cardBg: cardBg ?? this.cardBg,
        cardBgElevated: cardBgElevated ?? this.cardBgElevated,
        chipBg: chipBg ?? this.chipBg,
        stroke: stroke ?? this.stroke,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        sparklineColor: sparklineColor ?? this.sparklineColor,
        accent: accent ?? this.accent,
        accentGlow: accentGlow ?? this.accentGlow,
        metricColor: metricColor ?? this.metricColor,
        navBg: navBg ?? this.navBg,
        navActive: navActive ?? this.navActive,
        navInactive: navInactive ?? this.navInactive,
        scaffoldBg: scaffoldBg ?? this.scaffoldBg,
      );

  @override
  RiverColors lerp(ThemeExtension<RiverColors>? other, double t) {
    if (other is! RiverColors) return this;
    return RiverColors(
      riverNormal: Color.lerp(riverNormal, other.riverNormal, t)!,
      riverWarning: Color.lerp(riverWarning, other.riverWarning, t)!,
      riverSevere: Color.lerp(riverSevere, other.riverSevere, t)!,
      riverDanger: Color.lerp(riverDanger, other.riverDanger, t)!,
      riverCritical: Color.lerp(riverCritical, other.riverCritical, t)!,
      riverSurface: Color.lerp(riverSurface, other.riverSurface, t)!,
      riverGlow: Color.lerp(riverGlow, other.riverGlow, t)!,
      cardBg: Color.lerp(cardBg, other.cardBg, t)!,
      cardBgElevated: Color.lerp(cardBgElevated, other.cardBgElevated, t)!,
      chipBg: Color.lerp(chipBg, other.chipBg, t)!,
      stroke: Color.lerp(stroke, other.stroke, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      sparklineColor: Color.lerp(sparklineColor, other.sparklineColor, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentGlow: Color.lerp(accentGlow, other.accentGlow, t)!,
      metricColor: Color.lerp(metricColor, other.metricColor, t)!,
      navBg: Color.lerp(navBg, other.navBg, t)!,
      navActive: Color.lerp(navActive, other.navActive, t)!,
      navInactive: Color.lerp(navInactive, other.navInactive, t)!,
      scaffoldBg: Color.lerp(scaffoldBg, other.scaffoldBg, t)!,
    );
  }

  // ── Static theme builders ──────────────────────────────────────────────────
  static ThemeData lightTheme() =>
      _buildTheme(brightness: Brightness.light, ext: _light);
  static ThemeData darkTheme() =>
      _buildTheme(brightness: Brightness.dark, ext: _golden);
  static ThemeData sunsetTheme() =>
      _buildTheme(brightness: Brightness.dark, ext: _sunset);
  static ThemeData oceanTheme() =>
      _buildTheme(brightness: Brightness.dark, ext: _ocean);

  static ThemeData highContrastTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF000000),
      cardColor: const Color(0xFF0D0D0D),
      dividerColor: const Color(0xFF555555),
      colorScheme: const ColorScheme.dark(
        surface: Color(0xFF0D0D0D),
        primary: Color(0xFF63C2FF),
        secondary: Color(0xFF48D597),
        error: Color(0xFFFF6B75),
        outline: Color(0xFF555555),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 20,
            fontWeight: FontWeight.w700),
        titleMedium: TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 16,
            fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: Color(0xFFFFFFFF), fontSize: 15),
        bodyMedium: TextStyle(color: Color(0xFFE0E0E0), fontSize: 13),
        labelSmall: TextStyle(color: Color(0xFFE0E0E0), fontSize: 11),
      ),
      iconTheme: const IconThemeData(color: Color(0xFFE0E0E0), size: 20),
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required RiverColors ext,
  }) {
    final isDark = brightness == Brightness.dark;
    final scaffold = ext.scaffoldBg;
    final card = ext.cardBg;
    final stroke = ext.stroke;
    final accent = ext.accent;

    final cs = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    ).copyWith(
      primary: accent,
      secondary: ext.metricColor,
      surface: card,
      onPrimary: isDark ? ext.scaffoldBg : Colors.white,
      onSecondary: isDark ? ext.scaffoldBg : Colors.white,
      error: AppPalette.critical,
      surfaceContainerHighest: ext.cardBgElevated,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: scaffold,
      extensions: <ThemeExtension<dynamic>>[ext],
      fontFamily: 'Roboto',
      textTheme: TextTheme(
        displayLarge: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: -1.5,
            color: ext.textPrimary),
        displaySmall: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0,
            color: ext.textPrimary),
        titleLarge: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: ext.textPrimary),
        titleMedium: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: ext.textPrimary),
        bodyMedium:
            TextStyle(fontWeight: FontWeight.w400, color: ext.textSecondary),
        labelSmall: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: ext.textSecondary),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: stroke, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: ext.navBg,
        foregroundColor: ext.textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        titleTextStyle: TextStyle(
          color: ext.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: accent),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ext.navBg,
        indicatorColor: ext.accentGlow,
        height: 64,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected))
            return IconThemeData(color: ext.navActive, size: 24);
          return IconThemeData(color: ext.navInactive, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: ext.navActive,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            );
          }
          return TextStyle(
            color: ext.navInactive,
            fontSize: 10,
            letterSpacing: 0.2,
          );
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: isDark ? ext.scaffoldBg : Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: isDark ? ext.scaffoldBg : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: BorderSide(color: accent, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ext.chipBg,
        labelStyle: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: ext.textPrimary),
        side: BorderSide(color: stroke, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: ext.cardBgElevated,
      ),
      dividerTheme: DividerThemeData(
        color: stroke,
        space: 1,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: stroke)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: stroke)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: accent, width: 2)),
        hintStyle: TextStyle(color: ext.textSecondary),
        labelStyle: TextStyle(color: accent),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: ext.cardBgElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: stroke),
        ),
        textStyle: TextStyle(color: ext.textPrimary, fontSize: 12),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ext.cardBgElevated,
        contentTextStyle: TextStyle(color: ext.textPrimary),
        actionTextColor: accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RiverTheme  –  convenience wrapper for tests & previews
// ─────────────────────────────────────────────────────────────────────────────

class RiverTheme extends StatelessWidget {
  final Widget child;
  final String mode; // 'dark' | 'light' | 'sunset' | 'ocean'

  const RiverTheme({
    super.key,
    required this.child,
    this.mode = 'dark',
  });

  ThemeData get _theme {
    switch (mode) {
      case 'light':
        return RiverColors.lightTheme();
      case 'sunset':
        return RiverColors.sunsetTheme();
      case 'ocean':
        return RiverColors.oceanTheme();
      default:
        return RiverColors.darkTheme();
    }
  }

  @override
  Widget build(BuildContext context) => Theme(data: _theme, child: child);
}
