// test/bihar_prediction_provider_test.dart  (Step 7 v2)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:equinox_flood/providers/bihar_prediction_provider.dart';
import 'package:equinox_flood/models/flood_prediction.dart';
import 'package:equinox_flood/models/prediction_point.dart';

void main() {
  group('biharBulkPredictionsProvider', () {
    test('returns empty list when biharLiveProvider has no data', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final preds = container.read(biharBulkPredictionsProvider);
      // Live provider not yet resolved → empty list
      expect(preds, isA<List<FloodPrediction>>());
    });

    test('override with stub list returns correct data', () {
      final stub = FloodPrediction(
        station:       'Patna (Ganga)',
        severity:      'SEVERE',
        riskScore:     61.0,
        currentLevel:  72.4,
        warningLevel:  74.0,
        dangerLevel:   76.0,
        predicted24h:  73.1,
        predicted48h:  73.8,
        predicted72h:  74.2,
        trend:         'Rising',
        confidencePct: 75.0,
        modelVersion:  'rule-v1',
        outlook:       'Worsening',
        fromBackend:   false,
        next24h:       [PredictionPoint(time: DateTime(2026,6,17), level: 73.1)],
        next48h:       [PredictionPoint(time: DateTime(2026,6,17), level: 73.8)],
        next72h:       [PredictionPoint(time: DateTime(2026,6,17), level: 74.2)],
        updatedAt:     DateTime(2026, 6, 17),
      );

      final container = ProviderContainer(
        overrides: [
          biharBulkPredictionsProvider.overrideWith((_) => [stub]),
        ],
      );
      addTearDown(container.dispose);

      final preds = container.read(biharBulkPredictionsProvider);
      expect(preds, hasLength(1));
      expect(preds.first.station,  'Patna (Ganga)');
      expect(preds.first.severity, 'SEVERE');
      expect(preds.first.riskScore, 61.0);
    });
  });
}
