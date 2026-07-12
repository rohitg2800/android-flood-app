// lib/core/theme/river_colors.dart
import 'package:flutter/material.dart';

class RiverColors {
  final Color scaffoldBg;
  final Color cardBg;
  final Color surfaceOutline;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  final Color accent;
  final Color accentSoft;

  final Color danger;
  final Color warning;
  final Color success;
  final Color info;

  const RiverColors({
    required this.scaffoldBg,
    required this.cardBg,
    required this.surfaceOutline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentSoft,
    required this.danger,
    required this.warning,
    required this.success,
    required this.info,
  });

  factory RiverColors.dark() {
    return RiverColors(
      scaffoldBg: const Color(0xFF05070A),
      cardBg: const Color(0xFF0F141B),
      surfaceOutline: const Color(0xFF232934),
      textPrimary: const Color(0xFFF5F7FA),
      textSecondary: const Color(0xFFB7C0CE),
      textMuted: const Color(0xFF7A8290),
      accent: const Color(0xFF4CB3FF),
      accentSoft: const Color(0x334CB3FF),
      danger: const Color(0xFFFF4D5A),
      warning: const Color(0xFFFFC857),
      success: const Color(0xFF3ACC8A),
      info: const Color(0xFF4C6FFF),
    );
  }

  RiverColors copyWith({Color? accent, Color? danger}) {
    return RiverColors(
      scaffoldBg: scaffoldBg,
      cardBg: cardBg,
      surfaceOutline: surfaceOutline,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      textMuted: textMuted,
      accent: accent ?? this.accent,
      accentSoft: accentSoft,
      danger: danger ?? this.danger,
      warning: warning,
      success: success,
      info: info,
    );
  }
}
