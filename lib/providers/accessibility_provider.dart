import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccessibilityState {
  final bool highContrast;
  final double textScaleFactor;
  final String locale;

  const AccessibilityState({
    this.highContrast    = false,
    this.textScaleFactor = 1.0,
    this.locale          = 'en',
  });

  AccessibilityState copyWith({
    bool?   highContrast,
    double? textScaleFactor,
    String? locale,
  }) => AccessibilityState(
    highContrast:    highContrast    ?? this.highContrast,
    textScaleFactor: textScaleFactor ?? this.textScaleFactor,
    locale:          locale          ?? this.locale,
  );
}

class AccessibilityNotifier extends Notifier<AccessibilityState> {
  final SharedPreferences prefs;

  AccessibilityNotifier({required this.prefs});

  @override
  AccessibilityState build() => AccessibilityState(
    highContrast:    prefs.getBool('a11y_high_contrast')   ?? false,
    textScaleFactor: prefs.getDouble('a11y_text_scale')    ?? 1.0,
    locale:          prefs.getString('a11y_locale')        ?? 'en',
  );

  Future<void> setHighContrast(bool value) async {
    await prefs.setBool('a11y_high_contrast', value);
    state = state.copyWith(highContrast: value);
  }

  void toggleHighContrast() => setHighContrast(!state.highContrast);

  Future<void> setTextScale(double value) async {
    final clamped = value.clamp(1.0, 1.4);
    await prefs.setDouble('a11y_text_scale', clamped);
    state = state.copyWith(textScaleFactor: clamped);
  }

  Future<void> setLocale(String locale) async {
    await prefs.setString('a11y_locale', locale);
    state = state.copyWith(locale: locale);
  }
}

/// App-wide provider — override at startup and in tests.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('sharedPreferencesProvider not initialised'),
);

final accessibilityProvider =
    NotifierProvider<AccessibilityNotifier, AccessibilityState>(
  () => throw UnimplementedError('accessibilityProvider must be overridden'),
);
