import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── State Model ────────────────────────────────────────────────────────────

class AccessibilitySettings {
  final double
      fontSizeScale; // 0.8 = small, 1.0 = normal, 1.2 = large, 1.5 = XL
  final bool highContrast;
  final bool reduceMotion;
  final bool screenReaderOptimized;
  final bool boldText;
  final bool largeIcons;
  final ThemeMode themeMode;

  const AccessibilitySettings({
    this.fontSizeScale = 1.0,
    this.textToSpeechAlerts = false,
    this.hapticFeedback = true,
    this.customVibrationPatterns = false,
    this.highContrast = false,
    this.reduceMotion = false,
    this.screenReaderOptimized = false,
    this.boldText = false,
    this.largeIcons = false,
    this.themeMode = ThemeMode.system,
  });

  AccessibilitySettings copyWith({
    double? fontSizeScale,
    bool? highContrast,
    bool? reduceMotion,
    bool? screenReaderOptimized,
    bool? boldText,
    bool? largeIcons,
    ThemeMode? themeMode,
  }) =>
      AccessibilitySettings(
        fontSizeScale: fontSizeScale ?? this.fontSizeScale,
        highContrast: highContrast ?? this.highContrast,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        screenReaderOptimized:
            screenReaderOptimized ?? this.screenReaderOptimized,
        boldText: boldText ?? this.boldText,
        largeIcons: largeIcons ?? this.largeIcons,
        themeMode: themeMode ?? this.themeMode,
      );

  @override
  bool operator ==(Object other) =>
      other is AccessibilitySettings &&
      other.fontSizeScale == fontSizeScale &&
      other.highContrast == highContrast &&
      other.reduceMotion == reduceMotion &&
      other.screenReaderOptimized == screenReaderOptimized &&
      other.boldText == boldText &&
      other.largeIcons == largeIcons &&
      other.themeMode == themeMode;

  @override
  int get hashCode => Object.hash(
        fontSizeScale,
        highContrast,
        reduceMotion,
        screenReaderOptimized,
        boldText,
        largeIcons,
        themeMode,
      );
  void toggleTTS() => state = state.copyWith(textToSpeechAlerts: !state.textToSpeechAlerts);
  void toggleHaptic() => state = state.copyWith(hapticFeedback: !state.hapticFeedback);
  void toggleVibration() => state = state.copyWith(customVibrationPatterns: !state.customVibrationPatterns);
  void setTextScale(double s) => setFontSizeScale(s);
}

// ── StateNotifier ──────────────────────────────────────────────────────────

class AccessibilityNotifier extends StateNotifier<AccessibilitySettings> {
  AccessibilityNotifier() : super(const AccessibilitySettings());

  void setFontSizeScale(double scale) =>
      state = state.copyWith(fontSizeScale: scale.clamp(0.8, 1.6));

  void toggleHighContrast() =>
      state = state.copyWith(highContrast: !state.highContrast);

  void toggleReduceMotion() =>
      state = state.copyWith(reduceMotion: !state.reduceMotion);

  void toggleScreenReaderOptimized() => state =
      state.copyWith(screenReaderOptimized: !state.screenReaderOptimized);

  void toggleBoldText() => state = state.copyWith(boldText: !state.boldText);

  void toggleLargeIcons() =>
      state = state.copyWith(largeIcons: !state.largeIcons);

  void setThemeMode(ThemeMode mode) => state = state.copyWith(themeMode: mode);

  void resetToDefaults() => state = const AccessibilitySettings();
  void toggleTTS() => state = state.copyWith(textToSpeechAlerts: !state.textToSpeechAlerts);
  void toggleHaptic() => state = state.copyWith(hapticFeedback: !state.hapticFeedback);
  void toggleVibration() => state = state.copyWith(customVibrationPatterns: !state.customVibrationPatterns);
  void setTextScale(double s) => setFontSizeScale(s);
}

// ── Provider ───────────────────────────────────────────────────────────────

final accessibilityProvider =
    StateNotifierProvider<AccessibilityNotifier, AccessibilitySettings>(
  (ref) => AccessibilityNotifier(),
);

// ── Convenience selectors ──────────────────────────────────────────────────

final fontSizeScaleProvider = Provider<double>(
  (ref) => ref.watch(accessibilityProvider).fontSizeScale,
);

final themeModeProvider = Provider<ThemeMode>(
  (ref) => ref.watch(accessibilityProvider).themeMode,
);

final highContrastProvider = Provider<bool>(
  (ref) => ref.watch(accessibilityProvider).highContrast,
);
