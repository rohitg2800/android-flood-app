// lib/models/flood_data.dart
// OpsFlood — FloodData model (canonical v2)
//
// v2 adds:
//  • EmergencyContact class (used by real_time_service.dart)
//  • Alias getters on FloodData so legacy call-sites (city, riverName,
//    state, riskLevel, status, capacityPercent, lastUpdated, flowRate,
//    imdRainfallMm, effectiveRainfallMm, priorityColor) compile without
//    renaming every screen / provider.
//  • Optional constructor aliases city / riverName / state so providers
//    that build FloodData with those named params still compile.

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EmergencyContact  (imported by real_time_service.dart)
// ─────────────────────────────────────────────────────────────────────────────

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

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'role': role,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// FloodData
// ─────────────────────────────────────────────────────────────────────────────

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
  final String   trend; // 'rising' | 'falling' | 'steady'

  // ── Optional fields added by newer providers ─────────────────────────────
  /// Explicit city label (falls back to stationName).
  final String?  _city;
  /// River name override (falls back to river).
  final String?  _riverName;
  /// State / province string (falls back to district).
  final String?  _state;
  /// Flow rate in m³/s.
  final double?  _flowRate;
  /// IMD-sourced rainfall in mm.
  final double?  _imdRainfallMm;
  /// Timestamp of last update (falls back to observedAt).
  final DateTime? _lastUpdated;

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
    // ── alias constructor params ──────────────────────────────────────
    String?   city,
    String?   riverName,
    String?   state,
    double?   flowRate,
    double?   imdRainfallMm,
    DateTime? lastUpdated,
  })  : _city          = city,
        _riverName     = riverName,
        _state         = state,
        _flowRate      = flowRate,
        _imdRainfallMm = imdRainfallMm,
        _lastUpdated   = lastUpdated;

  // ── Canonical computed getters ────────────────────────────────────────────

  /// Percentage of danger-level capacity (0–150).
  double get fillPercent =>
      dangerLevel > 0 ? (currentLevel / dangerLevel * 100).clamp(0, 150) : 0;

  bool get isAboveDanger  => currentLevel >= dangerLevel;
  bool get isAboveWarning => currentLevel >= warningLevel;

  // ── Alias getters for legacy call-sites ──────────────────────────────────

  /// Human-readable city / station name.
  String get city => _city?.isNotEmpty == true ? _city! : stationName;

  /// River name.
  String? get riverName => _riverName?.isNotEmpty == true ? _riverName : river;

  /// State name (falls back to district).
  String get state => _state?.isNotEmpty == true ? _state! : district;

  /// Flow rate in m³/s (nullable).
  double? get flowRate => _flowRate;

  /// IMD-sourced rainfall in mm (nullable).
  double? get imdRainfallMm => _imdRainfallMm;

  /// Effective rainfall: IMD value if available, else 0.
  double get effectiveRainfallMm => _imdRainfallMm ?? 0.0;

  /// Last updated timestamp.
  DateTime? get lastUpdated => _lastUpdated ?? observedAt;

  /// Capacity as a percentage (alias for fillPercent, capped at 100).
  double get capacityPercent => fillPercent.clamp(0, 100).toDouble();

  /// Risk level string derived from current vs danger/warning levels.
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

  /// Status string: 'LIVE' when observedAt is within the last 2 hours.
  String get status {
    final ts = lastUpdated;
    if (ts == null) return 'STALE';
    final age = DateTime.now().difference(ts);
    return age.inHours < 2 ? 'LIVE' : 'STALE';
  }

  /// Priority color based on riskLevel (uses AppPalette-style values).
  Color get priorityColor {
    switch (riskLevel) {
      case 'CRITICAL': return const Color(0xFFFF1A44);
      case 'DANGER':   return const Color(0xFFFF5500);
      case 'HIGH':     return const Color(0xFFFFA520);
      case 'WARNING':  return const Color(0xFFFFA520);
      case 'MODERATE': return const Color(0xFF10E88A);
      default:         return const Color(0xFF10E88A);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Serialisation
  // ─────────────────────────────────────────────────────────────────────────

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
        city:          j['city']          as String?,
        riverName:     j['river_name']    as String?,
        state:         j['state']         as String?,
        flowRate:      (j['flow_rate']     as num?)?.toDouble(),
        imdRainfallMm: (j['imd_rainfall_mm'] as num?)?.toDouble(),
        lastUpdated: j['last_updated'] != null
            ? DateTime.tryParse(j['last_updated'] as String)
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
        if (observedAt != null) 'observed_at': observedAt!.toIso8601String(),
        'trend': trend,
        if (_city != null)          'city':            _city,
        if (_riverName != null)     'river_name':      _riverName,
        if (_state != null)         'state':           _state,
        if (_flowRate != null)      'flow_rate':       _flowRate,
        if (_imdRainfallMm != null) 'imd_rainfall_mm': _imdRainfallMm,
        if (_lastUpdated != null)   'last_updated':    _lastUpdated!.toIso8601String(),
      };
}
