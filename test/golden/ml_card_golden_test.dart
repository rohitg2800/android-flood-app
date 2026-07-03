// test/golden/ml_card_golden_test.dart  v2
// Fixed: all required FloodPrediction constructor params supplied.
// Removed: stationName/predictedLevel/confidence/isOffline (those are
//          the old aliases — use station/predicted24h/confidencePct/fromBackend)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:equinox_flood/models/flood_prediction.dart';
import 'package:equinox_flood/models/prediction_point.dart';
import 'package:equinox_flood/widgets/ml_card_test_export.dart';

void main() {
  // ─ Helper: build a fully-populated FloodPrediction ────────────────────────
  FloodPrediction _mkPrediction({String severity = 'MODERATE'}) =>
      FloodPrediction(
        severity: severity,
        riskScore: 72.5,
        station: 'Birpur (Kosi)',
        currentLevel: 47.2,
        warningLevel: 49.0,
        dangerLevel: 52.0,
        predicted24h: 48.3,
        predicted48h: 50.1,
        predicted72h: 51.4,
        trend: 'Rising',
        confidencePct: 85.0,
        modelVersion: 'v2.1.0',
        outlook: 'River levels expected to continue rising over 72h.',
        fromBackend: true,
        next24h: [
          PredictionPoint(time: DateTime(2026, 6, 16, 6), level: 47.5),
          PredictionPoint(time: DateTime(2026, 6, 16, 12), level: 47.9),
          PredictionPoint(time: DateTime(2026, 6, 16, 18), level: 48.1),
          PredictionPoint(time: DateTime(2026, 6, 17, 0), level: 48.3),
        ],
        next48h: [
          PredictionPoint(time: DateTime(2026, 6, 17, 6), level: 48.7),
          PredictionPoint(time: DateTime(2026, 6, 17, 12), level: 49.2),
          PredictionPoint(time: DateTime(2026, 6, 17, 18), level: 49.8),
          PredictionPoint(time: DateTime(2026, 6, 18, 0), level: 50.1),
        ],
        next72h: [
          PredictionPoint(time: DateTime(2026, 6, 18, 6), level: 50.5),
          PredictionPoint(time: DateTime(2026, 6, 18, 12), level: 51.0),
          PredictionPoint(time: DateTime(2026, 6, 18, 18), level: 51.2),
          PredictionPoint(time: DateTime(2026, 6, 19, 0), level: 51.4),
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
            child: MlCardTestExport(pred: _mkPrediction(severity: 'CRITICAL')),
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
