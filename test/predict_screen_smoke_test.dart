// test/predict_screen_smoke_test.dart  (Step 7 v4)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:equinox_flood/providers/bihar_prediction_provider.dart';
import 'package:equinox_flood/providers/bihar_live_provider.dart';
import 'package:equinox_flood/providers/weather_provider.dart';
import 'package:equinox_flood/models/flood_prediction.dart';
import 'package:equinox_flood/models/prediction_point.dart';
import 'package:equinox_flood/screens/predict_screen_impl.dart';

final _t = DateTime(2026, 6, 17);

final _stub = FloodPrediction(
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
  next24h:       [PredictionPoint(time: _t, level: 73.1)],
  next48h:       [PredictionPoint(time: _t, level: 73.8)],
  next72h:       [PredictionPoint(time: _t, level: 74.2)],
  updatedAt:     _t,
);

void main() {
  testWidgets('PredictScreen renders without overflow', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Freeze live provider — no network calls
          biharLiveProvider.overrideWith(_StubBiharLiveNotifier.new),
          // Freeze weather — no network calls
          weatherProvider.overrideWith(
            () => _StubWeatherNotifier(),
          ),
          // Inject stub predictions directly
          biharBulkPredictionsProvider.overrideWith((_) => [_stub]),
        ],
        child: const MaterialApp(home: PredictScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}

class _StubBiharLiveNotifier extends BiharLiveNotifier {
  @override
  Future<BiharLiveState> build() async => BiharLiveState();
}

class _StubWeatherNotifier extends WeatherNotifier {
  @override
  WeatherState build() => const WeatherState();
}
