// File: lib/models/flood_station.dart
// Updated: June 2026
// Changes: New — FloodStation model matching /api/live-levels response shape

class FloodStation {
  final String city;
  final String state;
  final String riverName;
  final double? currentLevel;
  final double? safeLevel;
  final double? warningLevel;
  final double? dangerLevel;
  final double? capacityPercent;
  final String riskLevel;
  final String status;
  final String? alert;
  final double? flowRate;
  final double? lat;
  final double? lon;
  final String dataSource;
  final String? timestamp;
  final double? aboveBelowDangerM;
  final double? change24hM;
  final String? trend;
  final String? wrdStatus;
  final String? predictedSeverity;
  final double? riskScore;
  final double? confidencePercent;
  final bool? willBreachDanger;
  final double? peakLevel72h;
  final String? algorithm;
  final String? modelVersion;

  const FloodStation({
    required this.city,
    required this.state,
    required this.riverName,
    required this.riskLevel,
    required this.status,
    required this.dataSource,
    this.currentLevel,
    this.safeLevel,
    this.warningLevel,
    this.dangerLevel,
    this.capacityPercent,
    this.alert,
    this.flowRate,
    this.lat,
    this.lon,
    this.timestamp,
    this.aboveBelowDangerM,
    this.change24hM,
    this.trend,
    this.wrdStatus,
    this.predictedSeverity,
    this.riskScore,
    this.confidencePercent,
    this.willBreachDanger,
    this.peakLevel72h,
    this.algorithm,
    this.modelVersion,
  });

  factory FloodStation.fromJson(Map<String, dynamic> j) {
    double? _d(String k) {
      final v = j[k];
      if (v == null) return null;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    return FloodStation(
      city: (j['city'] as String?) ?? '',
      state: (j['state'] as String?) ?? '',
      riverName: (j['river_name'] as String?) ?? '',
      riskLevel: (j['risk_level'] as String?) ?? 'UNKNOWN',
      status: (j['status'] as String?) ?? '',
      dataSource: (j['data_source'] as String?) ?? '',
      currentLevel: _d('current_level'),
      safeLevel: _d('safe_level'),
      warningLevel: _d('warning_level'),
      dangerLevel: _d('danger_level'),
      capacityPercent: _d('capacity_percent'),
      alert: j['alert'] as String?,
      flowRate: _d('flow_rate'),
      lat: _d('lat'),
      lon: _d('lon'),
      timestamp: j['timestamp'] as String?,
      aboveBelowDangerM: _d('above_below_danger_m'),
      change24hM: _d('change_24h_m'),
      trend: j['trend'] as String?,
      wrdStatus: j['wrd_status'] as String?,
      predictedSeverity: j['predicted_severity'] as String?,
      riskScore: _d('risk_score'),
      confidencePercent: _d('confidence_percent'),
      willBreachDanger: j['will_breach_danger'] as bool?,
      peakLevel72h: _d('peak_level_72h'),
      algorithm: j['algorithm'] as String?,
      modelVersion: j['model_version'] as String?,
    );
  }

  FloodStation copyWithSeverity({
    String? predictedSeverity,
    double? riskScore,
    double? confidencePercent,
    bool? willBreachDanger,
    double? peakLevel72h,
    String? algorithm,
    String? modelVersion,
  }) {
    return FloodStation(
      city: city,
      state: state,
      riverName: riverName,
      riskLevel: riskLevel,
      status: status,
      dataSource: dataSource,
      currentLevel: currentLevel,
      safeLevel: safeLevel,
      warningLevel: warningLevel,
      dangerLevel: dangerLevel,
      capacityPercent: capacityPercent,
      alert: alert,
      flowRate: flowRate,
      lat: lat,
      lon: lon,
      timestamp: timestamp,
      aboveBelowDangerM: aboveBelowDangerM,
      change24hM: change24hM,
      trend: trend,
      wrdStatus: wrdStatus,
      predictedSeverity: predictedSeverity ?? this.predictedSeverity,
      riskScore: riskScore ?? this.riskScore,
      confidencePercent: confidencePercent ?? this.confidencePercent,
      willBreachDanger: willBreachDanger ?? this.willBreachDanger,
      peakLevel72h: peakLevel72h ?? this.peakLevel72h,
      algorithm: algorithm ?? this.algorithm,
      modelVersion: modelVersion ?? this.modelVersion,
    );
  }
}
