// lib/models/flood_data.dart
// OpsFlood — FloodData model (canonical v5.1)
//
// v5.1: added flowRateCumecs + isLive getters needed by kosi_birpur_provider
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
  final String   stationId;
  final String   stationName;
  final String   river;
  final String   district;
  final double   currentLevel;
  final double   dangerLevel;
  final double   warningLevel;
  final double?  previousLevel;
  final DateTime? observedAt;
  final String   trend;

  // v2 optional fields
  final String?  _city;
  final String?  _riverName;
  final String?  _state;
  final double?  _flowRate;
  final double?  _imdRainfallMm;
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

  // v5 extended live-data fields
  final String?  _source;
  final double?  _hfl;
  final double?  _rainfall24hMm;
  final double?  _forecastLevel24h;
  final double?  _rateOfRiseMph;

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
    String?   source,
    double?   hfl,
    double?   rainfall24hMm,
    double?   forecastLevel24h,
    double?   rateOfRiseMph,
  })  : _city             = city,
        _riverName        = riverName,
        _state            = state,
        _flowRate         = flowRate,
        _imdRainfallMm    = imdRainfallMm,
        _lastUpdated      = lastUpdated,
        _latitude         = latitude,
        _longitude        = longitude,
        _source           = source,
        _hfl              = hfl,
        _rainfall24hMm    = rainfall24hMm,
        _forecastLevel24h = forecastLevel24h,
        _rateOfRiseMph    = rateOfRiseMph;

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
    String?   source,
    double?   hfl,
    double?   rainfall24hMm,
    double?   forecastLevel24h,
    double?   rateOfRiseMph,
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
        source:            source            ?? _source,
        hfl:               hfl               ?? _hfl,
        rainfall24hMm:     rainfall24hMm     ?? _rainfall24hMm,
        forecastLevel24h:  forecastLevel24h  ?? _forecastLevel24h,
        rateOfRiseMph:     rateOfRiseMph     ?? _rateOfRiseMph,
      );

  // ── Computed getters ─────────────────────────────────────────────────────────
  double get fillPercent =>
      dangerLevel > 0 ? (currentLevel / dangerLevel * 100).clamp(0, 150) : 0;
  bool get isAboveDanger  => currentLevel >= dangerLevel;
  bool get isAboveWarning => currentLevel >= warningLevel;

  // ── Alias getters (v2) ───────────────────────────────────────────────────────
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
  double? get lat => _latitude;
  double? get lon => _longitude;

  // ── v5 extended getters ─────────────────────────────────────────────────────
  String  get source           => _source ?? 'LIVE';
  double  get hfl              => _hfl ?? (dangerLevel > 0 ? dangerLevel * 1.3 : 0);
  double? get rainfall24hMm    => _rainfall24hMm;
  double? get forecastLevel24h => _forecastLevel24h;
  double? get rateOfRiseMph    => _rateOfRiseMph;
  DateTime get fetchedAt       => _lastUpdated ?? observedAt ?? DateTime(1970);
  double  get progressPct      => hfl > 0 ? (currentLevel / hfl).clamp(0.0, 1.0) : 0.0;

  // v5.1 — aliases used by kosi_birpur_provider + befiqr_cwc_service
  /// Flow rate in cumecs (m³/s). Alias for flowRate.
  double? get flowRateCumecs => _flowRate;

  /// True when source is not SEED and data is fresh (< 2h old).
  bool get isLive {
    if (_source == 'SEED') return false;
    final ts = _lastUpdated ?? observedAt;
    if (ts == null) return false;
    return DateTime.now().difference(ts).inHours < 2;
  }

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

  String get riskLabel => riskLevel;

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
        source:            j['source']               as String?,
        hfl:               (j['hfl']                 as num?)?.toDouble(),
        rainfall24hMm:     (j['rainfall_24h_mm']     as num?)?.toDouble(),
        forecastLevel24h:  (j['forecast_level_24h']  as num?)?.toDouble(),
        rateOfRiseMph:     (j['rate_of_rise_mph']    as num?)?.toDouble(),
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
        if (_source           != null) 'source':             _source,
        if (_hfl              != null) 'hfl':                _hfl,
        if (_rainfall24hMm    != null) 'rainfall_24h_mm':   _rainfall24hMm,
        if (_forecastLevel24h != null) 'forecast_level_24h':_forecastLevel24h,
        if (_rateOfRiseMph    != null) 'rate_of_rise_mph':  _rateOfRiseMph,
      };
}
