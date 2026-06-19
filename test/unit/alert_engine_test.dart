// lib/services/alert_engine.dart  v5.0
//
// test(I-15): Unit tests for safety-critical alert threshold logic

import 'package:flutter_test/flutter_test.dart';
import 'package:flood_watch/services/alert_engine.dart';
import 'package:flood_watch/services/kosi_birpur_service.dart';

void main() {
  group('AlertSeverity', () {
    test('emergency has highest priority', () {
      expect(AlertSeverity.emergency.priority, greaterThan(AlertSeverity.critical.priority));
      expect(AlertSeverity.critical.priority,  greaterThan(AlertSeverity.warning.priority));
      expect(AlertSeverity.warning.priority,   greaterThan(AlertSeverity.info.priority));
    });

    test('labels are non-empty', () {
      for (final s in AlertSeverity.values) {
        expect(s.label, isNotEmpty);
      }
    });
  });

  group('AlertType', () {
    test('all types have displayName', () {
      for (final t in AlertType.values) {
        expect(t.displayName, isNotEmpty,
            reason: 'AlertType.\${t.name} has empty displayName');
      }
    });

    test('all types have label', () {
      for (final t in AlertType.values) {
        expect(t.label, isNotEmpty);
      }
    });
  });

  group('Birpur thresholds', () {
    test('danger > warning > normal', () {
      expect(kBirpurDangerLevel,  greaterThan(kBirpurWarningLevel));
      expect(kBirpurWarningLevel, greaterThan(kBirpurNormalLevel));
    });

    test('HFL equals danger level', () {
      expect(kBirpurHFL, equals(kBirpurDangerLevel));
    });

    test('danger discharge > warning discharge', () {
      expect(kBirpurDangerDischarge, greaterThan(kBirpurWarningDischarge));
    });

    test('datum offset is positive', () {
      expect(kBirpurDatumOffset, greaterThan(0));
    });

    test('level 76.02 is at or above danger', () {
      const level = 76.02;
      expect(level, greaterThanOrEqualTo(kBirpurDangerLevel));
    });

    test('level 73.70 is at or above warning but below danger', () {
      const level = 73.70;
      expect(level, greaterThanOrEqualTo(kBirpurWarningLevel));
      expect(level, lessThan(kBirpurDangerLevel));
    });

    test('level 71.00 is normal (below warning)', () {
      const level = 71.00;
      expect(level, lessThan(kBirpurWarningLevel));
    });
  });
}
