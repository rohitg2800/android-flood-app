// test/unit/alert_engine_test.dart  v4 — correct package equinox_flood
import 'package:flutter_test/flutter_test.dart';
import 'package:equinox_flood/services/alert_engine.dart';
import 'package:equinox_flood/models/river_station.dart';

RiverStation _station({
  required double current,
  double warning = 8.0,
  double danger  = 10.0,
  double hfl     = 12.0,
}) =>
    RiverStation(
      city:    'TestCity',
      state:   'Bihar',
      river:   'Ganga',
      station: 'GS001',
      current: current,
      warning: warning,
      danger:  danger,
      hfl:     hfl,
    );

void main() {
  test('no alert when level < warningLevel', () {
    final alerts = AlertEngine.instance.evaluateMerged([_station(current: 7.5)]);
    expect(alerts, isEmpty);
  });

  test('INFO alert when warningLevel <= level < 85% dangerLevel', () {
    final alerts = AlertEngine.instance.evaluateMerged([_station(current: 8.4)]);
    expect(alerts.length, 1);
    expect(alerts.first.severity, AlertSeverity.info);
  });

  test('WARNING alert when level >= 85% dangerLevel and < dangerLevel', () {
    final alerts = AlertEngine.instance.evaluateMerged([_station(current: 9.0)]);
    expect(alerts.length, 1);
    expect(alerts.first.severity, AlertSeverity.warning);
  });

  test('CRITICAL alert when level >= dangerLevel and < 98% HFL', () {
    final alerts = AlertEngine.instance.evaluateMerged([_station(current: 10.5)]);
    expect(alerts.length, 1);
    expect(alerts.first.severity, AlertSeverity.critical);
  });

  test('EMERGENCY alert when level >= 98% HFL', () {
    final alerts = AlertEngine.instance.evaluateMerged([_station(current: 12.0)]);
    expect(alerts.length, 1);
    expect(alerts.first.severity, AlertSeverity.emergency);
  });

  test('alert carries correct stationName and district', () {
    final alerts = AlertEngine.instance.evaluateMerged([_station(current: 10.5)]);
    expect(alerts.first.stationName, 'GS001');
    expect(alerts.first.district,    'TestCity');
  });

  test('only stations above warning threshold emit alerts', () {
    final alerts = AlertEngine.instance.evaluateMerged([
      _station(current: 7.5),
      _station(current: 10.5),
    ]);
    expect(alerts.length, 1);
    expect(alerts.first.severity, AlertSeverity.critical);
  });

  test('no emergency when hfl is 0 even if level is very high', () {
    final alerts = AlertEngine.instance.evaluateMerged([
      _station(current: 50.0, hfl: 0),
    ]);
    expect(alerts.first.severity, AlertSeverity.critical);
  });
}
