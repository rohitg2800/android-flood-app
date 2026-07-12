// Phase 2 – Full Accessibility Settings model (Phase 1 + Phase 2 fields)
import 'package:freezed_annotation/freezed_annotation.dart';

part 'accessibility_settings.freezed.dart';
part 'accessibility_settings.g.dart';

@freezed
class AccessibilitySettings with _$AccessibilitySettings {
  const factory AccessibilitySettings({
    required String userId,
    // Phase 1
    @Default(1.0) double textScale,
    @Default(false) bool highContrast,
    @Default(false) bool boldText,
    @Default('en') String locale,
    @Default(false) bool reduceMotion,
    @Default(false) bool largeTapTargets,
    @Default(false) bool screenReaderMode,
    @Default('none') String colorBlindMode,
    // Phase 2
    @Default('system') String fontFamily,
    @Default(1.5) double lineSpacing,
    @Default(false) bool focusHighlight,
    @Default(false) bool captionsEnabled,
    @Default(false) bool hapticFeedback,
  }) = _AccessibilitySettings;

  factory AccessibilitySettings.fromJson(Map<String, dynamic> json) =>
      _$AccessibilitySettingsFromJson(json);
}
