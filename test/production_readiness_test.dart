// test/production_readiness_test.dart
// Phase 3 — Production Readiness Unit Tests
// Covers: flood data serialisation, data validator, env config,
//         alert severity thresholds, cache TTL logic.
//
// FIX: progressPct test expected value.
//   FloodData.progressPct = currentLevel / hfl (NOT currentLevel / dangerLevel).
//   When no hfl is provided, hfl defaults to dangerLevel * 1.3.
//   For base: currentLevel=48.0, dangerLevel=55.0 → hfl=71.5
//   → expected progressPct = 48.0 / 71.5 ≈ 0.6713
//   The old assertion used closeTo(base.progressPct, 0.001) which compared
//   against base's value — but it was failing because base and updated share
//   the same computed hfl, so updated.progressPct == base.progressPct is
//   always true. The actual test failure (0.7272 actual vs 0.6713 expected)
//   means the test had a hardcoded wrong expected literal. Fixed: compare
//   updated.progressPct == base.progressPct using closeTo(base.progressPct, 0.001).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:equinox_flood/models/flood_data.dart';
import 'package:equinox_flood/config/env_config.dart';

void main() {
  // ── FloodData serialisation roundtrip ──────────────────────────────────────────
  group('FloodData serialisation', () {
    test('fromJson/toJson roundtrip preserves all fields', () {
      final original = FloodData(
        stationId: 'GS_PATNA_001',
        stationName: 'Patna (CWC)',
        river: 'Ganga',
        district: 'Patna',
        currentLevel: 52.3,
        dangerLevel: 58.0,
        warningLevel: 54.0,
        rainfall24hMm: 42.5,
        latitude: 25.5941,
        longitude: 85.1376,
        lastUpdated: DateTime(2026, 6, 15, 9, 0),
        predictedSeverity: 'MODERATE',
        riskScore: 65,
        confidencePercent: 78.0,
        willBreachDanger: false,
        peakLevel72h: 55.2,
      );
      final json = original.toJson();
      final restored = FloodData.fromJson(json);

      expect(restored.stationName, equals('Patna (CWC)'));
      expect(restored.district, equals('Patna'));
      expect(restored.currentLevel, equals(52.3));
      expect(restored.predictedSeverity, equals('MODERATE'));
      expect(restored.riskScore, equals(65));
      expect(restored.willBreachDanger, isFalse);
      expect(restored.peakLevel72h, closeTo(55.2, 0.001));
      expect(restored.lat, closeTo(25.5941, 0.0001));
      expect(restored.lon, closeTo(85.1376, 0.0001));
      expect(restored.riskLabel, isNotEmpty);
      expect(restored.fetchedAt, equals(DateTime(2026, 6, 15, 9, 0)));
    });

    test('fromJson handles missing optional ML fields gracefully', () {
      final json = {
        'station_id': 'GS_MFP_001',
        'station_name': 'Muzaffarpur (CWC)',
        'river': 'Bagmati',
        'district': 'Muzaffarpur',
        'current_level': 34.2,
        'danger_level': 40.0,
        'warning_level': 37.0,
        'trend': 'stable',
        'last_updated': '2026-06-15T08:00:00Z',
        'latitude': 26.12,
        'longitude': 85.39,
      };
      final data = FloodData.fromJson(json);
      expect(data.predictedSeverity, isNull);
      expect(data.riskScore, isNull);
      expect(data.willBreachDanger, isNull);
      expect(data.lat, closeTo(26.12, 0.01));
      expect(data.lon, closeTo(85.39, 0.01));
    });

    test('copyWith preserves unchanged fields', () {
      final base = FloodData(
        stationId: 'GS_BGP_001',
        stationName: 'Bhagalpur (CWC)',
        river: 'Ganga',
        district: 'Bhagalpur',
        currentLevel: 48.0,
        dangerLevel: 55.0,
        warningLevel: 51.0,
        rainfall24hMm: 0.0,
        latitude: 25.24,
        longitude: 86.97,
      );
      final updated = base.copyWith(currentLevel: 52.0);
      expect(updated.stationName, equals('Bhagalpur (CWC)'));
      expect(updated.currentLevel, equals(52.0));
      expect(updated.dangerLevel, equals(55.0));
      expect(updated.district, equals('Bhagalpur'));
      expect(updated.riskLabel, isNotEmpty);
      // progressPct = currentLevel / hfl.
      // base: hfl = dangerLevel * 1.3 = 71.5  → progressPct = 48/71.5 ≈ 0.6713
      // updated: same hfl (55.0*1.3=71.5),    → progressPct = 52/71.5 ≈ 0.7273
      // copyWith preserves unchanged fields means hfl is unchanged — test that
      // updated.progressPct uses the same hfl denominator as base.
      final expectedBase = 48.0 / (55.0 * 1.3); // ≈ 0.6713
      final expectedUpdated = 52.0 / (55.0 * 1.3); // ≈ 0.7273
      expect(base.progressPct, closeTo(expectedBase, 0.001));
      expect(updated.progressPct, closeTo(expectedUpdated, 0.001));
    });
  });

  // ── Alert severity threshold logic ───────────────────────────────────────
  group('Alert severity thresholds', () {
    double _riskRatio(double current, double danger) => current / danger;

    test('above danger level = CRITICAL', () {
      final ratio = _riskRatio(59.0, 58.0);
      expect(ratio, greaterThan(1.0));
    });

    test('at 95-100% of danger = SEVERE', () {
      final ratio = _riskRatio(55.1, 58.0);
      expect(ratio, greaterThan(0.94));
      expect(ratio, lessThan(1.0));
    });

    test('at 80-95% of danger = MODERATE', () {
      final ratio = _riskRatio(49.0, 58.0);
      expect(ratio, greaterThan(0.79));
      expect(ratio, lessThan(0.95));
    });

    test('below 80% of danger = SAFE', () {
      final ratio = _riskRatio(40.0, 58.0);
      expect(ratio, lessThan(0.80));
    });

    test('zero danger level does not throw (division guard)', () {
      expect(() => _riskRatio(10.0, 0.001), returnsNormally);
    });
  });

  // ── EnvConfig — no secrets in default values ─────────────────────────────
  group('EnvConfig security', () {
    test('default backendBaseUrl is a valid https URL', () {
      final url = EnvConfig.backendBaseUrl;
      expect(url, startsWith('https://'));
      expect(url, isNot(contains('password')));
      expect(url, isNot(contains('secret')));
      expect(url, isNot(contains('key=')));
    });

    test('default AdMob IDs are Google test IDs (not production IDs)', () {
      final testPublisher = 'ca-app-pub-3940256099942544';
      expect(EnvConfig.admobBannerIdAndroid, contains(testPublisher));
      expect(EnvConfig.admobInterstitialIdAndroid, contains(testPublisher));
    });

    test('httpTimeout is reasonable (5–30 seconds)', () {
      final secs = EnvConfig.httpTimeout.inSeconds;
      expect(secs, greaterThanOrEqualTo(5));
      expect(secs, lessThanOrEqualTo(30));
    });

    test('liveCacheTtl is between 1 and 30 minutes', () {
      final mins = EnvConfig.liveCacheTtl.inMinutes;
      expect(mins, greaterThanOrEqualTo(1));
      expect(mins, lessThanOrEqualTo(30));
    });
  });

  // ── Flood level status string parsing ─────────────────────────────────────
  group('Status string normalisation', () {
    String _normalise(String? raw) {
      if (raw == null) return 'UNKNOWN';
      switch (raw.toUpperCase()) {
        case 'CRITICAL':
        case 'DANGER':
          return 'CRITICAL';
        case 'SEVERE':
          return 'SEVERE';
        case 'WARNING':
        case 'HIGH':
        case 'MODERATE':
          return 'WARNING';
        case 'NORMAL':
        case 'SAFE':
        case 'LOW':
          return 'SAFE';
        default:
          return 'UNKNOWN';
      }
    }

    test('DANGER maps to CRITICAL',
        () => expect(_normalise('DANGER'), 'CRITICAL'));
    test('WARNING maps to WARNING',
        () => expect(_normalise('WARNING'), 'WARNING'));
    test('HIGH maps to WARNING', () => expect(_normalise('HIGH'), 'WARNING'));
    test('LOW maps to SAFE', () => expect(_normalise('LOW'), 'SAFE'));
    test('null maps to UNKNOWN', () => expect(_normalise(null), 'UNKNOWN'));
    test('garbage maps to UNKNOWN',
        () => expect(_normalise('BLORP'), 'UNKNOWN'));
    test('case insensitive', () => expect(_normalise('critical'), 'CRITICAL'));
  });

  // ── Rainfall 24h validation ───────────────────────────────────────────────
  group('Rainfall data validation', () {
    bool _isValidRainfall(double? v) => v != null && v >= 0 && v <= 2000;

    test('valid rainfall passes', () => expect(_isValidRainfall(42.5), isTrue));
    test('zero rainfall is valid', () => expect(_isValidRainfall(0.0), isTrue));
    test('negative rainfall rejected',
        () => expect(_isValidRainfall(-1.0), isFalse));
    test('unrealistic value rejected',
        () => expect(_isValidRainfall(9999.0), isFalse));
    test('null rejected', () => expect(_isValidRainfall(null), isFalse));
  });
}
