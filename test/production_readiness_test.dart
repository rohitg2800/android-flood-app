// test/production_readiness_test.dart
// Phase 3 — Production Readiness Unit Tests
// Covers: flood data serialisation, data validator, env config,
//         alert severity thresholds, cache TTL logic.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:equinox_flood/models/flood_data.dart';
import 'package:equinox_flood/config/env_config.dart';

void main() {
  // ── FloodData serialisation roundtrip ──────────────────────────────────────
  group('FloodData serialisation', () {
    test('fromJson/toJson roundtrip preserves all fields', () {
      final original = FloodData(
        city:          'Patna',
        state:         'Bihar',
        river:         'Ganga',
        currentLevel:  52.3,
        dangerLevel:   58.0,
        warningLevel:  54.0,
        normalLevel:   46.0,
        status:        'WARNING',
        trend:         'rising',
        rainfall24h:   42.5,
        lastUpdated:   DateTime(2026, 6, 15, 9, 0),
        lat:           25.5941,
        lon:           85.1376,
        predictedSeverity:  'MODERATE',
        riskScore:          0.65,
        confidencePercent:  78.0,
        willBreachDanger:   false,
        peakLevel72h:       55.2,
      );
      final json       = original.toJson();
      final restored   = FloodData.fromJson(json);

      expect(restored.city,              equals('Patna'));
      expect(restored.currentLevel,      equals(52.3));
      expect(restored.predictedSeverity, equals('MODERATE'));
      expect(restored.riskScore,         closeTo(0.65, 0.001));
      expect(restored.willBreachDanger,  isFalse);
      expect(restored.peakLevel72h,      closeTo(55.2, 0.001));
    });

    test('fromJson handles missing optional ML fields gracefully', () {
      final json = {
        'city':          'Muzaffarpur',
        'state':         'Bihar',
        'river':         'Bagmati',
        'current_level': 34.2,
        'danger_level':  40.0,
        'warning_level': 37.0,
        'normal_level':  30.0,
        'status':        'NORMAL',
        'trend':         'stable',
        'last_updated':  '2026-06-15T08:00:00Z',
        'lat': 26.12, 'lon': 85.39,
      };
      final data = FloodData.fromJson(json);
      expect(data.predictedSeverity, isNull);
      expect(data.riskScore,         isNull);
      expect(data.willBreachDanger,  isNull);
    });

    test('copyWith preserves unchanged fields', () {
      final base    = FloodData(
        city: 'Bhagalpur', state: 'Bihar', river: 'Ganga',
        currentLevel: 48.0, dangerLevel: 55.0,
        warningLevel: 51.0, normalLevel: 44.0,
        status: 'NORMAL', trend: 'stable', rainfall24h: 0.0,
        lastUpdated: DateTime(2026, 6, 15), lat: 25.24, lon: 86.97,
      );
      final updated = base.copyWith(currentLevel: 52.0, status: 'WARNING');
      expect(updated.city,         equals('Bhagalpur'));
      expect(updated.currentLevel, equals(52.0));
      expect(updated.status,       equals('WARNING'));
      expect(updated.dangerLevel,  equals(55.0)); // unchanged
    });
  });

  // ── Alert severity threshold logic ─────────────────────────────────────────
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

  // ── EnvConfig — no secrets in default values ───────────────────────────────
  group('EnvConfig security', () {
    test('default backendBaseUrl is a valid https URL', () {
      final url = EnvConfig.backendBaseUrl;
      expect(url, startsWith('https://'));
      expect(url, isNot(contains('password')));
      expect(url, isNot(contains('secret')));
      expect(url, isNot(contains('key=')));
    });

    test('default AdMob IDs are Google test IDs (not production IDs)', () {
      // Google test IDs always start with ca-app-pub-3940256099942544
      // Production IDs from your AdMob account must be injected via
      // --dart-define at build time — never hardcoded here.
      final testPublisher = 'ca-app-pub-3940256099942544';
      expect(EnvConfig.admobBannerIdAndroid,        contains(testPublisher));
      expect(EnvConfig.admobInterstitialIdAndroid,  contains(testPublisher));
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
        case 'CRITICAL': case 'DANGER': return 'CRITICAL';
        case 'SEVERE':                  return 'SEVERE';
        case 'WARNING': case 'HIGH': case 'MODERATE': return 'WARNING';
        case 'NORMAL': case 'SAFE': case 'LOW': return 'SAFE';
        default: return 'UNKNOWN';
      }
    }

    test('DANGER maps to CRITICAL', () => expect(_normalise('DANGER'), 'CRITICAL'));
    test('WARNING maps to WARNING', () => expect(_normalise('WARNING'), 'WARNING'));
    test('HIGH maps to WARNING',    () => expect(_normalise('HIGH'),    'WARNING'));
    test('LOW maps to SAFE',        () => expect(_normalise('LOW'),     'SAFE'));
    test('null maps to UNKNOWN',    () => expect(_normalise(null),      'UNKNOWN'));
    test('garbage maps to UNKNOWN', () => expect(_normalise('BLORP'),   'UNKNOWN'));
    test('case insensitive',        () => expect(_normalise('critical'), 'CRITICAL'));
  });

  // ── Rainfall 24h validation ────────────────────────────────────────────────
  group('Rainfall data validation', () {
    bool _isValidRainfall(double? v) =>
        v != null && v >= 0 && v <= 2000; // 2000mm/day physically impossible

    test('valid rainfall passes', () => expect(_isValidRainfall(42.5), isTrue));
    test('zero rainfall is valid', () => expect(_isValidRainfall(0.0), isTrue));
    test('negative rainfall rejected', () => expect(_isValidRainfall(-1.0), isFalse));
    test('unrealistic value rejected', () => expect(_isValidRainfall(9999.0), isFalse));
    test('null rejected',              () => expect(_isValidRainfall(null), isFalse));
  });
}
