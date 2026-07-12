import 'package:flutter/material.dart';
import 'river_colors.dart';

class HighContrastColors {
  static RiverColors from(RiverColors base) {
    return RiverColors(
      scaffoldBg: const Color(0xFF000000),
      cardBg: const Color(0xFF0A0A0A),
      surfaceOutline: const Color(0xFF4A5568),
      textPrimary: const Color(0xFFFFFFFF),
      textSecondary: const Color(0xFFE2E8F0),
      textMuted: const Color(0xFFA0AEC0),
      accent: const Color(0xFF63C2FF),
      accentSoft: const Color(0x4D63C2FF),
      danger: const Color(0xFFFF6B75),
      warning: const Color(0xFFFFD874),
      success: const Color(0xFF48D597),
      info: const Color(0xFF7B8FFF),
    );
  }
}
