// lib/models/flood_alert.dart
// OpsFlood — FloodAlert model (android-flood-app edition)
//
// A display-layer model used by screens that import this path.
// Mirrors the AlertLevel vocabulary of ThresholdAlert (including 'watch')
// but lives separately so the import path resolves without touching the
// existing model layer.
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
    AlertLevel.normal  => 'Normal',
    AlertLevel.watch   => 'Watch',
    AlertLevel.warning => 'Warning',
    AlertLevel.danger  => 'Danger',
    AlertLevel.extreme => 'Extreme',
  };

  Color get color => switch (this) {
    AlertLevel.normal  => const Color(0xFF00E676),
    AlertLevel.watch   => const Color(0xFF40C4FF),
    AlertLevel.warning => const Color(0xFFFFB300),
    AlertLevel.danger  => const Color(0xFFFF6D00),
    AlertLevel.extreme => const Color(0xFFFF1744),
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
    required this.fillPercent,
    required this.level,
    required this.issuedAt,
    this.message,
  });

  final String     id;
  final String     cityId;
  final String     cityName;
  final String     river;
  final String     state;
  final double     currentValue;
  final double     dangerLevel;
  final double     warningLevel;
  final double     fillPercent;
  final AlertLevel level;
  final DateTime   issuedAt;
  final String?    message;

  /// How far above the relevant threshold (metres / cumecs).
  double get breach {
    if (level == AlertLevel.danger || level == AlertLevel.extreme) {
      return currentValue - dangerLevel;
    }
    return currentValue - warningLevel;
  }

  bool get isDanger  => level == AlertLevel.danger || level == AlertLevel.extreme;
  bool get isWarning => level == AlertLevel.warning;
  bool get isWatch   => level == AlertLevel.watch;

  @override
  String toString() =>
      'FloodAlert($cityName · ${level.label} · ${currentValue.toStringAsFixed(2)})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FloodAlert && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
