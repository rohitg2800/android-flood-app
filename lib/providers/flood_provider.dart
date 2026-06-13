// lib/providers/flood_provider.dart
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flood_data.dart';
import 'flood_providers.dart';

// Riverpod 3.x removed ChangeNotifierProvider.
// Use a plain Provider that creates the ChangeNotifier, wires listeners,
// and disposes it when the provider is destroyed.
final floodProvider = Provider<FloodProvider>((ref) {
  final notifier = FloodProvider();

  ref.listen<List<FloodData>>(
    liveLevelsProvider,
    (_, next) => notifier._updateLevels(next),
    fireImmediately: true,
  );

  ref.listen<bool>(
    isOfflineProvider,
    (_, offline) => notifier._updateOnline(!offline),
    fireImmediately: true,
  );

  ref.listen<DateTime?>(
    lastFetchTimeProvider,
    (_, t) => notifier._updateLastFetch(t),
    fireImmediately: true,
  );

  ref.onDispose(notifier.dispose);

  return notifier;
});

class FloodProvider extends ChangeNotifier {
  List<FloodData> _levels   = [];
  bool            _isOnline = true;
  DateTime?       _lastFetch;

  List<FloodData> get liveLevels   => _levels;
  bool            get isOnline     => _isOnline;
  DateTime?       get lastFetchTime => _lastFetch;

  int get criticalCount => _levels.where((d) => d.riskLevel == 'CRITICAL').length;
  int get highRiskCount => _levels.where((d) => d.riskLevel == 'HIGH' || d.riskLevel == 'CRITICAL').length;
  int get stationCount  => _levels.length;

  List<FloodData> get critical =>
      _levels.where((d) => d.riskLevel == 'CRITICAL').toList();

  List<FloodData> get highRisk =>
      _levels.where((d) => d.riskLevel == 'HIGH' || d.riskLevel == 'CRITICAL').toList();

  /// Top at-risk cities sorted by severity (CRITICAL > DANGER > HIGH > WARNING).
  List<FloodData> get topAtRiskCities {
    const order = {'CRITICAL': 0, 'DANGER': 1, 'HIGH': 2, 'WARNING': 3};
    return [..._levels]
      ..sort((a, b) =>
          (order[a.riskLevel] ?? 99).compareTo(order[b.riskLevel] ?? 99));
  }

  /// All live stations (same as liveLevels, alias for legacy screen compat).
  List<FloodData> get liveStations => _levels;

  /// Trigger a manual refresh — delegates to DataFetchEngine.
  Future<void> refresh() async {
    // DataFetchEngine auto-polls; a no-op here keeps screens working.
  }

  void _updateLevels(List<FloodData> v)  { _levels   = v;  notifyListeners(); }
  void _updateOnline(bool v)             { _isOnline = v;  notifyListeners(); }
  void _updateLastFetch(DateTime? v)     { _lastFetch = v; notifyListeners(); }
}
