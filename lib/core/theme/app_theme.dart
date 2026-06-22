import 'package:flutter/material.dart';
import 'river_colors.dart';
import 'high_contrast_colors.dart';

class AppTheme {
  final RiverColors colors;
  final bool highContrast;

  const AppTheme({required this.colors, required this.highContrast});

  factory AppTheme.dark({bool highContrast = false}) {
    final base = RiverColors.dark();
    final colors = highContrast ? HighContrastColors.from(base) : base;
    return AppTheme(colors: colors, highContrast: highContrast);
  }

  ThemeData toThemeData() {
    final c = colors;
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: c.scaffoldBg,
      cardColor: c.cardBg,
      dividerColor: c.surfaceOutline,
      colorScheme: ColorScheme.dark(
        background: c.scaffoldBg,
        surface: c.cardBg,
        primary: c.accent,
        secondary: c.info,
        error: c.danger,
        outline: c.surfaceOutline,
      ),
      textTheme: TextTheme(
        titleMedium: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: c.textPrimary, fontSize: 15, height: 1.5),
        bodyMedium: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4),
        labelMedium: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.4),
        labelSmall: TextStyle(color: c.textMuted, fontSize: 11, letterSpacing: 0.9, fontWeight: FontWeight.w600),
      ),
      iconTheme: IconThemeData(color: c.textSecondary, size: 20),
      splashColor: c.accentSoft,
      highlightColor: Colors.transparent,
    );
  }
}
