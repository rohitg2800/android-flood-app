import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equinox_flood/features/accessibility/models/accessibility_settings.dart';

class AccessibilityNotifier
    extends Notifier<AccessibilitySettings> {
  @override
  AccessibilitySettings build() => const AccessibilitySettings();

  void toggleHighContrast() =>
      state = state.copyWith(highContrast: !state.highContrast);

  void toggleLargeText() =>
      state = state.copyWith(largeText: !state.largeText);

  void toggleScreenReader() =>
      state = state.copyWith(screenReaderMode: !state.screenReaderMode);

  void toggleHaptic() =>
      state = state.copyWith(hapticFeedback: !state.hapticFeedback);

  void toggleTTS() =>
      state = state.copyWith(textToSpeechAlerts: !state.textToSpeechAlerts);

  void toggleVibration() => state = state.copyWith(
      customVibrationPatterns: !state.customVibrationPatterns);

  void toggleReduceMotion() =>
      state = state.copyWith(reduceMotion: !state.reduceMotion);

  void setTextScale(double scale) =>
      state = state.copyWith(textScaleFactor: scale);
}

final accessibilityProvider =
    NotifierProvider<AccessibilityNotifier, AccessibilitySettings>(
        AccessibilityNotifier.new);
