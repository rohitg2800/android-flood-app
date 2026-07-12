// File: lib/providers/flood_data_provider.dart
// Updated: June 2026
// Changes: New — FloodDataProvider with 2-phase GloFAS load
//          + auto-refresh every 5 min + silent severity patch

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/flood_station.dart';
import '../services/flood_api.dart';

class FloodDataProvider extends ChangeNotifier {
  Map<String, FloodStation> _stations = {};
  bool _isLoading = false;
  String? _error;
  DateTime? _lastUpdated;
  Timer? _refreshTimer;

  FloodDataProvider() {
    _load();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastUpdated => _lastUpdated;

  int get totalLiveCount => _stations.length;

  List<FloodStation> get allStations =>
      _stations.values.toList(growable: false);

  List<FloodStation> get biharStations =>
      allStations.where((s) => s.state == 'Bihar').toList(growable: false);

  int get biharLiveCount => biharStations.length;

  List<FloodStation> get criticalStations => allStations
      .where((s) => s.riskLevel == 'CRITICAL')
      .toList(growable: false);

  List<FloodStation> stationsByState(String state) =>
      allStations.where((s) => s.state == state).toList(growable: false);

  FloodStation? stationByCity(String city) => _stations[city.toLowerCase()];

  Future<void> _load() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Phase 1: fast fetch (no severity)
      final phase1 = await FloodApi.instance.fetchLiveLevels();

      if (phase1.isEmpty) {
        _isLoading = false;
        _error = 'No data received';
        notifyListeners();
        return;
      }

      _stations = {for (final s in phase1) s.city.toLowerCase(): s};
      _lastUpdated = DateTime.now();
      _isLoading = false;
      notifyListeners();

      // Phase 2: silent severity patch
      final phase2 = await FloodApi.instance.fetchLiveLevelsSeverity();
      if (phase2.isEmpty) return;

      bool anyUpdated = false;
      for (final s in phase2) {
        final key = s.city.toLowerCase();
        final existing = _stations[key];
        if (existing == null) continue;

        _stations[key] = existing.copyWithSeverity(
          predictedSeverity: s.predictedSeverity,
          riskScore: s.riskScore,
          confidencePercent: s.confidencePercent,
          willBreachDanger: s.willBreachDanger,
          peakLevel72h: s.peakLevel72h,
          algorithm: s.algorithm,
          modelVersion: s.modelVersion,
        );
        anyUpdated = true;
      }

      if (anyUpdated) notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  void refresh() => _load();
}
