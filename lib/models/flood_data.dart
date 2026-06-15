// lib/models/flood_data.dart
// OpsFlood — FloodData model (canonical v5)
//
// v5 (15 Jun 2026) — add 11 missing fields used by backend_sync_service,
//   export_screen, river_detail_screen, active_alert_controller, and tests.
//   All additions are optional/nullable — zero breaking changes.

import 'package:flutter/material.dart';

class EmergencyContact {
  final String name;
  final String phone;
  final String role;
  const EmergencyContact({
    required this.name,
    required this.phone,
    this.role = '',
  });
  factory EmergencyContact.fromJson(Map<String, dynamic> j) =>
      EmergencyContact(
        name:  j['name']  as String? ?? '',
        phone: j['phone'] as String? ?? '',
        role:  j['role']  as String? ?? '',
      );
  Map<String, dynamic> toJson() =>
      {'name': name, 'phone': phone, 'role': role};
}

class FloodData {
  final String    stationId;
  final String    stationName;
  final String    river;
  final String    district;
  final double    currentLevel;
  final double    dangerLevel;
  final double    warningLevel;
  final double?   previousLevel;
  final DateTime? observedAt;
  final String    trend;

  // v2 optional fields
  final String?   _city;
  final String?   _riverName;
  final String?   _state;
  final double?   _flowRate;
  final double?   _imdRainfallMm;
  final DateTime? _lastUpdated;

  // v3 ML prediction fields
  final String?  predictedSeverity;
  final int?     riskScore;
  final double?  confidencePercent;
  final bool?    willBreachDanger;
  final double?  peakLevel72h;

  // v4 geo fields
  final double?  _latitude;
  final double?  _longitude;

  // v5 extended telemetry / chart / test fields
  final double?   hfl;             // highest flood level (m)
  final String?   source;          // data source label e.g. 'CWC', 'IMD'
  final double?   normalLevel;     // low-flow normal gauge level (m)
  final double?   rainfall24hMm;   // 24h accumulated rainfall in mm
  final double?   forecastLevel24h;// predicted level 24h from now (m)
  final double?   rateOfRiseMph;   // rate of rise metres-per-hour
  final DateTime? _fetchedAt;      // wall-clock time data was pulled

  const FloodData({
    required this.stationId,
    required this.stationName,
    required this.river,
    required this.district,
    required this.currentLevel,
    required this.dangerLevel,
    required this.warningLevel,
    this.previousLevel,
    this.observedAt,
    this.trend = 'steady',
    String?   city,
    String?   riverName,
    String?   state,
    double?   flowRate,
    double?   imdRainfallMm,
    DateTime? lastUpdated,
    this.predictedSeverity,
    this.riskScore,
    this.confidencePercent,
    this.willBreachDanger,
    this.peakLevel72h,
    double?   latitude,
    double?   longitude,
    // v5
    this.hfl,
    this.source,
    this.normalLevel,
    this.rainfall24hMm,
    this.forecastLevel24h,
    this.rateOfRiseMph,
    DateTime? fetchedAt,
  })  : _city          = city,
        _riverName     = riverName,
        _state         = state,
        _flowRate      = flowRate,
        _imdRainfallMm = imdRainfallMm,
        _lastUpdated   = lastUpdated,
        _latitude      = latitude,
        _longitude     = longitude,
        _fetchedAt     = fetchedAt;

  FloodData copyWith({
    String?   stationId,
    String?   stationName,
    String?   river,
    String?   district,
    double?   currentLevel,
    double?   dangerLevel,
    double?   warningLevel,
    double?   previousLevel,
    DateTime? observedAt,
    String?   trend,
    String?   city,
    String?   riverName,
    String?   state,
    double?   flowRate,
    double?   imdRainfallMm,
    DateTime? lastUpdated,
    String?   predictedSeverity,
    int?      riskScore,
    double?   confidencePercent,
    bool?     willBreachDanger,
    double?   peakLevel72h,
    double?   latitude,
    double?   longitude,
    double?   hfl,
    String?   source,
    double?   normalLevel,
    double?   rainfall24hMm,
    double?   forecastLevel24h,
    double?   rateOfRiseMph,
    DateTime? fetchedAt,
  }) =>
      FloodData(
        stationId:         stationId         ?? this.stationId,
        stationName:       stationName       ?? this.stationName,
        river:             river             ?? this.river,
        district:          district          ?? this.district,
        currentLevel:      currentLevel      ?? this.currentLevel,
        dangerLevel:       dangerLevel       ?? this.dangerLevel,
        warningLevel:      warningLevel      ?? this.warningLevel,
        previousLevel:     previousLevel     ?? this.previousLevel,
        observedAt:        observedAt        ?? this.observedAt,
        trend:             trend             ?? this.trend,
        city:              city              ?? _city,
        riverName:         riverName         ?? _riverName,
        state:             state             ?? _state,
        flowRate:          flowRate          ?? _flowRate,
        imdRainfallMm:     imdRainfallMm     ?? _imdRainfallMm,
        lastUpdated:       lastUpdated       ?? _lastUpdated,
        predictedSeverity: predictedSeverity ?? this.predictedSeverity,
        riskScore:         riskScore         ?? this.riskScore,
        confidencePercent: confidencePercent ?? this.confidencePercent,
        willBreachDanger:  willBreachDanger  ?? this.willBreachDanger,
        peakLevel72h:      peakLevel72h      ?? this.peakLevel72h,
        latitude:          latitude          ?? _latitude,
        longitude:         longitude         ?? _longitude,
        hfl:               hfl               ?? this.hfl,
        source:            source            ?? this.source,
        normalLevel:       normalLevel       ?? this.normalLevel,
        rainfall24hMm:     rainfall24hMm     ?? this.rainfall24hMm,
        forecastLevel24h:  forecastLevel24h  ?? this.forecastLevel24h,
        rateOfRiseMph:     rateOfRiseMph     ?? this.rateOfRiseMph,
        fetchedAt:         fetchedAt         ?? _fetchedAt,
      );

  // ── Computed getters ────────────────────────────────────────────────────────
  double get fillPercent =>
      dangerLevel > 0 ? (currentLevel / dangerLevel * 100).clamp(0, 150) : 0;
  bool get isAboveDanger  => currentLevel >= dangerLevel;
  bool get isAboveWarning => currentLevel >= warningLevel;

  // ── Alias getters (v1–v4 compat) ──────────────────────────────────────────
  String  get city          => _city?.isNotEmpty == true ? _city! : stationName;
  String? get riverName     => _riverName?.isNotEmpty == true ? _riverName : river;
  String  get state         => _state?.isNotEmpty == true ? _state! : district;
  double? get flowRate      => _flowRate;
  double? get imdRainfallMm => _imdRainfallMm;
  double  get effectiveRainfallMm => _imdRainfallMm ?? 0.0;
  DateTime? get lastUpdated => _lastUpdated ?? observedAt;
  double  get capacityPercent => fillPercent.clamp(0, 100).toDouble();
  double? get latitude  => _latitude;
  double? get longitude => _longitude;

  // ── v5 alias getters ────────────────────────────────────────────────────────
  /// Short-form geo aliases used by backend_sync_service JSON payload
  double? get lat => _latitude;
  double? get lon => _longitude;

  /// Risk label string — same as riskLevel; explicit alias so callers
  /// can use either name without confusion with numeric riskScore.
  String get riskLabel => riskLevel;

  /// Progress percent of danger level as a 0–100 double.
  /// Alias of fillPercent clamped to 100; used by backend_sync telemetry.
  double get progressPct => fillPercent.clamp(0, 100).toDouble();

  /// Wall-clock time data was fetched. Falls back to lastUpdated then now.
  DateTime get fetchedAt => _fetchedAt ?? lastUpdated ?? DateTime.now();

  // ── Risk classification ──────────────────────────────────────────────────────
  String get riskLevel {
    if (dangerLevel <= 0) return 'UNKNOWN';
    final pct = currentLevel / dangerLevel;
    if (pct >= 1.0)  return 'CRITICAL';
    if (pct >= 0.90) return 'DANGER';
    if (pct >= 0.75) return 'HIGH';
    if (pct >= 0.60) return 'WARNING';
    if (pct >= 0.40) return 'MODERATE';
    return 'SAFE';
  }

  String get status {
    final ts = lastUpdated;
    if (ts == null) return 'STALE';
    return DateTime.now().difference(ts).inHours < 2 ? 'LIVE' : 'STALE';
  }

  Color get priorityColor {
    final sev = predictedSeverity?.toUpperCase() ?? riskLevel;
    switch (sev) {
      case 'CRITICAL': return const Color(0xFFFF1A44);
      case 'SEVERE':   return const Color(0xFFFF5500);
      case 'DANGER':   return const Color(0xFFFF5500);
      case 'HIGH':     return const Color(0xFFFFA520);
      case 'WARNING':  return const Color(0xFFFFA520);
      case 'MODERATE': return const Color(0xFF10E88A);
      default:         return const Color(0xFF10E88A);
    }
  }

  // ── JSON ───────────────────────────────────────────────────────────────────
  factory FloodData.fromJson(Map<String, dynamic> j) => FloodData(
        stationId:    j['station_id']    as String? ?? '',
        stationName:  j['station_name']  as String? ?? '',
        river:        j['river']         as String? ?? '',
        district:     j['district']      as String? ?? '',
        currentLevel: (j['current_level']  as num?)?.toDouble() ?? 0,
        dangerLevel:  (j['danger_level']   as num?)?.toDouble() ?? 0,
        warningLevel: (j['warning_level']  as num?)?.toDouble() ?? 0,
        previousLevel:(j['previous_level'] as num?)?.toDouble(),
        observedAt: j['observed_at'] != null
            ? DateTime.tryParse(j['observed_at'] as String)
            : null,
        trend: j['trend'] as String? ?? 'steady',
        city:          j['city']           as String?,
        riverName:     j['river_name']     as String?,
        state:         j['state']          as String?,
        flowRate:      (j['flow_rate']      as num?)?.toDouble(),
        imdRainfallMm: (j['imd_rainfall_mm'] as num?)?.toDouble(),
        lastUpdated: j['last_updated'] != null
            ? DateTime.tryParse(j['last_updated'] as String)
            : null,
        predictedSeverity: j['predicted_severity'] as String?,
        riskScore:         (j['risk_score']         as num?)?.toInt(),
        confidencePercent: (j['confidence_percent'] as num?)?.toDouble(),
        willBreachDanger:  j['will_breach_danger']  as bool?,
        peakLevel72h:      (j['peak_level_72h']     as num?)?.toDouble(),
        latitude:          (j['latitude']            as num?)?.toDouble(),
        longitude:         (j['longitude']           as num?)?.toDouble(),
        // v5
        hfl:              (j['hfl']               as num?)?.toDouble(),
        source:            j['source']             as String?,
        normalLevel:      (j['normal_level']       as num?)?.toDouble(),
        rainfall24hMm:    (j['rainfall_24h']       as num?)?.toDouble(),
        forecastLevel24h: (j['forecast_24h']       as num?)?.toDouble(),
        rateOfRiseMph:    (j['rate_of_rise']       as num?)?.toDouble(),
        fetchedAt: j['fetched_at'] != null
            ? DateTime.tryParse(j['fetched_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'station_id':    stationId,
        'station_name':  stationName,
        'river':         river,
        'district':      district,
        'current_level': currentLevel,
        'danger_level':  dangerLevel,
        'warning_level': warningLevel,
        if (previousLevel != null) 'previous_level': previousLevel,
        if (observedAt   != null) 'observed_at': observedAt!.toIso8601String(),
        'trend': trend,
        if (_city          != null) 'city':              _city,
        if (_riverName     != null) 'river_name':        _riverName,
        if (_state         != null) 'state':             _state,
        if (_flowRate      != null) 'flow_rate':         _flowRate,
        if (_imdRainfallMm != null) 'imd_rainfall_mm':  _imdRainfallMm,
        if (_lastUpdated   != null) 'last_updated':      _lastUpdated!.toIso8601String(),
        if (predictedSeverity != null) 'predicted_severity': predictedSeverity,
        if (riskScore         != null) 'risk_score':         riskScore,
        if (confidencePercent != null) 'confidence_percent': confidencePercent,
        if (willBreachDanger  != null) 'will_breach_danger': willBreachDanger,
        if (peakLevel72h      != null) 'peak_level_72h':     peakLevel72h,
        if (_latitude         != null) 'latitude':           _latitude,
        if (_longitude        != null) 'longitude':          _longitude,
        // v5
        if (hfl              != null) 'hfl':          hfl,
        if (source           != null) 'source':        source,
        if (normalLevel      != null) 'normal_level':  normalLevel,
        if (rainfall24hMm    != null) 'rainfall_24h':  rainfall24hMm,
        if (forecastLevel24h != null) 'forecast_24h':  forecastLevel24h,
        if (rateOfRiseMph    != null) 'rate_of_rise':  rateOfRiseMph,
        if (_fetchedAt       != null) 'fetched_at':    _fetchedAt!.toIso8601String(),
      };
}
