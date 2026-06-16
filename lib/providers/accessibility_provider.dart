// lib/providers/accessibility_provider.dart  Steps 5.2 / 5.5
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kHC    = 'a11y_high_contrast';
const _kScale = 'a11y_text_scale';
const _kLocale = 'a11y_locale';

class AccessibilityState {
  final bool   highContrast;
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

final accessibilityProvider =
    StateNotifierProvider<AccessibilityNotifier, AccessibilityState>(
  (ref) => AccessibilityNotifier(),
);

class AccessibilityNotifier extends StateNotifier<AccessibilityState> {
  // [prefs] is optional — pass it in tests to avoid singleton races
  AccessibilityNotifier({SharedPreferences? prefs})
      : super(const AccessibilityState()) {
    _load(prefs);
  }

  Future<void> _load(SharedPreferences? injected) async {
    final prefs = injected ?? await SharedPreferences.getInstance();
    if (!mounted) return;
    state = AccessibilityState(
      highContrast:    prefs.getBool(_kHC)       ?? false,
      textScaleFactor: prefs.getDouble(_kScale)  ?? 1.0,
      locale:          prefs.getString(_kLocale) ?? 'en',
    );
  }

  Future<void> setHighContrast(bool v) async {
    state = state.copyWith(highContrast: v);
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kHC, v);
  }

  Future<void> setTextScale(double v) async {
    final clamped = v.clamp(1.0, 1.4);
    state = state.copyWith(textScaleFactor: clamped);
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_kScale, clamped);
  }

  Future<void> setLocale(String tag) async {
    state = state.copyWith(locale: tag);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLocale, tag);
  }

  void toggleHighContrast() => setHighContrast(!state.highContrast);
}
