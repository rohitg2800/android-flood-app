// lib/providers/flood_provider.dart
// OpsFlood — FloodProvider (Riverpod ChangeNotifier)
//
// Thin facade over bihar_live_provider / flood_providers so screens that
// import this path and call ref.watch(floodProvider) compile.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flood_data.dart';
import 'flood_providers.dart';

// ─── Riverpod provider ────────────────────────────────────────────────────────

final floodProvider = ChangeNotifierProvider<FloodProvider>((ref) {
  final notifier = FloodProvider();

  // Mirror liveLevelsProvider changes into this notifier.
  ref.listen<List<FloodData>>(
    liveLevelsProvider,
    (_, next) => notifier._updateLevels(next),
    fireImmediately: true,
  );

  // Mirror online status.
  ref.listen<bool>(
    isOfflineProvider,
    (_, offline) => notifier._updateOnline(!offline),
    fireImmediately: true,
  );

  // Mirror last-fetch time.
  ref.listen<DateTime?>(
    lastFetchTimeProvider,
    (_, t) => notifier._updateLastFetch(t),
    fireImmediately: true,
  );

  return notifier;
});

// ─── FloodProvider ────────────────────────────────────────────────────────────

class FloodProvider extends ChangeNotifier {
  List<FloodData> _levels    = [];
  bool            _isOnline  = true;
  DateTime?       _lastFetch;

  // ── Getters ──────────────────────────────────────────────────────────────

  List<FloodData> get liveLevels => _levels;

  List<FloodData> get critical =>
      _levels.where((d) => d.riskLevel == 'CRITICAL').toList();

  List<FloodData> get highRisk =>
      _levels
          .where((d) => d.riskLevel == 'HIGH' || d.riskLevel == 'CRITICAL')
          .toList();

  int get criticalCount => critical.length;
  int get highRiskCount => highRisk.length;
  int get stationCount  => _levels.length;

  bool      get isOnline     => _isOnline;
  DateTime? get lastFetchTime => _lastFetch;

  // ── Internal setters (called by ref.listen above) ────────────────────────

  void _updateLevels(List<FloodData> v)  { _levels   = v;  notifyListeners(); }
  void _updateOnline(bool v)             { _isOnline = v;  notifyListeners(); }
  void _updateLastFetch(DateTime? v)     { _lastFetch = v; notifyListeners(); }
}
