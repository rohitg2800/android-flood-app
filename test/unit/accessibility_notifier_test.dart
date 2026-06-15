// test/unit/accessibility_notifier_test.dart  Step 6.2
// Unit tests for AccessibilityNotifier:
//   • initial state defaults
//   • setHighContrast toggles and persists
//   • setTextScale clamps to [1.0, 1.4]
//   • setLocale updates locale string
//   • toggleHighContrast flips the flag

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flood_app/providers/accessibility_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ProviderContainer _container() => ProviderContainer();

  // ── 1. Defaults
  test('initial state: highContrast=false, scale=1.0, locale=en', () async {
    final c      = _container();
    // Wait for async _load()
    await Future.delayed(const Duration(milliseconds: 50));
    final state  = c.read(accessibilityProvider);

    expect(state.highContrast,    isFalse);
    expect(state.textScaleFactor, 1.0);
    expect(state.locale,          'en');
    c.dispose();
  });

  // ── 2. setHighContrast
  test('setHighContrast(true) updates state and prefs', () async {
    final c       = _container();
    final notifier = c.read(accessibilityProvider.notifier);
    await notifier.setHighContrast(true);

    expect(c.read(accessibilityProvider).highContrast, isTrue);

    // Verify persisted
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('a11y_high_contrast'), isTrue);
    c.dispose();
  });

  // ── 3. toggleHighContrast
  test('toggleHighContrast flips from false to true', () async {
    final c        = _container();
    final notifier = c.read(accessibilityProvider.notifier);
    await Future.delayed(const Duration(milliseconds: 50)); // load defaults

    notifier.toggleHighContrast();
    await Future.delayed(const Duration(milliseconds: 50));

    expect(c.read(accessibilityProvider).highContrast, isTrue);
    c.dispose();
  });

  // ── 4. setTextScale — valid value
  test('setTextScale(1.2) updates state', () async {
    final c       = _container();
    final notifier = c.read(accessibilityProvider.notifier);
    await notifier.setTextScale(1.2);

    expect(c.read(accessibilityProvider).textScaleFactor, 1.2);
    c.dispose();
  });

  // ── 5. setTextScale — clamping above max
  test('setTextScale(2.0) clamps to 1.4', () async {
    final c        = _container();
    final notifier = c.read(accessibilityProvider.notifier);
    await notifier.setTextScale(2.0);

    expect(c.read(accessibilityProvider).textScaleFactor, 1.4);
    c.dispose();
  });

  // ── 6. setTextScale — clamping below min
  test('setTextScale(0.5) clamps to 1.0', () async {
    final c        = _container();
    final notifier = c.read(accessibilityProvider.notifier);
    await notifier.setTextScale(0.5);

    expect(c.read(accessibilityProvider).textScaleFactor, 1.0);
    c.dispose();
  });

  // ── 7. setLocale
  test('setLocale(hi) persists Hindi tag', () async {
    final c        = _container();
    final notifier = c.read(accessibilityProvider.notifier);
    await notifier.setLocale('hi');

    expect(c.read(accessibilityProvider).locale, 'hi');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('a11y_locale'), 'hi');
    c.dispose();
  });

  // ── 8. Persistence across container recreation
  test('prefs are reloaded into new container', () async {
    // Write prefs manually
    SharedPreferences.setMockInitialValues({
      'a11y_high_contrast': true,
      'a11y_text_scale':    1.4,
      'a11y_locale':        'bn',
    });

    final c = _container();
    await Future.delayed(const Duration(milliseconds: 100));
    final s = c.read(accessibilityProvider);

    expect(s.highContrast,    isTrue);
    expect(s.textScaleFactor, 1.4);
    expect(s.locale,          'bn');
    c.dispose();
  });
}
