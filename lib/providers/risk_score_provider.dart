import 'package:flutter/foundation.dart';
import '../services/offline_cache_service.dart';
import '../services/ops_client.dart';

/// Resolves issue #19: AI-Based Flood Risk Indicator
/// Task #4: wired to real OpsClient → GET /api/v1/risk-score?station_id={id}
class RiskScore {
  final String stationId;
  final double score; // 0-100
  final RiskZone zone;
  final List<String> contributingFactors;
  final double confidencePercent;
  final DateTime updatedAt;

  const RiskScore({
    required this.stationId,
    required this.score,
    required this.zone,
    required this.contributingFactors,
    required this.confidencePercent,
    required this.updatedAt,
  });

  factory RiskScore.fromMap(Map<String, dynamic> map) => RiskScore(
        stationId: map['station_id'] ?? '',
        score: (map['score'] ?? 0.0).toDouble(),
        zone: RiskZone.fromScore((map['score'] ?? 0.0).toDouble()),
        contributingFactors:
            List<String>.from(map['contributing_factors'] ?? []),
        confidencePercent:
            (map['confidence_percent'] ?? 0.0).toDouble(),
        updatedAt: map['updated_at'] != null
            ? DateTime.parse(map['updated_at'])
            : DateTime.now(),
      );
}

enum RiskZone {
  low,
  moderate,
  high,
  veryHigh,
  critical;

  static RiskZone fromScore(double score) {
    if (score <= 20) return RiskZone.low;
    if (score <= 40) return RiskZone.moderate;
    if (score <= 60) return RiskZone.high;
    if (score <= 80) return RiskZone.veryHigh;
    return RiskZone.critical;
  }

  String get label {
    switch (this) {
      case RiskZone.low:      return 'Low';
      case RiskZone.moderate: return 'Moderate';
      case RiskZone.high:     return 'High';
      case RiskZone.veryHigh: return 'Very High';
      case RiskZone.critical: return 'Critical';
    }
  }
}

class RiskScoreProvider extends ChangeNotifier {
  final Map<String, RiskScore> _scores = {};
  bool _isLoading = false;
  String? _error;

  Map<String, RiskScore> get scores => Map.unmodifiable(_scores);
  bool get isLoading => _isLoading;
  String? get error => _error;

  RiskScore? getScore(String stationId) => _scores[stationId];

  Future<void> fetchRiskScore(String stationId, [String? _ignoredBaseUrl]) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final cache = OfflineCacheService();

      // 1. Serve cache immediately for instant UI (stale-while-revalidate)
      final cached = await cache.getCachedData('risk_$stationId');
      if (cached != null) {
        _scores[stationId] = RiskScore.fromMap(cached);
        notifyListeners();
      }

      // 2. Skip network if offline
      if (!cache.isOnline) {
        debugPrint('RiskScoreProvider: offline — serving cached data for $stationId');
        return;
      }

      // 3. Real API call via OpsClient → /api/v1/risk-score?station_id={id}
      final data = await OpsClient.instance.get(
        '/api/v1/risk-score',
        queryParams: {'station_id': stationId},
      );

      // Backend returns { station_id, score, contributing_factors,
      //                    confidence_percent, updated_at }
      _scores[stationId] = RiskScore.fromMap(data);
      await cache.cacheData('risk_$stationId', data);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('RiskScoreProvider error: $e');

      // Keep last cached score visible — do not blank the UI on network error
      if (!_scores.containsKey(stationId)) {
        _scores[stationId] = RiskScore(
          stationId: stationId,
          score: 0,
          zone: RiskZone.low,
          contributingFactors: ['Data unavailable — check connection'],
          confidencePercent: 0,
          updatedAt: DateTime.now(),
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchAllDistrictScores() async {
    // GET /api/v1/risk-score?scope=district
    // Returns list of { district, score, zone } objects aggregated by backend
    try {
      final data = await OpsClient.instance.get(
        '/api/v1/risk-score',
        queryParams: {'scope': 'district'},
      );
      final list = (data['data'] as List<dynamic>? ?? []);
      for (final item in list.cast<Map<String, dynamic>>()) {
        final score = RiskScore.fromMap(item);
        _scores[score.stationId] = score;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('RiskScoreProvider.fetchAllDistrictScores error: $e');
    }
  }
}
