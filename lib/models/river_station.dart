// lib/models/river_station.dart
// Extended model — carries both static CWC thresholds AND live API fields.
// v2:   added lat/lon (nullable) and riskLabel getter.
// v2.1: guard hfl==0 and danger==0 in dangerClass.
// v2.2: dangerClass now delegates to gaugeRiskFromLevels() (bihar_rivers.dart)
//       so the map and all other screens share one severity computation.
// v2.3: add `district` alias + `riskLevel` alias used by bihar_district_heatmap.
// v2.4: add `lng` getter alias for `lon` (used by bihar_river_map_screen).

export 'live_river_result_ext.dart';

import '../data/bihar_rivers.dart';

class RiverStation {
  final String city;
  final String state;
  final String river;
  final String station;
  final double current;
  final double warning;
  final double danger;
  final double hfl;

  final double? lat;
  final double? lon;

  final double?  rainfallLastHour;
  final double?  flowRate;
  final String?  trend;
  final String?  liveStatus;
  final String?  lastUpdated;
  final String?  dataSource;
  final bool     isLive;

  const RiverStation({
    required this.city,
    required this.state,
    required this.river,
    required this.station,
    required this.current,
    required this.warning,
    required this.danger,
    required this.hfl,
    this.lat,
    this.lon,
    this.rainfallLastHour,
    this.flowRate,
    this.trend,
    this.liveStatus,
    this.lastUpdated,
    this.dataSource,
    this.isLive = false,
  });

  // ── Computed getters ─────────────────────────────────────────────────
  /// Delegates to gaugeRiskFromLevels() — the single canonical severity fn.
  DangerClass get dangerClass {
    final label = gaugeRiskFromLevels(
      current: current,
      warning: warning,
      danger:  danger,
      hfl:     hfl,
    );
    return switch (label) {
      'EXTREME'  => DangerClass.extreme,
      'CRITICAL' => DangerClass.severe,
      'DANGER'   => DangerClass.aboveNormal,
      _          => DangerClass.normal,
    };
  }

  /// Human-readable risk label.
  String get riskLabel => gaugeRiskFromLevels(
    current: current,
    warning: warning,
    danger:  danger,
    hfl:     hfl,
  );

  /// Alias for riskLabel.
  String get riskLevel => riskLabel;

  /// Alias for city — used by bihar_district_heatmap district grouping.
  String get district => city;

  /// Longitude alias — same as [lon], provided for callers that use `lng`.
  /// Used by bihar_river_map_screen Marker construction.
  double? get lng => lon;

  bool   get hasData     => current >= 0;
  String get levelText   => hasData ? '${current.toStringAsFixed(2)} m' : '-- m';
  double get safeLevel    => hasData ? current : 0.0;
  double get progressPct => hfl > 0 ? (current / hfl).clamp(0.0, 1.0) : 0.0;
  int    get riskScore   => dangerClass.index;

  // ── copyWith ─────────────────────────────────────────────────────────────
  RiverStation copyWith({
    double?  current,
    double?  warning,
    double?  danger,
    double?  hfl,
    double?  lat,
    double?  lon,
    double?  rainfallLastHour,
    double?  flowRate,
    String?  trend,
    String?  liveStatus,
    String?  lastUpdated,
    String?  dataSource,
    bool?    isLive,
  }) => RiverStation(
    city:             city,
    state:            state,
    river:            river,
    station:          station,
    current:          current          ?? this.current,
    warning:          warning          ?? this.warning,
    danger:           danger           ?? this.danger,
    hfl:              hfl              ?? this.hfl,
    lat:              lat              ?? this.lat,
    lon:              lon              ?? this.lon,
    rainfallLastHour: rainfallLastHour ?? this.rainfallLastHour,
    flowRate:         flowRate         ?? this.flowRate,
    trend:            trend            ?? this.trend,
    liveStatus:       liveStatus       ?? this.liveStatus,
    lastUpdated:      lastUpdated      ?? this.lastUpdated,
    dataSource:       dataSource       ?? this.dataSource,
    isLive:           isLive           ?? this.isLive,
  );
}

enum DangerClass { normal, aboveNormal, severe, extreme }

extension DangerClassExt on DangerClass {
  String get label {
    switch (this) {
      case DangerClass.normal:      return 'Normal';
      case DangerClass.aboveNormal: return 'Above Normal';
      case DangerClass.severe:      return 'Severe';
      case DangerClass.extreme:     return 'Extreme';
    }
  }
}
