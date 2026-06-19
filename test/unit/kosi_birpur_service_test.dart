// test/unit/kosi_birpur_service_test.dart
// I-15: Unit tests for Birpur level constants and classification

import 'package:flutter_test/flutter_test.dart';
import 'package:flood_watch/services/kosi_birpur_service.dart';

void main() {
  group('Birpur constants sanity', () {
    test('all constants are positive doubles', () {
      for (final v in [
        kBirpurDatumOffset, kBirpurDangerLevel, kBirpurWarningLevel,
        kBirpurNormalLevel, kBirpurHFL,
        kBirpurWarningDischarge, kBirpurDangerDischarge,
      ]) {
        expect(v, isPositive);
      }
    });

    test('level ordering: normal < warning < danger', () {
      expect(kBirpurNormalLevel,  lessThan(kBirpurWarningLevel));
      expect(kBirpurWarningLevel, lessThan(kBirpurDangerLevel));
    });

    test('datum offset converts: gauge 0.0m => 139.32m absolute', () {
      expect(0.0 + kBirpurDatumOffset, closeTo(139.32, 0.01));
    });
  });

  group('Level classification logic', () {
    test('74.5m: above warning, below danger', () {
      const level = 74.5;
      expect(level >= kBirpurWarningLevel, isTrue);
      expect(level >= kBirpurDangerLevel,  isFalse);
    });

    test('76.02m: at danger / HFL', () {
      const level = 76.02;
      expect(level >= kBirpurDangerLevel, isTrue);
      expect(level >= kBirpurHFL,         isTrue);
    });

    test('70.0m: normal (below warning)', () {
      const level = 70.0;
      expect(level < kBirpurWarningLevel, isTrue);
    });
  });
}
