// test/golden/ml_card_golden_test.dart  v2
// Fixed: all required FloodPrediction constructor params supplied.
// Removed: stationName/predictedLevel/confidence/isOffline (those are
//          the old aliases — use station/predicted24h/confidencePct/fromBackend)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/flood_prediction.dart';
import '../../lib/models/prediction_point.dart';
import '../../lib/widgets/ml_card_test_export.dart';

void main() {
  // ─ Helper: build a fully-populated FloodPrediction ────────────────────────
  FloodPrediction _mkPrediction({String severity = 'MODERATE'}) =>
      FloodPrediction(
        severity:      severity,
        riskScore:     72.5,
        station:       'Birpur (Kosi)',
        currentLevel:  47.2,
        warningLevel:  49.0,
        dangerLevel:   52.0,
        predicted24h:  48.3,
        predicted48h:  50.1,
        predicted72h:  51.4,
        trend:         'Rising',
        confidencePct: 85.0,
        modelVersion:  'v2.1.0',
        outlook:       'River levels expected to continue rising over 72h.',
        fromBackend:   true,
        next24h: const [
          PredictionPoint(hour: 6,  level: 47.5),
          PredictionPoint(hour: 12, level: 47.9),
          PredictionPoint(hour: 18, level: 48.1),
          PredictionPoint(hour: 24, level: 48.3),
        ],
        next48h: const [
          PredictionPoint(hour: 30, level: 48.7),
          PredictionPoint(hour: 36, level: 49.2),
          PredictionPoint(hour: 42, level: 49.8),
          PredictionPoint(hour: 48, level: 50.1),
        ],
        next72h: const [
          PredictionPoint(hour: 54, level: 50.5),
          PredictionPoint(hour: 60, level: 51.0),
          PredictionPoint(hour: 66, level: 51.2),
          PredictionPoint(hour: 72, level: 51.4),
        ],
        updatedAt: DateTime(2026, 6, 16, 8, 30),
      );

  // ─ Golden test 1: MODERATE severity ────────────────────────────────
  testWidgets('ml_card_golden_moderate', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: MlCardTestExport(pred: _mkPrediction()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MlCardTestExport),
      matchesGoldenFile('goldens/ml_card_moderate.png'),
    );
  });

  // ─ Golden test 2: CRITICAL severity ───────────────────────────────
  testWidgets('ml_card_golden_critical', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: MlCardTestExport(
                pred: _mkPrediction(severity: 'CRITICAL')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MlCardTestExport),
      matchesGoldenFile('goldens/ml_card_critical.png'),
    );
  });
}
