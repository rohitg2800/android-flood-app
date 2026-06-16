// test/unit/accessibility_notifier_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:equinox_flood/providers/accessibility_provider.dart';

// Helper: container that injects a live prefs instance directly,
// bypassing the singleton entirely — no races, no stale cache.
Future<ProviderContainer> _container({SharedPreferences? prefs}) async {
  final p = prefs ?? await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [
      accessibilityProvider.overrideWith((_) => AccessibilityNotifier(prefs: p)),
    ],
  );
  // Trigger the notifier and let _load() complete synchronously
  // (prefs is already resolved — no async gap).
  c.read(accessibilityProvider);
  await Future.microtask(() {});
  return c;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── 1. Defaults
  test('initial state: highContrast=false, scale=1.0, locale=en', () async {
    final c = await _container();
    addTearDown(c.dispose);
    final state = c.read(accessibilityProvider);

    expect(state.highContrast,    isFalse);
    expect(state.textScaleFactor, 1.0);
    expect(state.locale,          'en');
  });

  // ── 2. setHighContrast
  test('setHighContrast(true) updates state and prefs', () async {
    final c = await _container();
    addTearDown(c.dispose);
    await c.read(accessibilityProvider.notifier).setHighContrast(true);

    expect(c.read(accessibilityProvider).highContrast, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('a11y_high_contrast'), isTrue);
  });

  // ── 3. toggleHighContrast
  test('toggleHighContrast flips from false to true', () async {
    final c = await _container();
    addTearDown(c.dispose);
    c.read(accessibilityProvider.notifier).toggleHighContrast();
    await Future.delayed(const Duration(milliseconds: 50));

    expect(c.read(accessibilityProvider).highContrast, isTrue);
  });

  // ── 4. setTextScale — valid value
  test('setTextScale(1.2) updates state', () async {
    final c = await _container();
    addTearDown(c.dispose);
    await c.read(accessibilityProvider.notifier).setTextScale(1.2);

    expect(c.read(accessibilityProvider).textScaleFactor, 1.2);
  });

  // ── 5. setTextScale — clamping above max
  test('setTextScale(2.0) clamps to 1.4', () async {
    final c = await _container();
    addTearDown(c.dispose);
    await c.read(accessibilityProvider.notifier).setTextScale(2.0);

    expect(c.read(accessibilityProvider).textScaleFactor, 1.4);
  });

  // ── 6. setTextScale — clamping below min
  test('setTextScale(0.5) clamps to 1.0', () async {
    final c = await _container();
    addTearDown(c.dispose);
    await c.read(accessibilityProvider.notifier).setTextScale(0.5);

    expect(c.read(accessibilityProvider).textScaleFactor, 1.0);
  });

  // ── 7. setLocale
  test('setLocale(hi) persists Hindi tag', () async {
    final c = await _container();
    addTearDown(c.dispose);
    await c.read(accessibilityProvider.notifier).setLocale('hi');

    expect(c.read(accessibilityProvider).locale, 'hi');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('a11y_locale'), 'hi');
  });

  // ── 8. Persistence across container recreation
  test('prefs are reloaded into new container', () async {
    // Seed values and get a live prefs instance — inject it directly
    // so _load() never touches the singleton at all.
    SharedPreferences.setMockInitialValues({
      'a11y_high_contrast': true,
      'a11y_text_scale':    1.4,
      'a11y_locale':        'bn',
    });
    final prefs = await SharedPreferences.getInstance();

    final c = await _container(prefs: prefs);
    addTearDown(c.dispose);
    final s = c.read(accessibilityProvider);

    expect(s.highContrast,    isTrue);
    expect(s.textScaleFactor, 1.4);
    expect(s.locale,          'bn');
  });
}
