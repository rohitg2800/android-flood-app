// test/constants_domain_test.dart
// Unit tests for the 4 new domain-split constant files.
// Run: flutter test test/constants_domain_test.dart

// ignore_for_file: deprecated_member_use

import 'package:flutter_test/flutter_test.dart';
import 'package:equinox_flood/constants/constants.dart';
import 'package:equinox_flood/constants.dart'; // deprecated shim — only for backward-compat tests

void main() {
  // ── AppConfig ──────────────────────────────────────────────────────────────
  group('AppConfig', () {
    test('endpoints start with /', () {
      for (final ep in [
        AppConfig.healthEndpoint,
        AppConfig.liveTelemetryEndpoint,
        AppConfig.liveLevelsEndpoint,
        AppConfig.criticalAlertsEndpoint,
        AppConfig.predictLegacyEndpoint,
        AppConfig.weatherCurrentEndpoint,
        AppConfig.weatherForecastEndpoint,
      ]) {
        expect(ep, startsWith('/'), reason: 'endpoint: $ep');
      }
    });

    test('pollingInterval is positive', () {
      expect(AppConfig.pollingInterval.inSeconds, greaterThan(0));
    });

    test('maxRetries >= 1', () {
      expect(AppConfig.maxRetries, greaterThanOrEqualTo(1));
    });

    test('shortAnimDuration < longAnimDuration', () {
      expect(
        AppConfig.shortAnimDuration.inMilliseconds,
        lessThan(AppConfig.longAnimDuration.inMilliseconds),
      );
    });
  });

  // ── FloodThresholds ────────────────────────────────────────────────────────
  group('FloodThresholds', () {
    test('capacity thresholds are in ascending order', () {
      expect(FloodThresholds.moderate, lessThan(FloodThresholds.high));
      expect(FloodThresholds.high, lessThan(FloodThresholds.critical));
    });

    test('default levels are in ascending order', () {
      expect(FloodThresholds.defaultSafeLevel,
          lessThan(FloodThresholds.defaultWarningLevel));
      expect(FloodThresholds.defaultWarningLevel,
          lessThan(FloodThresholds.defaultDangerLevel));
    });

    test('riskColors contains all four severity keys', () {
      for (final k in ['LOW', 'MODERATE', 'SEVERE', 'CRITICAL']) {
        expect(FloodThresholds.riskColors, contains(k));
      }
    });

    test('riskColors values are valid ARGB ints', () {
      for (final v in FloodThresholds.riskColors.values) {
        expect(v, greaterThanOrEqualTo(0xFF000000));
        expect(v, lessThanOrEqualTo(0xFFFFFFFF));
      }
    });

    test('riskIcons contains all four severity keys', () {
      for (final k in ['LOW', 'MODERATE', 'SEVERE', 'CRITICAL']) {
        expect(FloodThresholds.riskIcons, contains(k));
      }
    });
  });

  // ── AlertChannels ──────────────────────────────────────────────────────────
  group('AlertChannels', () {
    test('channel IDs are non-empty strings', () {
      expect(AlertChannels.criticalId, isNotEmpty);
      expect(AlertChannels.warningId, isNotEmpty);
    });

    test('channel IDs are distinct', () {
      expect(AlertChannels.criticalId, isNot(AlertChannels.warningId));
    });

    test('channel names are non-empty', () {
      expect(AlertChannels.criticalName, isNotEmpty);
      expect(AlertChannels.warningName, isNotEmpty);
    });
  });

  // ── IndiaGeodata ───────────────────────────────────────────────────────────
  group('IndiaGeodata.states', () {
    test('contains 36 entries', () {
      expect(IndiaGeodata.states.length, 36);
    });

    test('contains all 28 states', () {
      for (final s in [
        'Maharashtra',
        'Kerala',
        'Assam',
        'Bihar',
        'Uttar Pradesh',
        'West Bengal',
        'Odisha',
        'Gujarat',
        'Rajasthan',
        'Karnataka',
      ]) {
        expect(IndiaGeodata.states, contains(s));
      }
    });

    test('contains 8 UTs', () {
      const uts = [
        'Delhi',
        'Jammu and Kashmir',
        'Ladakh',
        'Chandigarh',
        'Puducherry',
        'Andaman and Nicobar Islands',
        'Lakshadweep',
        'Dadra and Nagar Haveli and Daman and Diu',
      ];
      for (final ut in uts) {
        expect(IndiaGeodata.states, contains(ut));
      }
    });

    test('no duplicate state names', () {
      final unique = IndiaGeodata.states.toSet();
      expect(unique.length, IndiaGeodata.states.length);
    });
  });

  group('IndiaGeodata.monitoredCities', () {
    test('has at least 80 cities', () {
      expect(IndiaGeodata.monitoredCities.length, greaterThanOrEqualTo(80));
    });

    test('every city has required keys', () {
      const required = [
        'city',
        'state',
        'river',
        'lat',
        'lon',
        'danger_level',
        'warning_level',
        'risk',
        'flood_freq',
        'river_type',
        'zone',
      ];
      for (final city in IndiaGeodata.monitoredCities) {
        for (final key in required) {
          expect(city, contains(key),
              reason: 'Missing key "$key" in ${city["city"]}');
        }
      }
    });

    test('danger_level > warning_level for all cities', () {
      for (final city in IndiaGeodata.monitoredCities) {
        final danger = (city['danger_level'] as num).toDouble();
        final warning = (city['warning_level'] as num).toDouble();
        expect(danger, greaterThan(warning),
            reason: '${city["city"]}: danger($danger) <= warning($warning)');
      }
    });

    test('flood_freq is between 0 and 1 for all cities', () {
      for (final city in IndiaGeodata.monitoredCities) {
        final ff = (city['flood_freq'] as num).toDouble();
        expect(ff, inInclusiveRange(0.0, 1.0),
            reason: '${city["city"]} flood_freq=$ff out of range');
      }
    });

    test('risk tag is one of allowed values', () {
      const allowed = {'LOW', 'MODERATE', 'HIGH', 'CRITICAL'};
      for (final city in IndiaGeodata.monitoredCities) {
        expect(allowed, contains(city['risk']),
            reason: '${city["city"]} has invalid risk: ${city["risk"]}');
      }
    });

    test('lat is in India bounding box (6–37°N)', () {
      for (final city in IndiaGeodata.monitoredCities) {
        final lat = (city['lat'] as num).toDouble();
        expect(lat, inInclusiveRange(6.0, 37.0),
            reason: '${city["city"]} lat=$lat out of India range');
      }
    });

    test('lon is in India bounding box (67–98°E)', () {
      for (final city in IndiaGeodata.monitoredCities) {
        final lon = (city['lon'] as num).toDouble();
        expect(lon, inInclusiveRange(67.0, 98.0),
            reason: '${city["city"]} lon=$lon out of India range');
      }
    });

    test('Delhi has MSL danger_level around 200–210', () {
      final delhi =
          IndiaGeodata.monitoredCities.firstWhere((c) => c['city'] == 'Delhi');
      expect(delhi['danger_level'], inInclusiveRange(200.0, 210.0));
    });

    test('no city name is duplicated within same state', () {
      final seen = <String, Set<String>>{};
      for (final city in IndiaGeodata.monitoredCities) {
        final state = city['state'] as String;
        final name = city['city'] as String;
        seen.putIfAbsent(state, () => {});
        expect(seen[state]!, isNot(contains(name)),
            reason: 'Duplicate city $name in $state');
        seen[state]!.add(name);
      }
    });
  });

  // ── Backward-compat: AppConstants delegates correctly ─────────────────────
  group('AppConstants backward-compat shim', () {
    test('AppConstants.criticalThreshold == FloodThresholds.critical', () {
      expect(AppConstants.criticalThreshold, FloodThresholds.critical);
    });

    test('AppConstants.indianStates == IndiaGeodata.states', () {
      expect(AppConstants.indianStates, IndiaGeodata.states);
    });

    test('AppConstants.criticalAlertChannelId == AlertChannels.criticalId', () {
      expect(AppConstants.criticalAlertChannelId, AlertChannels.criticalId);
    });
  });
}
