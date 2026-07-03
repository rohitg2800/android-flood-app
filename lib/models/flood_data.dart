import 'package:flutter/material.dart';

// ── EmergencyContact ─────────────────────────────────────────────────────────
/// Simple value class used by RealTimeService and CollapsibleContacts.
class EmergencyContact {
  final String name;
  final String phone;
  final String role;
  const EmergencyContact({
    required this.name,
    required this.phone,
    required this.role,
  });
  factory EmergencyContact.fromJson(Map<String, dynamic> j) => EmergencyContact(
        name: (j['name'] as String? ?? '').trim(),
        phone: (j['phone'] as String? ?? '').trim(),
        role: (j['role'] as String? ?? '').trim(),
      );
  Map<String, dynamic> toJson() => {'name': name, 'phone': phone, 'role': role};
}

// ── FloodData ────────────────────────────────────────────────────────────────
class FloodData {
  final String stationId;
  final String stationName;
  final String? city;
  final String? district;
  final String? state;
  final String? river;
  final String? riverName;
  final double currentLevel;
  final double warningLevel;
  final double dangerLevel;
  final double? discharge;
  final double? flowRate;
  final double? imdRainfallMm;
  final double? latitude;
  final double? longitude;
  final DateTime observedAt;
  final DateTime? lastUpdated;
  final String? trend;

  // ML / severity fields
  final String? predictedSeverity;
  final int? riskScore;
  final double? confidencePercent;
  final bool? willBreachDanger;
  final double? peakLevel72h;

  // Extended fields (v4.3)
  final double? hfl; // Historical Flood Level
  final String? source; // data source identifier
  final double? rainfall24hMm; // 24-hour rainfall (mm)
  final double? forecastLevel24h; // 24-hour forecast water level
  final double? rateOfRiseMph; // rate of rise (m/h)

  FloodData({
    required this.stationId,
    required this.stationName,
    this.city,
    this.district,
    this.state,
    this.river,
    this.riverName,
    required this.currentLevel,
    required this.warningLevel,
    required this.dangerLevel,
    this.discharge,
    this.flowRate,
    this.imdRainfallMm,
    this.latitude,
    this.longitude,
    DateTime? observedAt,
    this.lastUpdated,
    this.trend,
    this.predictedSeverity,
    this.riskScore,
    this.confidencePercent,
    this.willBreachDanger,
    this.peakLevel72h,
    this.hfl,
    this.source,
    this.rainfall24hMm,
    this.forecastLevel24h,
    this.rateOfRiseMph,
  }) : observedAt = observedAt ?? lastUpdated ?? DateTime(1970);

  // ── Convenience getters ────────────────────────────────────────────────────
  String get station => stationName;
  String get id => stationId;

  // Coordinate aliases
  double? get lat => latitude;
  double? get lon => longitude;

  // Live-data flag: true if data is fresher than 2 hours
  bool get isLive {
    final age = DateTime.now().difference(observedAt);
    return age.inHours < 2;
  }

  // Timestamp alias
  DateTime get fetchedAt => lastUpdated ?? observedAt;

  // Reservoir fill percentage (0–100)
  double get fillPercent {
    if (dangerLevel <= 0) return 0;
    return ((currentLevel / dangerLevel) * 100).clamp(0, 100);
  }

  double get capacityPercent => fillPercent;

  // Progress toward danger (0.0–1.0)
  double get progressPct {
    if (dangerLevel <= warningLevel) return 0;
    return ((currentLevel - warningLevel) / (dangerLevel - warningLevel))
        .clamp(0.0, 1.0);
  }

  // Effective rainfall
  double get effectiveRainfallMm => rainfall24hMm ?? imdRainfallMm ?? 0.0;

  // Flow rate alias
  double? get flowRateCumecs => discharge ?? flowRate;

  String get riskLevel {
    if (currentLevel >= dangerLevel) return 'CRITICAL';
    if (currentLevel >= warningLevel) return 'SEVERE';
    if ((dangerLevel - currentLevel) <= 0.5) return 'MODERATE';
    return 'NORMAL';
  }

  String get riskLabel => riskLevel;

  String get status {
    if (currentLevel >= dangerLevel) return 'danger';
    if (currentLevel >= warningLevel) return 'warning';
    return 'normal';
  }

  bool get isAtWarning => currentLevel >= warningLevel;
  bool get isAtDanger => currentLevel >= dangerLevel;

  Color get priorityColor {
    switch (status) {
      case 'danger':
        return const Color(0xFFD32F2F);
      case 'warning':
        return const Color(0xFFF57C00);
      default:
        return const Color(0xFF388E3C);
    }
  }

  // ── copyWith ───────────────────────────────────────────────────────────────
  FloodData copyWith({
    String? stationId,
    String? stationName,
    String? city,
    String? district,
    String? state,
    String? river,
    String? riverName,
    double? currentLevel,
    double? warningLevel,
    double? dangerLevel,
    double? discharge,
    double? flowRate,
    double? imdRainfallMm,
    double? latitude,
    double? longitude,
    DateTime? observedAt,
    DateTime? lastUpdated,
    String? trend,
    String? predictedSeverity,
    int? riskScore,
    double? confidencePercent,
    bool? willBreachDanger,
    double? peakLevel72h,
    double? hfl,
    String? source,
    double? rainfall24hMm,
    double? forecastLevel24h,
    double? rateOfRiseMph,
  }) =>
      FloodData(
        stationId: stationId ?? this.stationId,
        stationName: stationName ?? this.stationName,
        city: city ?? this.city,
        district: district ?? this.district,
        state: state ?? this.state,
        river: river ?? this.river,
        riverName: riverName ?? this.riverName,
        currentLevel: currentLevel ?? this.currentLevel,
        warningLevel: warningLevel ?? this.warningLevel,
        dangerLevel: dangerLevel ?? this.dangerLevel,
        discharge: discharge ?? this.discharge,
        flowRate: flowRate ?? this.flowRate,
        imdRainfallMm: imdRainfallMm ?? this.imdRainfallMm,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        observedAt: observedAt ?? this.observedAt,
        lastUpdated: lastUpdated ?? this.lastUpdated,
        trend: trend ?? this.trend,
        predictedSeverity: predictedSeverity ?? this.predictedSeverity,
        riskScore: riskScore ?? this.riskScore,
        confidencePercent: confidencePercent ?? this.confidencePercent,
        willBreachDanger: willBreachDanger ?? this.willBreachDanger,
        peakLevel72h: peakLevel72h ?? this.peakLevel72h,
        hfl: hfl ?? this.hfl,
        source: source ?? this.source,
        rainfall24hMm: rainfall24hMm ?? this.rainfall24hMm,
        forecastLevel24h: forecastLevel24h ?? this.forecastLevel24h,
        rateOfRiseMph: rateOfRiseMph ?? this.rateOfRiseMph,
      );

  // ── Helpers ────────────────────────────────────────────────────────────────
  static double _d(dynamic v) => v == null ? 0.0 : (v as num).toDouble();
  static double? _dOpt(dynamic v) => v == null ? null : (v as num).toDouble();

  // ── fromJson ───────────────────────────────────────────────────────────────
  factory FloodData.fromJson(Map<String, dynamic> json) => FloodData(
        stationId: (json['station_id'] ?? json['id'] ?? json['station'] ?? '')
            as String,
        stationName: (json['station_name'] ??
            json['name'] ??
            json['station'] ??
            '') as String,
        city: json['city'] as String?,
        district: json['district'] as String?,
        state: json['state'] as String?,
        river: json['river'] as String?,
        riverName: json['riverName'] as String?,
        currentLevel:
            _d(json['current_level'] ?? json['level'] ?? json['currentLevel']),
        warningLevel: _d(
            json['warning_level'] ?? json['warning'] ?? json['warningLevel']),
        dangerLevel:
            _d(json['danger_level'] ?? json['danger'] ?? json['dangerLevel']),
        discharge: _dOpt(json['discharge']),
        flowRate: _dOpt(json['flowRate'] ?? json['flow_rate']),
        imdRainfallMm: _dOpt(json['imdRainfallMm'] ?? json['rainfall24h']),
        latitude: _dOpt(json['latitude']),
        longitude: _dOpt(json['longitude']),
        observedAt: json['observed_at'] != null
            ? DateTime.parse(json['observed_at'] as String)
            : json['lastUpdated'] != null
                ? DateTime.parse(json['lastUpdated'] as String)
                : null,
        lastUpdated: json['lastUpdated'] != null
            ? DateTime.parse(json['lastUpdated'] as String)
            : null,
        trend: json['trend'] as String?,
        predictedSeverity: json['predictedSeverity'] as String?,
        riskScore: (json['riskScore'] as num?)?.toInt(),
        confidencePercent: _dOpt(json['confidencePercent']),
        willBreachDanger: json['willBreachDanger'] as bool?,
        peakLevel72h: _dOpt(json['peakLevel72h']),
        hfl: _dOpt(json['hfl']),
        source: json['source'] as String?,
        rainfall24hMm: _dOpt(json['rainfall24hMm'] ?? json['rainfall24h']),
        forecastLevel24h: _dOpt(json['forecastLevel24h']),
        rateOfRiseMph: _dOpt(json['rateOfRiseMph']),
      );

  // ── toJson ─────────────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
        'station_id': stationId,
        'station': stationName,
        'station_name': stationName,
        if (city != null) 'city': city,
        if (district != null) 'district': district,
        if (state != null) 'state': state,
        if (river != null) 'river': river,
        if (riverName != null) 'riverName': riverName,
        'current_level': currentLevel,
        'warning_level': warningLevel,
        'danger_level': dangerLevel,
        if (discharge != null) 'discharge': discharge,
        if (flowRate != null) 'flowRate': flowRate,
        if (imdRainfallMm != null) 'imdRainfallMm': imdRainfallMm,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'observed_at': observedAt.toIso8601String(),
        if (lastUpdated != null) 'lastUpdated': lastUpdated!.toIso8601String(),
        if (trend != null) 'trend': trend,
        if (predictedSeverity != null) 'predictedSeverity': predictedSeverity,
        if (riskScore != null) 'riskScore': riskScore,
        if (confidencePercent != null) 'confidencePercent': confidencePercent,
        if (willBreachDanger != null) 'willBreachDanger': willBreachDanger,
        if (peakLevel72h != null) 'peakLevel72h': peakLevel72h,
        if (hfl != null) 'hfl': hfl,
        if (source != null) 'source': source,
        if (rainfall24hMm != null) 'rainfall24hMm': rainfall24hMm,
        if (forecastLevel24h != null) 'forecastLevel24h': forecastLevel24h,
        if (rateOfRiseMph != null) 'rateOfRiseMph': rateOfRiseMph,
      };
}
