// test/notification_watcher_test.dart  (Step 7 v2)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:equinox_flood/providers/bihar_prediction_provider.dart';
import 'package:equinox_flood/providers/notification_watcher_provider.dart';
import 'package:equinox_flood/services/flood_notification_service.dart';
import 'package:equinox_flood/models/flood_prediction.dart';
import 'package:equinox_flood/models/prediction_point.dart';

class _FakeSvc extends FloodNotificationService {
  _FakeSvc() : super.internal();
  final List<String> criticalFired = [];
  final List<String> warningFired  = [];

  @override
  Future<void> showCriticalAlert({
    required int id, required String city,
    required double level, required double dangerLevel,
  }) async => criticalFired.add(city);

  @override
  Future<void> showWarningAlert({
    required int id, required String city,
    required double level,
  }) async => warningFired.add(city);

  @override
  Future<void> init() async {}
}

final _t = DateTime(2026, 6, 17);
FloodPrediction _stubPred(String station, String severity) =>
    FloodPrediction(
      station:       station,
      severity:      severity,
      riskScore:     severity == 'CRITICAL' ? 92.0 : 61.0,
      currentLevel:  80.0,
      warningLevel:  74.0,
      dangerLevel:   76.0,
      predicted24h:  80.5,
      predicted48h:  81.0,
      predicted72h:  81.5,
      trend:         'Rising',
      confidencePct: 78.0,
      modelVersion:  'rule-v1',
      outlook:       'Deteriorating',
      fromBackend:   false,
      next24h:       [PredictionPoint(time: _t, level: 80.5)],
      next48h:       [PredictionPoint(time: _t, level: 81.0)],
      next72h:       [PredictionPoint(time: _t, level: 81.5)],
      updatedAt:     _t,
    );

void main() {
  late _FakeSvc fakeSvc;

  setUp(() {
    fakeSvc = _FakeSvc();
    FloodNotificationService.testOverride(fakeSvc);
  });
  tearDown(FloodNotificationService.clearOverride);

  test('fires CRITICAL exactly once per station', () {
    final container = ProviderContainer(
      overrides: [
        biharBulkPredictionsProvider.overrideWith(
          (_) => [_stubPred('Patna (Ganga)', 'CRITICAL')],
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(notificationWatcherProvider);
    container.read(notificationWatcherProvider); // second read must not re-fire

    expect(fakeSvc.criticalFired, hasLength(1));
    expect(fakeSvc.criticalFired.first, 'Patna');
  });

  test('fires WARNING for SEVERE only', () {
    final container = ProviderContainer(
      overrides: [
        biharBulkPredictionsProvider.overrideWith(
          (_) => [
            _stubPred('Hajipur (Gandak)', 'SEVERE'),
            _stubPred('Muzaffarpur (Burhi)', 'CRITICAL'),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(notificationWatcherProvider);

    expect(fakeSvc.warningFired,  contains('Hajipur'));
    expect(fakeSvc.criticalFired, contains('Muzaffarpur'));
    expect(fakeSvc.warningFired,  isNot(contains('Muzaffarpur')));
  });
}
