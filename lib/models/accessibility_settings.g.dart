// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'accessibility_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AccessibilitySettingsImpl _$$AccessibilitySettingsImplFromJson(
        Map<String, dynamic> json) =>
    _$AccessibilitySettingsImpl(
      userId: json['userId'] as String,
      textScale: (json['textScale'] as num?)?.toDouble() ?? 1.0,
      highContrast: json['highContrast'] as bool? ?? false,
      boldText: json['boldText'] as bool? ?? false,
      locale: json['locale'] as String? ?? 'en',
      reduceMotion: json['reduceMotion'] as bool? ?? false,
      largeTapTargets: json['largeTapTargets'] as bool? ?? false,
      screenReaderMode: json['screenReaderMode'] as bool? ?? false,
      colorBlindMode: json['colorBlindMode'] as String? ?? 'none',
      fontFamily: json['fontFamily'] as String? ?? 'system',
      lineSpacing: (json['lineSpacing'] as num?)?.toDouble() ?? 1.5,
      focusHighlight: json['focusHighlight'] as bool? ?? false,
      captionsEnabled: json['captionsEnabled'] as bool? ?? false,
      hapticFeedback: json['hapticFeedback'] as bool? ?? false,
    );

Map<String, dynamic> _$$AccessibilitySettingsImplToJson(
        _$AccessibilitySettingsImpl instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'textScale': instance.textScale,
      'highContrast': instance.highContrast,
      'boldText': instance.boldText,
      'locale': instance.locale,
      'reduceMotion': instance.reduceMotion,
      'largeTapTargets': instance.largeTapTargets,
      'screenReaderMode': instance.screenReaderMode,
      'colorBlindMode': instance.colorBlindMode,
      'fontFamily': instance.fontFamily,
      'lineSpacing': instance.lineSpacing,
      'focusHighlight': instance.focusHighlight,
      'captionsEnabled': instance.captionsEnabled,
      'hapticFeedback': instance.hapticFeedback,
    };
