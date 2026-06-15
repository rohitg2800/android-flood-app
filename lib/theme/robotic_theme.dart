// lib/theme/robotic_theme.dart
// Robotic design language — sharp corners, glow effects, monospaced type.
// Two faces: Tactical-Dark (isDark=true) / Tactical-Light (isDark=false).
// toThemeData() / toFlutterTheme() — used by main.dart.
library;

import 'package:flutter/material.dart';
import 'river_theme.dart';

// ─── Robotic palette ─────────────────────────────────────────────────────

class RoboticColors {
  RoboticColors._();

  // TACTICAL DARK
  static const rdBg          = Color(0xFF030508);
  static const rdSurface     = Color(0xFF0A0D12);
  static const rdSurface2    = Color(0xFF111620);
  static const rdBorder      = Color(0xFF1C2333);
  static const rdAccent      = Color(0xFF00FFB2);
  static const rdAccentGlow  = Color(0x3300FFB2);
  static const rdAccent2     = Color(0xFF00AAFF);
  static const rdAccent2Glow = Color(0x2200AAFF);
  static const rdDanger      = Color(0xFFFF3B3B);
  static const rdWarning     = Color(0xFFFFAA00);
  static const rdText        = Color(0xFFE0F0FF);
  static const rdTextMuted   = Color(0xFF5A7080);

  // TACTICAL LIGHT
  static const rlBg          = Color(0xFFF4F7FA);
  static const rlSurface     = Color(0xFFFFFFFF);
  static const rlSurface2    = Color(0xFFEBF0F5);
  static const rlBorder      = Color(0xFFCDD8E3);
  static const rlAccent      = Color(0xFF007ACC);
  static const rlAccentGlow  = Color(0x22007ACC);
  static const rlAccent2     = Color(0xFF00A86B);
  static const rlAccent2Glow = Color(0x2200A86B);
  static const rlDanger      = Color(0xFFD32F2F);
  static const rlWarning     = Color(0xFFF57C00);
  static const rlText        = Color(0xFF0D1B2A);
  static const rlTextMuted   = Color(0xFF5A7080);
}

// ─── RiverColors for robotic modes ──────────────────────────────────────
// These extend RiverColors so every screen's rc.cardBg / rc.accent /
// rc.scaffoldBg / rc.sparklineColor etc. all respond to tactical themes.

const _roboticDarkColors = RiverColors(
  riverNormal:    Color(0xFF00FFB2),   // neon mint — safe level
  riverWarning:   Color(0xFFFFAA00),   // amber
  riverSevere:    Color(0xFFFF6600),   // orange-red — between warning & danger
  riverDanger:    Color(0xFFFF6600),   // orange
  riverCritical:  Color(0xFFFF3B3B),   // red
  riverSurface:   Color(0xFF0A0D12),
  riverGlow:      Color(0x3300FFB2),
  cardBg:         Color(0xFF0A0D12),
  cardBgElevated: Color(0xFF111620),
  chipBg:         Color(0xFF1C2333),
  stroke:         Color(0xFF1C2333),
  textPrimary:    Color(0xFFE0F0FF),
  textSecondary:  Color(0xFF5A7080),
  sparklineColor: Color(0xFF00FFB2),
  accent:         Color(0xFF00FFB2),
  accentGlow:     Color(0x3300FFB2),
  metricColor:    Color(0xFF00AAFF),
  navBg:          Color(0xFF030508),
  navActive:      Color(0xFF00FFB2),
  navInactive:    Color(0xFF1C2333),
  scaffoldBg:     Color(0xFF030508),
);

const _roboticLightColors = RiverColors(
  riverNormal:    Color(0xFF00A86B),   // green — safe
  riverWarning:   Color(0xFFF57C00),   // orange
  riverSevere:    Color(0xFFE65000),   // deep orange — between warning & danger
  riverDanger:    Color(0xFFE64A19),   // deep orange
  riverCritical:  Color(0xFFD32F2F),   // red
  riverSurface:   Color(0xFFFFFFFF),
  riverGlow:      Color(0x22007ACC),
  cardBg:         Color(0xFFFFFFFF),
  cardBgElevated: Color(0xFFEBF0F5),
  chipBg:         Color(0xFFCDD8E3),
  stroke:         Color(0xFFCDD8E3),
  textPrimary:    Color(0xFF0D1B2A),
  textSecondary:  Color(0xFF5A7080),
  sparklineColor: Color(0xFF007ACC),
  accent:         Color(0xFF007ACC),
  accentGlow:     Color(0x22007ACC),
  metricColor:    Color(0xFF007ACC),
  navBg:          Color(0xFF0D1B2A),
  navActive:      Color(0xFF007ACC),
  navInactive:    Color(0xFFCDD8E3),
  scaffoldBg:     Color(0xFFF4F7FA),
);

// ─── RoboticTheme ─────────────────────────────────────────────────────────────────

class RoboticTheme {
  final bool isDark;
  const RoboticTheme({required this.isDark});

  Color get bg          => isDark ? RoboticColors.rdBg          : RoboticColors.rlBg;
  Color get surface     => isDark ? RoboticColors.rdSurface     : RoboticColors.rlSurface;
  Color get surface2    => isDark ? RoboticColors.rdSurface2    : RoboticColors.rlSurface2;
  Color get border      => isDark ? RoboticColors.rdBorder      : RoboticColors.rlBorder;
  Color get accent      => isDark ? RoboticColors.rdAccent      : RoboticColors.rlAccent;
  Color get accentGlow  => isDark ? RoboticColors.rdAccentGlow  : RoboticColors.rlAccentGlow;
  Color get accent2     => isDark ? RoboticColors.rdAccent2     : RoboticColors.rlAccent2;
  Color get accent2Glow => isDark ? RoboticColors.rdAccent2Glow : RoboticColors.rlAccent2Glow;
  Color get danger      => isDark ? RoboticColors.rdDanger      : RoboticColors.rlDanger;
  Color get warning     => isDark ? RoboticColors.rdWarning     : RoboticColors.rlWarning;
  Color get text        => isDark ? RoboticColors.rdText        : RoboticColors.rlText;
  Color get textMuted   => isDark ? RoboticColors.rdTextMuted   : RoboticColors.rlTextMuted;

  RiverColors get riverColors =>
      isDark ? _roboticDarkColors : _roboticLightColors;

  /// Primary method — called as roboticTheme.toThemeData() in main.dart.
  /// RiverColors is injected as a ThemeExtension so every screen's
  /// RiverColors.of(context) resolves the correct tactical palette.
  ThemeData toThemeData() {
    final brightness = isDark ? Brightness.dark : Brightness.light;
    final rc = riverColors;

    final cs = ColorScheme.fromSeed(
      seedColor:  accent,
      brightness: brightness,
    ).copyWith(
      primary:   accent,
      secondary: accent2,
      surface:   surface,
      onPrimary: isDark ? const Color(0xFF030508) : Colors.white,
      error:     danger,
    );

    return ThemeData(
      useMaterial3:            true,
      colorScheme:             cs,
      scaffoldBackgroundColor: bg,
      fontFamily:              'RobotoMono',
      // ✔ Inject RiverColors so RiverColors.of(context) works on every screen
      extensions: <ThemeExtension<dynamic>>[rc],
      cardTheme: CardThemeData(
        color:     surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: border, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor:  bg,
        foregroundColor:  text,
        elevation:        0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color:         text,
          fontSize:      16,
          fontWeight:    FontWeight.w700,
          letterSpacing: 1.5,
          fontFamily:    'RobotoMono',
        ),
        iconTheme: IconThemeData(color: accent),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bg,
        indicatorColor:  accentGlow,
        height:          64,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: accent, size: 24);
          }
          return IconThemeData(color: rc.navInactive, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: accent, fontSize: 10,
              fontWeight: FontWeight.w700, letterSpacing: 0.3);
          }
          return TextStyle(
            color: rc.navInactive, fontSize: 10, letterSpacing: 0.2);
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: isDark ? const Color(0xFF030508) : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700, letterSpacing: 1.0,
            fontFamily: 'RobotoMono'),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: BorderSide(color: accent, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600, fontFamily: 'RobotoMono'),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? const Color(0xFF1C2333) : const Color(0xFFEBF0F5),
        labelStyle: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: text,
          fontFamily: 'RobotoMono',
        ),
        side: BorderSide(color: border, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color:            accent,
        linearTrackColor: surface2,
      ),
      dividerTheme: DividerThemeData(
        color: border, space: 1, thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled:    true,
        fillColor: surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        hintStyle: TextStyle(color: textMuted),
        labelStyle: TextStyle(color: accent),
      ),
      textTheme: TextTheme(
        displayLarge:  TextStyle(color: text, fontWeight: FontWeight.w900, letterSpacing: -1.5, fontFamily: 'RobotoMono'),
        displaySmall:  TextStyle(color: text, fontWeight: FontWeight.w800, letterSpacing: -1.0, fontFamily: 'RobotoMono'),
        titleLarge:    TextStyle(color: text, fontWeight: FontWeight.w700, letterSpacing: 1.0,  fontFamily: 'RobotoMono'),
        titleMedium:   TextStyle(color: text, fontWeight: FontWeight.w600, letterSpacing: 0.5,  fontFamily: 'RobotoMono'),
        bodyMedium:    TextStyle(color: rc.textSecondary, fontFamily: 'RobotoMono'),
        labelSmall:    TextStyle(color: rc.textSecondary, fontWeight: FontWeight.w600, letterSpacing: 1.2, fontFamily: 'RobotoMono'),
      ),
    );
  }

  /// Alias — keeps backward compatibility if any file calls toFlutterTheme()
  ThemeData toFlutterTheme() => toThemeData();
}
