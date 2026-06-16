// lib/theme/high_contrast_colors.dart  v2
// Fixed: all 21 required RiverColors parameters now supplied.
// divider removed (it's a computed alias via stroke in RiverColors, not a param).
import 'package:flutter/material.dart';
import 'river_theme.dart';

RiverColors highContrastColors() {
  return const RiverColors(
    // River semantic
    riverNormal:    Color(0xFF00E676),
    riverWarning:   Color(0xFFFFD600),
    riverSevere:    Color(0xFFFF9100),
    riverDanger:    Color(0xFFFF3D00),
    riverCritical:  Color(0xFFFF1744),
    riverSurface:   Color(0xFF1A1A1A),
    riverGlow:      Color(0x44FF1744),
    // Cards / chips
    cardBg:         Color(0xFF0D0D0D),
    cardBgElevated: Color(0xFF1A1A1A),
    chipBg:         Color(0xFF222222),
    stroke:         Color(0xFF444444),
    // Text
    textPrimary:    Color(0xFFFFFFFF),
    textSecondary:  Color(0xFFDDDDDD),
    // Sparkline / accent
    sparklineColor: Color(0xFF00E5FF),
    accent:         Color(0xFF00E5FF),
    accentGlow:     Color(0x4400E5FF),
    metricColor:    Color(0xFF00E5FF),
    // Nav
    navBg:          Color(0xFF000000),
    navActive:      Color(0xFF00E5FF),
    navInactive:    Color(0xFF666666),
    // Scaffold
    scaffoldBg:     Color(0xFF000000),
  );
}

extension HighContrastX on RiverColors {
  bool get isHighContrast => scaffoldBg == const Color(0xFF000000);
}
