import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/settings_state.dart';

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() => const SettingsState();

  void setHighContrast(bool v) => state = state.copyWith(highContrast: v);
  void setReducedMotion(bool v) => state = state.copyWith(reducedMotion: v);
  void setTextScale(AppTextScale v) => state = state.copyWith(textScale: v);
  void setAlertLevel(AppAlertLevel v) => state = state.copyWith(alertLevel: v);
  void setQuietHours(bool v) => state = state.copyWith(quietHoursEnabled: v);
  void setQuietHourStart(int v) => state = state.copyWith(quietHourStart: v);
  void setQuietHourEnd(int v) => state = state.copyWith(quietHourEnd: v);
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);
