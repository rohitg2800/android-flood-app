// lib/providers/accessibility_provider.dart  Steps 5.2 / 5.5
// Persisted accessibility preferences:
//   • highContrast   — bool  (swaps to WCAG AA palette)
//   • textScaleFactor — double (1.0 | 1.2 | 1.4)
//   • locale         — String locale tag ('en' | 'hi' | 'bn' | 'or')
//
// How to wire in MaterialApp:
//   textScaleFactor: ref.watch(accessibilityProvider).textScaleFactor,
//   locale:          Locale(ref.watch(accessibilityProvider).locale),
//   theme:           ref.watch(accessibilityProvider).highContrast
//                      ? highContrastTheme : appTheme,

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kHC       = 'a11y_high_contrast';
const _kScale    = 'a11y_text_scale';
const _kLocale   = 'a11y_locale';

// ── State model ───────────────────────────────────────────────────────────────

class AccessibilityState {
  final bool   highContrast;
  final double textScaleFactor;
  final String locale;           // BCP-47 tag: 'en', 'hi', 'bn', 'or'

  const AccessibilityState({
    this.highContrast    = false,
    this.textScaleFactor = 1.0,
    this.locale          = 'en',
  });

  AccessibilityState copyWith({
    bool?   highContrast,
    double? textScaleFactor,
    String? locale,
  }) =>
      AccessibilityState(
        highContrast:    highContrast    ?? this.highContrast,
        textScaleFactor: textScaleFactor ?? this.textScaleFactor,
        locale:          locale          ?? this.locale,
      );
}

// ── Provider ────────────────────────────────────────────────────────────────

final accessibilityProvider =
    StateNotifierProvider<AccessibilityNotifier, AccessibilityState>(
  (ref) => AccessibilityNotifier(),
);

// ── Notifier ────────────────────────────────────────────────────────────────

class AccessibilityNotifier
    extends StateNotifier<AccessibilityState> {
  AccessibilityNotifier() : super(const AccessibilityState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AccessibilityState(
      highContrast:    prefs.getBool(_kHC)          ?? false,
      textScaleFactor: prefs.getDouble(_kScale)     ?? 1.0,
      locale:          prefs.getString(_kLocale)    ?? 'en',
    );
  }

  // ── Public API ──────────────────────────────────────────────────────

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
