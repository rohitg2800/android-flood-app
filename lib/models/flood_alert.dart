// lib/models/flood_alert.dart
// OpsFlood — FloodAlert model (android-flood-app edition)
//
// v2 — added AlertType enum + missing fields needed by:
//   alert_share_service, fcm_templates, offline_rule_engine,
//   excel_export_service, ops_depth_card
library;

import 'package:flutter/material.dart';

// ─── AlertLevel ──────────────────────────────────────────────────────────────

enum AlertLevel {
  normal,
  watch,
  warning,
  danger,
  extreme;

  bool get requiresEmergency =>
      this == AlertLevel.danger || this == AlertLevel.extreme;

  String get label => switch (this) {
        AlertLevel.normal => 'Normal',
        AlertLevel.watch => 'Watch',
        AlertLevel.warning => 'Warning',
        AlertLevel.danger => 'Danger',
        AlertLevel.extreme => 'Extreme',
      };

  Color get color => switch (this) {
        AlertLevel.normal => const Color(0xFF00E676),
        AlertLevel.watch => const Color(0xFF40C4FF),
        AlertLevel.warning => const Color(0xFFFFB300),
        AlertLevel.danger => const Color(0xFFFF6D00),
        AlertLevel.extreme => const Color(0xFFFF1744),
      };
}

// ─── AlertType ───────────────────────────────────────────────────────────────

enum AlertType {
  levelAboveHfl,
  levelAboveDanger,
  levelAboveWarning,
  rapidRise,
  forecastDanger24h,
  forecastDanger48h,
  rainfallExtreme,
  rainfallHeavy,
  upstreamCritical,
  multiRiverAlert;

  String get displayName => switch (this) {
        AlertType.levelAboveHfl => 'Above HFL',
        AlertType.levelAboveDanger => 'Above Danger Level',
        AlertType.levelAboveWarning => 'Above Warning Level',
        AlertType.rapidRise => 'Rapid Rise',
        AlertType.forecastDanger24h => 'Forecast Danger (24h)',
        AlertType.forecastDanger48h => 'Forecast Danger (48h)',
        AlertType.rainfallExtreme => 'Extreme Rainfall',
        AlertType.rainfallHeavy => 'Heavy Rainfall',
        AlertType.upstreamCritical => 'Upstream Critical',
        AlertType.multiRiverAlert => 'Multi-River Alert',
      };
}

// ─── FloodAlert ───────────────────────────────────────────────────────────────

class FloodAlert {
  const FloodAlert({
    required this.id,
    required this.cityId,
    required this.cityName,
    required this.river,
    required this.state,
    required this.currentValue,
    required this.dangerLevel,
    required this.warningLevel,
    required this.hfl,
    required this.fillPercent,
    required this.level,
    required this.type,
    required this.issuedAt,
    this.station,
    this.message,
    this.body,
    this.action,
    this.expiresAt,
    this.rateOfRise,
    this.rateOfRiseMph,
    this.rainfall24h,
    this.rainfall24hMm,
  });

  final String id;
  final String cityId;
  final String cityName;
  final String river;
  final String state;
  final double currentValue;
  final double dangerLevel;
  final double warningLevel;
  final double hfl;
  final double fillPercent;
  final AlertLevel level;
  final AlertType type;
  final DateTime issuedAt;

  // Optional / nullable fields used by services
  final String? station; // station name (e.g. "Birpur (Kosi)")
  final String? message; // short summary
  final String? body; // long description / notification body
  final String? action; // recommended action
  final DateTime? expiresAt; // when this alert expires
  final double? rateOfRise; // m/h
  final double? rateOfRiseMph; // m/h alias (some callers use this name)
  final double? rainfall24h; // mm in last 24h
  final double? rainfall24hMm; // alias

  // ── Derived ─────────────────────────────────────────────────────────────

  /// How far above the relevant threshold (metres).
  double get breach {
    if (level == AlertLevel.danger || level == AlertLevel.extreme) {
      return currentValue - dangerLevel;
    }
    return currentValue - warningLevel;
  }

  bool get isDanger =>
      level == AlertLevel.danger || level == AlertLevel.extreme;
  bool get isWarning => level == AlertLevel.warning;
  bool get isWatch => level == AlertLevel.watch;

  @override
  String toString() =>
      'FloodAlert($cityName \u00b7 ${level.label} \u00b7 ${currentValue.toStringAsFixed(2)})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FloodAlert && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
