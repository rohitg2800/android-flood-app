import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:equinox_flood/models/flood_prediction.dart';
import 'package:equinox_flood/models/prediction_point.dart';
import 'package:equinox_flood/models/river_station.dart';
import 'package:equinox_flood/providers/bihar_prediction_provider.dart';
import 'package:equinox_flood/providers/prediction_provider.dart';
import 'package:equinox_flood/providers/real_time_river_provider.dart';
import 'package:equinox_flood/providers/weather_provider.dart';
import 'package:equinox_flood/screens/predict_screen.dart';

final _t = DateTime(2026, 6, 17);
const _stationId = 'PATNA_GANGA';

final _station = RiverStation(
  city: 'Patna',
  state: 'Bihar',
  river: 'Ganga',
  station: _stationId,
  current: 72.4,
  warning: 74.0,
  danger: 76.0,
  hfl: 78.5,
  isLive: true,
  dataSource: 'TEST',
);

final _prediction = FloodPrediction(
  station: 'PATNA_GANGA (Ganga)',
  severity: 'SEVERE',
  riskScore: 61.0,
  currentLevel: 72.4,
  warningLevel: 74.0,
  dangerLevel: 76.0,
  predicted24h: 73.1,
  predicted48h: 73.8,
  predicted72h: 74.2,
  trend: 'Rising',
  confidencePct: 75.0,
  modelVersion: 'rule-v1',
  outlook: 'Worsening',
  fromBackend: false,
  next24h: [PredictionPoint(time: _t, level: 73.1)],
  next48h: [PredictionPoint(time: _t, level: 73.8)],
  next72h: [PredictionPoint(time: _t, level: 74.2)],
  updatedAt: _t,
);

void main() {
  testWidgets('PredictScreen renders without overflow', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mergedStationsProvider.overrideWith((ref) => [_station]),
          biharBulkPredictionsProvider.overrideWith((ref) => [_prediction]),
          predictionProvider((_stationId, 24)).overrideWith((ref) async => _prediction),
          weatherProvider.overrideWith(() => _StubWeatherNotifier()),
        ],
        child: const MaterialApp(home: PredictScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(find.byType(SafeArea), findsWidgets);
  });
}

class _StubWeatherNotifier extends WeatherNotifier {
  @override
  WeatherState build() => const WeatherState();
}
