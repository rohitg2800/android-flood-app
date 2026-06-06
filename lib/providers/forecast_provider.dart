import 'package:flutter/foundation.dart';
import '../services/offline_cache_service.dart';
import '../services/ops_client.dart';

/// Resolves issue #20: Advanced Flood Forecasting (72-Hour Prediction)
/// Task #4: wired to real OpsClient → GET /api/v1/forecast/{station_id}
class ForecastPoint {
  final DateTime timestamp;
  final double predictedLevel;
  final double confidenceLow;
  final double confidenceHigh;

  const ForecastPoint({
    required this.timestamp,
    required this.predictedLevel,
    required this.confidenceLow,
    required this.confidenceHigh,
  });

  factory ForecastPoint.fromMap(Map<String, dynamic> map) => ForecastPoint(
        timestamp: DateTime.parse(map['timestamp']),
        predictedLevel: (map['predicted_level'] ?? 0.0).toDouble(),
        confidenceLow: (map['confidence_low'] ?? 0.0).toDouble(),
        confidenceHigh: (map['confidence_high'] ?? 0.0).toDouble(),
      );
}

class StationForecast {
  final String stationId;
  final List<ForecastPoint> points; // 12 points @ 6h intervals = 72h
  final String summaryText;
  final double modelAccuracy;
  final double mae;
  final double rmse;
  final DateTime generatedAt;

  const StationForecast({
    required this.stationId,
    required this.points,
    required this.summaryText,
    required this.modelAccuracy,
    required this.mae,
    required this.rmse,
    required this.generatedAt,
  });

  factory StationForecast.fromMap(Map<String, dynamic> map) => StationForecast(
        stationId: map['station_id'] ?? '',
        points: (map['points'] as List<dynamic>? ?? [])
            .map((p) => ForecastPoint.fromMap(p as Map<String, dynamic>))
            .toList(),
        summaryText: map['summary_text'] ?? '',
        modelAccuracy: (map['model_accuracy'] ?? 0.0).toDouble(),
        mae: (map['mae'] ?? 0.0).toDouble(),
        rmse: (map['rmse'] ?? 0.0).toDouble(),
        generatedAt: map['generated_at'] != null
            ? DateTime.parse(map['generated_at'])
            : DateTime.now(),
      );

  /// True if the 72h peak exceeds the dangerLevel passed in
  bool willExceedDanger(double dangerLevel) =>
      points.any((p) => p.predictedLevel >= dangerLevel);

  /// Hour offset when level is first predicted to cross threshold (or null)
  int? hoursUntilThreshold(double threshold) {
    for (final p in points) {
      if (p.predictedLevel >= threshold) {
        final diff = p.timestamp.difference(generatedAt);
        return diff.inHours;
      }
    }
    return null;
  }
}

class ForecastProvider extends ChangeNotifier {
  final Map<String, StationForecast> _forecasts = {};
  bool _isLoading = false;
  String? _error;

  Map<String, StationForecast> get forecasts =>
      Map.unmodifiable(_forecasts);
  bool get isLoading => _isLoading;
  String? get error => _error;

  StationForecast? getForecast(String stationId) =>
      _forecasts[stationId];

  Future<void> fetchForecast(String stationId, [String? _ignoredBaseUrl]) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final cache = OfflineCacheService();

      // 1. Stale-while-revalidate: serve cache first
      final cached = await cache.getCachedData('forecast_$stationId');
      if (cached != null) {
        _forecasts[stationId] = StationForecast.fromMap(cached);
        notifyListeners();
      }

      // 2. Skip network if offline
      if (!cache.isOnline) {
        debugPrint('ForecastProvider: offline — serving cached forecast for $stationId');
        return;
      }

      // 3. Real API call via OpsClient → /api/v1/forecast/{station_id}
      // Backend returns:
      // {
      //   station_id: string,
      //   points: [{ timestamp, predicted_level, confidence_low, confidence_high }],
      //   summary_text: string,
      //   model_accuracy: float,   // 0–100
      //   mae: float,
      //   rmse: float,
      //   generated_at: ISO8601
      // }
      final data = await OpsClient.instance.get(
        '/api/v1/forecast/$stationId',
      );

      _forecasts[stationId] = StationForecast.fromMap(data);
      await cache.cacheData('forecast_$stationId', data);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('ForecastProvider error: $e');

      // Keep last forecast visible — do not blank the UI on error
      if (!_forecasts.containsKey(stationId)) {
        _forecasts[stationId] = StationForecast(
          stationId: stationId,
          points: const [],
          summaryText: 'Forecast unavailable — check connection',
          modelAccuracy: 0,
          mae: 0,
          rmse: 0,
          generatedAt: DateTime.now(),
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Bulk-fetch for all stations in a district
  /// GET /api/v1/forecast?district={district}
  Future<void> fetchDistrictForecasts(String district) async {
    if (!OfflineCacheService().isOnline) return;
    try {
      final data = await OpsClient.instance.get(
        '/api/v1/forecast',
        queryParams: {'district': district},
      );
      final list = (data['data'] as List<dynamic>? ?? []);
      for (final item in list.cast<Map<String, dynamic>>()) {
        final forecast = StationForecast.fromMap(item);
        _forecasts[forecast.stationId] = forecast;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('ForecastProvider.fetchDistrictForecasts error: $e');
    }
  }
}
