import 'dart:async';
import 'package:flutter/foundation.dart';
import '../utils/flood_severity.dart';
import '../services/offline_cache_service.dart';

/// Resolves issue #35: Live Station Status Monitoring
enum StationTrend { rising, falling, stable }

class StationStatus {
  final String stationId;
  final String stationName;
  final String riverName;
  final String district;
  final double currentLevel;
  final double dangerLevel;
  final double warningLevel;
  final FloodSeverityLevel severity;
  final StationTrend trend;
  final bool isOnline;
  final DateTime lastUpdated;

  const StationStatus({
    required this.stationId,
    required this.stationName,
    required this.riverName,
    required this.district,
    required this.currentLevel,
    required this.dangerLevel,
    required this.warningLevel,
    required this.severity,
    required this.trend,
    required this.isOnline,
    required this.lastUpdated,
  });

  factory StationStatus.fromMap(Map<String, dynamic> map) => StationStatus(
        stationId: map['station_id'] ?? '',
        stationName: map['station_name'] ?? '',
        riverName: map['river_name'] ?? '',
        district: map['district'] ?? '',
        currentLevel: (map['current_level'] ?? 0.0).toDouble(),
        dangerLevel: (map['danger_level'] ?? 0.0).toDouble(),
        warningLevel: (map['warning_level'] ?? 0.0).toDouble(),
        severity:
            FloodSeverityLevelExtension.fromString(map['severity'] ?? 'normal'),
        trend: StationTrend.values.firstWhere(
          (t) => t.name == (map['trend'] ?? 'stable'),
          orElse: () => StationTrend.stable,
        ),
        isOnline: map['is_online'] ?? true,
        lastUpdated: map['last_updated'] != null
            ? DateTime.parse(map['last_updated'])
            : DateTime.now(),
      );

  String get trendLabel {
    switch (trend) {
      case StationTrend.rising:
        return '⬆️ Rising';
      case StationTrend.falling:
        return '⬇️ Falling';
      case StationTrend.stable:
        return '➡️ Stable';
    }
  }
}

class StationStatusProvider extends ChangeNotifier {
  final List<StationStatus> _stations = [];
  bool _isLoading = false;
  String? _error;
  Timer? _pollingTimer;
  static const Duration _pollingInterval = Duration(minutes: 5);

  List<StationStatus> get stations => List.unmodifiable(_stations);
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get dangerCount => _stations
      .where((s) =>
          s.severity == FloodSeverityLevel.danger ||
          s.severity == FloodSeverityLevel.extreme)
      .length;

  int get watchCount => _stations
      .where((s) =>
          s.severity == FloodSeverityLevel.watch ||
          s.severity == FloodSeverityLevel.warning)
      .length;

  int get normalCount =>
      _stations.where((s) => s.severity == FloodSeverityLevel.normal).length;

  int get offlineCount => _stations.where((s) => !s.isOnline).length;

  List<StationStatus> getByDistrict(String district) =>
      _stations.where((s) => s.district == district).toList();

  List<StationStatus> filterBySeverity(FloodSeverityLevel level) =>
      _stations.where((s) => s.severity == level).toList();

  List<StationStatus> get offlineStations =>
      _stations.where((s) => !s.isOnline).toList();

  Future<void> fetchStatuses(String baseUrl) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Check offline cache
      final cache = OfflineCacheService();
      if (!cache.isOnline) {
        final cached = await cache.getCachedList('station_statuses');
        if (cached != null) {
          _stations
            ..clear()
            ..addAll(cached.map(StationStatus.fromMap));
          notifyListeners();
          return;
        }
      }

      // TODO: Replace with real API call:
      // GET $baseUrl/api/v1/stations/status
      // Response includes trend, is_online fields from backend

      debugPrint('StationStatusProvider: fetching live statuses...');
    } catch (e) {
      _error = e.toString();
      debugPrint('StationStatusProvider error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void startPolling(String baseUrl) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollingInterval, (_) {
      fetchStatuses(baseUrl);
    });
    debugPrint('Station status polling started (every 5 min)');
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
