// flood_engine_test.dart
// Comprehensive unit tests for lib/ml/flood_engine.dart
// Updated for v1.3 engine thresholds (PLAINS moderate=200.0, algorithm='v1.3')
// Run: flutter test test/flood_engine_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:equinox_flood/ml/flood_engine.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

FloodInput _makeInput({
  required String state,
  required double peak,
  double rain = 0,
  double duration = 3,
  double timeToPeak = 2,
  double recession = 3,
}) =>
    FloodInput(
      peakFloodLevelM: peak,
      eventDurationDays: duration,
      timeToPeakDays: timeToPeak,
      recessionTimeDay: recession,
      t1d: rain / 7,
      t2d: rain / 7,
      t3d: rain / 7,
      t4d: rain / 7,
      t5d: rain / 7,
      t6d: rain / 7,
      t7d: rain / 7,
      state: state,
    );

void main() {
  // ─── 1. getStateEntry — lookup & normalisation ─────────────────────────────
  group('getStateEntry', () {
    test('returns maharashtra entry', () {
      final e = getStateEntry('Maharashtra');
      expect(e.region, 'COASTAL');
      expect(e.dangerLevelM, 13.0);
    });

    test('case-insensitive lookup', () {
      expect(getStateEntry('BIHAR').region, 'PLAINS');
      expect(getStateEntry('kerala').region, 'COASTAL');
    });

    test('alias orissa → odisha', () {
      final e = getStateEntry('orissa');
      expect(e.region, 'COASTAL');
      expect(e.primaryRivers, contains('Mahanadi'));
    });

    test('alias nct of delhi → delhi', () {
      final e = getStateEntry('NCT of Delhi');
      expect(e.usesAbsoluteElevation, isTrue);
    });

    test('alias j&k → jammu and kashmir', () {
      final e = getStateEntry('j&k');
      expect(e.region, 'HIMALAYAN');
    });

    test('unknown state falls back to PLAINS generic', () {
      final e = getStateEntry('Narnia');
      expect(e.region, 'PLAINS');
      expect(e.dangerLevelM, 11.0);
    });
  });

  // ─── 2. getRegionRainfallThresholds ───────────────────────────────────────
  group('getRegionRainfallThresholds', () {
    test('returns correct PLAINS thresholds (v1.3)', () {
      final t = getRegionRainfallThresholds('PLAINS');
      expect(t['moderate'], equals(200.0));
      expect(t['severe'], equals(350.0));
      expect(t['critical'], equals(500.0));
    });

    test('returns correct COASTAL thresholds (v1.3)', () {
      final t = getRegionRainfallThresholds('COASTAL');
      expect(t['moderate'], equals(150.0));
      expect(t['severe'], equals(300.0));
      expect(t['critical'], equals(500.0));
    });

    test('returns correct HIMALAYAN thresholds (v1.3)', () {
      final t = getRegionRainfallThresholds('HIMALAYAN');
      expect(t['moderate'], equals(200.0));
      expect(t['severe'], equals(350.0));
      expect(t['critical'], equals(550.0));
    });

    test('returns correct ARID thresholds (v1.3)', () {
      final t = getRegionRainfallThresholds('ARID');
      expect(t['moderate'], equals(80.0));
      expect(t['severe'], equals(160.0));
      expect(t['critical'], equals(280.0));
    });

    test('unknown region defaults to PLAINS (moderate=200.0)', () {
      final t = getRegionRainfallThresholds('UNKNOWN');
      expect(t['moderate'], equals(200.0));
    });
  });

  // ─── 3. severityFromEntry ─────────────────────────────────────────────────
  group('severityFromEntry', () {
    final bihar = getStateEntry('Bihar');

    test('LOW when both axes are below moderate', () {
      final sev = severityFromEntry(
        peakLevelM: 5.0,
        rainfall7dMm: 50.0,
        entry: bihar,
      );
      expect(sev, 'LOW');
    });

    test('MODERATE when peak crosses moderate threshold', () {
      final sev = severityFromEntry(
        peakLevelM: bihar.peakLevelM['moderate']!,
        rainfall7dMm: 50.0,
        entry: bihar,
      );
      expect(sev, 'MODERATE');
    });

    test('SEVERE when peak crosses severe threshold', () {
      final sev = severityFromEntry(
        peakLevelM: bihar.peakLevelM['severe']!,
        rainfall7dMm: 50.0,
        entry: bihar,
      );
      expect(sev, 'SEVERE');
    });

    test('CRITICAL when peak crosses critical threshold', () {
      final sev = severityFromEntry(
        peakLevelM: bihar.peakLevelM['critical']!,
        rainfall7dMm: 50.0,
        entry: bihar,
      );
      expect(sev, 'CRITICAL');
    });

    test('rain axis can dominate when peak is low', () {
      final sev = severityFromEntry(
        peakLevelM: 5.0,
        rainfall7dMm: 210.0,
        entry: bihar,
      );
      expect(sev, 'MODERATE');
    });

    test('higher axis wins (dual-axis max)', () {
      final sev = severityFromEntry(
        peakLevelM: bihar.peakLevelM['critical']!,
        rainfall7dMm: 50.0,
        entry: bihar,
      );
      expect(sev, 'CRITICAL');
    });
  });

  // ─── 4. runOnDeviceEngine — output invariants ─────────────────────────────
  group('runOnDeviceEngine — output invariants', () {
    test('result.severity is one of the four valid labels', () {
      final r =
          runOnDeviceEngine(_makeInput(state: 'Bihar', peak: 10.0, rain: 150));
      expect(['LOW', 'MODERATE', 'SEVERE', 'CRITICAL'], contains(r.severity));
    });

    test('confidencePercent is between 0 and 100', () {
      final r = runOnDeviceEngine(_makeInput(state: 'Bihar', peak: 10.0));
      expect(r.confidencePercent, inInclusiveRange(0.0, 100.0));
    });

    test('riskScore is between 0 and 100', () {
      final r = runOnDeviceEngine(_makeInput(state: 'Bihar', peak: 10.0));
      expect(r.riskScore, inInclusiveRange(0, 100));
    });

    test('probabilities sum to ~100', () {
      final r = runOnDeviceEngine(_makeInput(state: 'Bihar', peak: 10.0));
      final total = r.probabilities.values.fold(0.0, (a, b) => a + b);
      expect(total, closeTo(100.0, 1.0));
    });

    test('algorithm string mentions v1.3', () {
      final r = runOnDeviceEngine(_makeInput(state: 'Bihar', peak: 10.0));
      expect(r.algorithm, contains('v1.3'));
    });

    test('isOfflineEstimate is true (no API in on-device path)', () {
      final r = runOnDeviceEngine(_makeInput(state: 'Bihar', peak: 10.0));
      expect(r.isOfflineEstimate, isTrue);
    });

    test('usedApi is false', () {
      final r = runOnDeviceEngine(_makeInput(state: 'Bihar', peak: 10.0));
      expect(r.usedApi, isFalse);
    });

    test('alert emoji is one of the three defined symbols', () {
      final r = runOnDeviceEngine(_makeInput(state: 'Bihar', peak: 10.0));
      expect(['🚨', '⚠️', '🟢'], contains(r.alert));
    });

    test('monitoringLevel is non-empty', () {
      final r = runOnDeviceEngine(_makeInput(state: 'Bihar', peak: 10.0));
      expect(r.monitoringLevel, isNotEmpty);
    });

    test('monitoringAction is non-empty', () {
      final r = runOnDeviceEngine(_makeInput(state: 'Bihar', peak: 10.0));
      expect(r.monitoringAction, isNotEmpty);
    });
  });

  // ─── 5. runOnDeviceEngine — severity monotonicity ─────────────────────────
  group('runOnDeviceEngine — severity escalates with peak', () {
    final levels = [4.0, 8.0, 11.0, 13.5];
    final order = {'LOW': 0, 'MODERATE': 1, 'SEVERE': 2, 'CRITICAL': 3};

    test('severity rank is non-decreasing as peak increases (Bihar)', () {
      int prevRank = -1;
      for (final peak in levels) {
        final r = runOnDeviceEngine(_makeInput(state: 'Bihar', peak: peak));
        final rank = order[r.severity]!;
        expect(rank, greaterThanOrEqualTo(prevRank),
            reason: 'severity regressed at peak=$peak (${r.severity})');
        prevRank = rank;
      }
    });
  });

  // ─── 6. danger-level guard ─────────────────────────────────────────────────
  group('dangerLevelGuard', () {
    test('CRITICAL capped to SEVERE below HFL when level is at dangerM', () {
      final entry = getStateEntry('Maharashtra');
      final sev = severityFromEntry(
        peakLevelM: entry.dangerLevelM,
        rainfall7dMm: 50.0,
        entry: entry,
        riverLevelM: entry.dangerLevelM,
      );
      expect(['LOW', 'MODERATE', 'SEVERE'], contains(sev));
    });

    test('severity unchanged when level exceeds HFL', () {
      final entry = getStateEntry('Maharashtra');
      final sev = severityFromEntry(
        peakLevelM: entry.peakLevelM['critical']!,
        rainfall7dMm: 400.0,
        entry: entry,
        riverLevelM: entry.hflM + 1.0,
      );
      expect(sev, 'CRITICAL');
    });
  });

  // ─── 7. Full-India smoke — all 36 state entries ───────────────────────────
  group('Full India smoke test', () {
    final stateNames = [
      'Andhra Pradesh',
      'Arunachal Pradesh',
      'Assam',
      'Bihar',
      'Chhattisgarh',
      'Goa',
      'Gujarat',
      'Haryana',
      'Himachal Pradesh',
      'Jharkhand',
      'Karnataka',
      'Kerala',
      'Madhya Pradesh',
      'Maharashtra',
      'Manipur',
      'Meghalaya',
      'Mizoram',
      'Nagaland',
      'Odisha',
      'Punjab',
      'Rajasthan',
      'Sikkim',
      'Tamil Nadu',
      'Telangana',
      'Tripura',
      'Uttar Pradesh',
      'Uttarakhand',
      'West Bengal',
      'Andaman and Nicobar Islands',
      'Chandigarh',
      'Dadra and Nagar Haveli',
      'Delhi',
      'Jammu and Kashmir',
      'Ladakh',
      'Lakshadweep',
      'Puducherry',
    ];

    test('every state returns a valid engine result', () {
      for (final state in stateNames) {
        final entry = getStateEntry(state);
        final r = runOnDeviceEngine(
          _makeInput(state: state, peak: entry.dangerLevelM * 0.9),
        );
        expect(['LOW', 'MODERATE', 'SEVERE', 'CRITICAL'], contains(r.severity),
            reason: '$state returned unexpected severity');
        expect(r.riskScore, inInclusiveRange(0, 100),
            reason: '$state riskScore out of range');
      }
    });
  });
}
