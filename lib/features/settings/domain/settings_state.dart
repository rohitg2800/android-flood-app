enum AppTextScale { normal, large, extraLarge }
enum AppAlertLevel { criticalOnly, criticalAndWatch, all }

class SettingsState {
  final bool highContrast;
  final bool reducedMotion;
  final AppTextScale textScale;
  final AppAlertLevel alertLevel;
  final bool quietHoursEnabled;
  final int quietHourStart;
  final int quietHourEnd;

  const SettingsState({
    this.highContrast     = false,
    this.reducedMotion    = false,
    this.textScale        = AppTextScale.normal,
    this.alertLevel       = AppAlertLevel.criticalAndWatch,
    this.quietHoursEnabled = false,
    this.quietHourStart   = 22,
    this.quietHourEnd     = 7,
  });

  SettingsState copyWith({
    bool? highContrast,
    bool? reducedMotion,
    AppTextScale? textScale,
    AppAlertLevel? alertLevel,
    bool? quietHoursEnabled,
    int? quietHourStart,
    int? quietHourEnd,
  }) {
    return SettingsState(
      highContrast:      highContrast      ?? this.highContrast,
      reducedMotion:     reducedMotion     ?? this.reducedMotion,
      textScale:         textScale         ?? this.textScale,
      alertLevel:        alertLevel        ?? this.alertLevel,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHourStart:    quietHourStart    ?? this.quietHourStart,
      quietHourEnd:      quietHourEnd      ?? this.quietHourEnd,
    );
  }
}