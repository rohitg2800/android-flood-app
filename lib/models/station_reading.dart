// lib/models/station_reading.dart
// StationReading — intermediate model used by AlertEngine and OfflineRuleEngine.
// Carries all gauge + forecast fields. Created from RiverStation via
// AlertEngine._riverStationToReading(), or from raw CWC/WRD fetch results.

class StationReading {
  final String stationName;
  final String river;
  final String district;
  final String state;
  final double lat;
  final double lon;
  final double currentLevel;
  final double warningLevel;
  final double dangerLevel;
  final double hfl;
  final double progressPct; // 0–100+
  final String riskLabel; // 'NORMAL' | 'WARNING' | 'DANGER' | 'EXTREME'
  final String source; // 'CWC' | 'WRD' | 'MERGED' | ...
  final bool isLive;
  final DateTime fetchedAt;

  // Optional live-data fields
  final double? rateOfRiseMph; // m/h (positive = rising)
  final double? rainfall24hMm;
  final double? forecastLevel24h; // m (GloFAS / Open-Meteo)
  final double? forecastLevel48h;

  // Legacy aliases used by OfflineRuleEngine
  String? get stationId => stationName;
  double? get rateOfRise => rateOfRiseMph;
  double? get rainfall24h => rainfall24hMm;
  double? get rateOfRiseMphNullable => rateOfRiseMph;

  const StationReading({
    required this.stationName,
    required this.river,
    required this.district,
    required this.state,
    required this.lat,
    required this.lon,
    required this.currentLevel,
    required this.warningLevel,
    required this.dangerLevel,
    required this.hfl,
    required this.progressPct,
    required this.riskLabel,
    required this.source,
    required this.isLive,
    required this.fetchedAt,
    this.rateOfRiseMph,
    this.rainfall24hMm,
    this.forecastLevel24h,
    this.forecastLevel48h,
  });

  bool get isAboveHfl => hfl > 0 && currentLevel >= hfl;
  bool get isAboveDanger => dangerLevel > 0 && currentLevel >= dangerLevel;
  bool get isAboveWarning => warningLevel > 0 && currentLevel >= warningLevel;
}
