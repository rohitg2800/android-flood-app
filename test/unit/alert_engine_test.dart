// test/unit/alert_engine_test.dart  Step 6.2
// Unit tests for AlertEngine threshold evaluation:
//   • no alert when level < warning threshold
//   • MODERATE alert when warning <= level < danger
//   • SEVERE alert when danger <= level < HFL
//   • CRITICAL alert when level >= HFL
//   • no duplicate alert within debounce window
//   • alert fires again after cooldown expires

import 'package:flutter_test/flutter_test.dart';
import 'package:flood_app/services/alert_engine.dart';
import 'package:flood_app/models/alert_model.dart';
import 'package:flood_app/models/flood_data.dart';

FloodData _station({
  required double current,
  double warning = 8.0,
  double danger  = 10.0,
  double hfl     = 12.0,
}) =>
    FloodData.testInstance(
      stationId:    'GS001',
      city:         'TestCity',
      currentLevel: current,
      warningLevel: warning,
      dangerLevel:  danger,
      hfl:          hfl,
    );

void main() {
  late AlertEngine engine;

  setUp(() {
    engine = AlertEngine.forTesting();
  });

  // ── 1. Below warning — no alert
  test('no alert when level < warningLevel', () {
    final alerts = engine.evaluate(_station(current: 7.5));
    expect(alerts, isEmpty);
  });

  // ── 2. At warning — MODERATE
  test('MODERATE alert when level >= warningLevel and < dangerLevel', () {
    final alerts = engine.evaluate(_station(current: 8.5));
    expect(alerts.length, 1);
    expect(alerts.first.severity, AlertSeverity.moderate);
  });

  // ── 3. At danger — SEVERE
  test('SEVERE alert when level >= dangerLevel and < HFL', () {
    final alerts = engine.evaluate(_station(current: 10.5));
    expect(alerts.length, 1);
    expect(alerts.first.severity, AlertSeverity.severe);
  });

  // ── 4. At HFL — CRITICAL
  test('CRITICAL alert when level >= HFL', () {
    final alerts = engine.evaluate(_station(current: 12.0));
    expect(alerts.length, 1);
    expect(alerts.first.severity, AlertSeverity.critical);
  });

  // ── 5. No duplicate within debounce window
  test('second evaluate with same level returns no new alert (debounce)', () {
    engine.evaluate(_station(current: 10.5)); // first — SEVERE
    final second = engine.evaluate(_station(current: 10.5));
    expect(second, isEmpty); // debounced
  });

  // ── 6. Escalation generates new alert
  test('escalation from MODERATE to SEVERE generates new alert', () {
    engine.evaluate(_station(current: 8.5));  // MODERATE
    final alerts = engine.evaluate(_station(current: 10.5)); // SEVERE
    expect(alerts.length, 1);
    expect(alerts.first.severity, AlertSeverity.severe);
  });

  // ── 7. Below warning after alert — state resets
  test('dropping below warning after alert resets debounce state', () {
    engine.evaluate(_station(current: 10.5));  // SEVERE
    engine.evaluate(_station(current: 6.0));   // back to safe
    final alerts = engine.evaluate(_station(current: 10.5)); // SEVERE again
    expect(alerts.length, 1); // should fire again
  });

  // ── 8. Alert metadata
  test('alert contains correct stationId and city', () {
    final alerts = engine.evaluate(_station(current: 10.5));
    expect(alerts.first.stationId, 'GS001');
    expect(alerts.first.city,      'TestCity');
  });
}
