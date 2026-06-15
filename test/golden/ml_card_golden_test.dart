// test/golden/ml_card_golden_test.dart  Step 6.3
// Golden tests for _MlCard in 4 severity states:
//   SAFE | MODERATE | SEVERE | CRITICAL
// Run:  flutter test --update-goldens  (first time)
//       flutter test                   (subsequent CI runs)
//
// Goldens are written to test/golden/goldens/

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:flood_app/providers/prediction_provider.dart';
import 'package:flood_app/theme/river_theme.dart';

// We expose _MlCard via a thin test-only barrel
// lib/widgets/ml_card_test_export.dart  (created below in same commit)
import 'package:flood_app/widgets/ml_card_test_export.dart';

void main() {
  setUpAll(loadAppFonts);

  /// Helper: builds a [FloodPrediction] for a given severity.
  FloodPrediction _pred(String severity, {double riskScore = 50}) =>
      FloodPrediction(
        stationId:      'GS001',
        predicted24h:   9.5,
        predicted72h:   10.2,
        dangerLevel:    10.0,
        riskScore:      riskScore,
        severity:       severity,
        trend:          'rising',
        confidencePct:  82.0,
        outlook:        'Water levels expected to rise over the next 24 hours.',
        fromBackend:    true,
        generatedAt:    DateTime(2026, 6, 15, 12, 0),
      );

  Widget _wrap(FloodPrediction pred) => RiverTheme(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: const Color(0xFF0E1621),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: MlCardTestExport(pred: pred),
            ),
          ),
        ),
      );

  // ── Individual severity goldens
  testGoldens('MlCard — SAFE severity', (tester) async {
    await tester.pumpWidgetBuilder(
      _wrap(_pred('SAFE', riskScore: 15)),
      surfaceSize: const Size(420, 280),
    );
    await screenMatchesGolden(tester, 'ml_card_safe');
  });

  testGoldens('MlCard — MODERATE severity', (tester) async {
    await tester.pumpWidgetBuilder(
      _wrap(_pred('MODERATE', riskScore: 45)),
      surfaceSize: const Size(420, 280),
    );
    await screenMatchesGolden(tester, 'ml_card_moderate');
  });

  testGoldens('MlCard — SEVERE severity', (tester) async {
    await tester.pumpWidgetBuilder(
      _wrap(_pred('SEVERE', riskScore: 72)),
      surfaceSize: const Size(420, 280),
    );
    await screenMatchesGolden(tester, 'ml_card_severe');
  });

  testGoldens('MlCard — CRITICAL severity + breach risk', (tester) async {
    // predicted24h (9.5) >= dangerLevel (8.0) → breach banner visible
    final pred = FloodPrediction(
      stationId:     'GS001',
      predicted24h:  9.5,
      predicted72h:  11.0,
      dangerLevel:   8.0,   // lower threshold → triggers breach banner
      riskScore:     91,
      severity:      'CRITICAL',
      trend:         'rising',
      confidencePct: 94.0,
      outlook:       'Immediate action required. Breach imminent.',
      fromBackend:   true,
      generatedAt:   DateTime(2026, 6, 15, 12, 0),
    );
    await tester.pumpWidgetBuilder(
      _wrap(pred),
      surfaceSize: const Size(420, 340),
    );
    await screenMatchesGolden(tester, 'ml_card_critical_breach');
  });

  // ── Linear fallback chip visible
  testGoldens('MlCard — Linear fallback chip shown', (tester) async {
    final pred = _pred('MODERATE', riskScore: 45);
    final offlinePred = FloodPrediction(
      stationId:     pred.stationId,
      predicted24h:  pred.predicted24h,
      predicted72h:  pred.predicted72h,
      dangerLevel:   pred.dangerLevel,
      riskScore:     pred.riskScore,
      severity:      pred.severity,
      trend:         pred.trend,
      confidencePct: pred.confidencePct,
      outlook:       pred.outlook,
      fromBackend:   false,   // ← triggers fallback chip
      generatedAt:   pred.generatedAt,
    );
    await tester.pumpWidgetBuilder(
      _wrap(offlinePred),
      surfaceSize: const Size(420, 300),
    );
    await screenMatchesGolden(tester, 'ml_card_linear_fallback');
  });
}
