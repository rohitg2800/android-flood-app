import '../ml/flood_engine.dart';

class PredictionRecord {
  final DateTime timestamp;
  final String state;
  final String? station;
  final double peakFloodLevelM;
  final double rainfall7d;
  final FloodResult result;

  const PredictionRecord({
    required this.timestamp,
    required this.state,
    this.station,
    required this.peakFloodLevelM,
    required this.rainfall7d,
    required this.result,
  });
}

class PredictionHistoryService {
  static final PredictionHistoryService _instance =
      PredictionHistoryService._internal();
  factory PredictionHistoryService() => _instance;
  PredictionHistoryService._internal();

  final List<PredictionRecord> _records = [];

  List<PredictionRecord> get records =>
      List.unmodifiable(_records.reversed.toList());

  void addRecord(PredictionRecord record) {
    _records.add(record);
    if (_records.length > 100) _records.removeAt(0);
  }

  // --- Summary stats consumed by Dashboard KPI cards ---
  int get totalPredictions => _records.length;

  int get dangerAlerts => _records
      .where((r) =>
          r.result.severity == 'CRITICAL' || r.result.severity == 'SEVERE')
      .length;

  double get avgConfidence {
    if (_records.isEmpty) return 0;
    return _records
            .map((r) => r.result.confidencePercent)
            .fold(0.0, (a, b) => a + b) /
        _records.length;
  }

  int get avgRiskScore {
    if (_records.isEmpty) return 0;
    return (_records.map((r) => r.result.riskScore).fold(0, (a, b) => a + b) /
            _records.length)
        .round();
  }

  Map<String, int> get severityBreakdown {
    final map = {'LOW': 0, 'MODERATE': 0, 'SEVERE': 0, 'CRITICAL': 0};
    for (final r in _records) {
      map[r.result.severity] = (map[r.result.severity] ?? 0) + 1;
    }
    return map;
  }

  List<PredictionRecord> recentN(int n) => records.take(n).toList();

  void clear() => _records.clear();
}
