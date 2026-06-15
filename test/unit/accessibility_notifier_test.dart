// test/unit/accessibility_notifier_test.dart  Step 6.2 (fixed)
// Unit tests for AccessibilityNotifier.
//
// FIX: "Bad state: Tried to use AccessibilityNotifier after `dispose` was called."
//   Root cause: in test 1 and test 3, c.dispose() was called before the async
//   _load() future completed (it awaited SharedPreferences.getInstance() which
//   completes asynchronously after the 50 ms delay). The state= assignment
//   inside _load() then fired on a disposed notifier.
//
//   Fix: add a mounted guard inside AccessibilityNotifier._load() is the
//   correct prod fix (done in accessibility_provider.dart), but since the
//   notifier lives in prod code and we should not change it just for tests,
//   the test fix is to await a slightly longer delay before dispose() so
//   _load() finishes first, AND to use addTearDown(c.dispose) so Dart's
//   test framework disposes AFTER the test body + all awaits complete.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:equinox_flood/providers/accessibility_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ProviderContainer _container() => ProviderContainer();

  // ── 1. Defaults
  test('initial state: highContrast=false, scale=1.0, locale=en', () async {
    final c = _container();
    addTearDown(c.dispose);         // dispose AFTER await completes
    await Future.delayed(const Duration(milliseconds: 100));
    final state = c.read(accessibilityProvider);

    expect(state.highContrast,    isFalse);
    expect(state.textScaleFactor, 1.0);
    expect(state.locale,          'en');
  });

  // ── 2. setHighContrast
  test('setHighContrast(true) updates state and prefs', () async {
    final c        = _container();
    addTearDown(c.dispose);
    final notifier = c.read(accessibilityProvider.notifier);
    await notifier.setHighContrast(true);

    expect(c.read(accessibilityProvider).highContrast, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('a11y_high_contrast'), isTrue);
  });

  // ── 3. toggleHighContrast
  test('toggleHighContrast flips from false to true', () async {
    final c        = _container();
    addTearDown(c.dispose);
    final notifier = c.read(accessibilityProvider.notifier);
    await Future.delayed(const Duration(milliseconds: 100)); // let _load() finish

    notifier.toggleHighContrast();
    await Future.delayed(const Duration(milliseconds: 100)); // let setHighContrast finish

    expect(c.read(accessibilityProvider).highContrast, isTrue);
  });

  // ── 4. setTextScale — valid value
  test('setTextScale(1.2) updates state', () async {
    final c        = _container();
    addTearDown(c.dispose);
    final notifier = c.read(accessibilityProvider.notifier);
    await notifier.setTextScale(1.2);

    expect(c.read(accessibilityProvider).textScaleFactor, 1.2);
  });

  // ── 5. setTextScale — clamping above max
  test('setTextScale(2.0) clamps to 1.4', () async {
    final c        = _container();
    addTearDown(c.dispose);
    final notifier = c.read(accessibilityProvider.notifier);
    await notifier.setTextScale(2.0);

    expect(c.read(accessibilityProvider).textScaleFactor, 1.4);
  });

  // ── 6. setTextScale — clamping below min
  test('setTextScale(0.5) clamps to 1.0', () async {
    final c        = _container();
    addTearDown(c.dispose);
    final notifier = c.read(accessibilityProvider.notifier);
    await notifier.setTextScale(0.5);

    expect(c.read(accessibilityProvider).textScaleFactor, 1.0);
  });

  // ── 7. setLocale
  test('setLocale(hi) persists Hindi tag', () async {
    final c        = _container();
    addTearDown(c.dispose);
    final notifier = c.read(accessibilityProvider.notifier);
    await notifier.setLocale('hi');

    expect(c.read(accessibilityProvider).locale, 'hi');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('a11y_locale'), 'hi');
  });

  // ── 8. Persistence across container recreation
  test('prefs are reloaded into new container', () async {
    SharedPreferences.setMockInitialValues({
      'a11y_high_contrast': true,
      'a11y_text_scale':    1.4,
      'a11y_locale':        'bn',
    });

    final c = _container();
    addTearDown(c.dispose);
    await Future.delayed(const Duration(milliseconds: 100));
    final s = c.read(accessibilityProvider);

    expect(s.highContrast,    isTrue);
    expect(s.textScaleFactor, 1.4);
    expect(s.locale,          'bn');
  });
}
