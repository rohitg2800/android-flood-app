// test/golden/ml_card_golden_test.dart
// Golden-image tests for the ML prediction card widget.
// Package name corrected: flood_app → equinox_flood.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:equinox_flood/providers/prediction_provider.dart';
import 'package:equinox_flood/theme/river_theme.dart';
import 'package:equinox_flood/models/flood_prediction.dart';
import 'package:equinox_flood/widgets/ml_card_test_export.dart';

// ── Helpers ────────────────────────────────────────────────────────────────

FloodPrediction _pred(String severity, {double riskScore = 50}) =>
    FloodPrediction(
      severity:       severity,
      riskScore:      riskScore,
      stationName:    'Patna (Ganga)',
      predictedLevel: 52.4,
      dangerLevel:    55.0,
      trend:          'Rising',
      confidence:     0.87,
      updatedAt:      DateTime(2026, 6, 15, 14, 0),
      isOffline:      false,
    );

Widget _wrap(FloodPrediction pred) => RiverTheme(
      child: ProviderScope(
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: MlCardTestExport(pred: pred),
            ),
          ),
        ),
      ),
    );

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() async {
    await loadAppFonts();
  });

  testGoldens('ML card — low risk', (tester) async {
    final pred = _pred('LOW', riskScore: 20);
    await tester.pumpWidgetBuilder(
      _wrap(pred),
      surfaceSize: const Size(400, 260),
    );
    await screenMatchesGolden(tester, 'ml_card_low_risk');
  });

  testGoldens('ML card — critical risk', (tester) async {
    final pred = _pred('CRITICAL', riskScore: 92);
    await tester.pumpWidgetBuilder(
      _wrap(pred),
      surfaceSize: const Size(400, 260),
    );
    await screenMatchesGolden(tester, 'ml_card_critical_risk');
  });

  testGoldens('ML card — offline mode', (tester) async {
    final offlinePred = FloodPrediction(
      severity:       'MODERATE',
      riskScore:      55,
      stationName:    'Bhagalpur (Ganga)',
      predictedLevel: 40.1,
      dangerLevel:    45.0,
      trend:          'Steady',
      confidence:     0.70,
      updatedAt:      DateTime(2026, 6, 14, 8, 0),
      isOffline:      true,
    );
    await tester.pumpWidgetBuilder(
      _wrap(offlinePred),
      surfaceSize: const Size(400, 260),
    );
    await screenMatchesGolden(tester, 'ml_card_offline');
  });
}
