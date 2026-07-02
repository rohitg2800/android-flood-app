import 'package:freezed_annotation/freezed_annotation.dart';

part 'accessibility_settings.freezed.dart';
part 'accessibility_settings.g.dart';

@freezed
class AccessibilitySettings with _$AccessibilitySettings {
  const factory AccessibilitySettings({
    @Default(false) bool highContrast,
    @Default(false) bool largeText,
    @Default(false) bool screenReaderMode,
    @Default(true) bool hapticFeedback,
    @Default(true) bool textToSpeechAlerts,
    @Default(true) bool customVibrationPatterns,
    @Default(false) bool reduceMotion,
    @Default(1.0) double textScaleFactor,
  }) = _AccessibilitySettings;

  factory AccessibilitySettings.fromJson(Map<String, dynamic> json) =>
      _$AccessibilitySettingsFromJson(json);
}
