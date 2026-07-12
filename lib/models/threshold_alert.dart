// lib/models/threshold_alert.dart
// OpsFlood — ThresholdAlert model + AlertLevel + TrendDirection enums
library;

import 'package:flutter/foundation.dart';

// ─── AlertLevel ──────────────────────────────────────────────────────────────

enum AlertLevel {
  normal,
  watch,
  warning,
  danger,
  extreme;

  bool get requiresEmergency => this == danger || this == extreme;

  /// Severity order: higher = more severe.
  int get order => index;

  String get label => switch (this) {
        AlertLevel.normal => 'Normal',
        AlertLevel.watch => 'Watch',
        AlertLevel.warning => 'Warning',
        AlertLevel.danger => 'Danger',
        AlertLevel.extreme => 'Extreme',
      };
}

// ─── TrendDirection ───────────────────────────────────────────────────────────

enum TrendDirection {
  rising,
  steady,
  falling;

  String get label => switch (this) {
        TrendDirection.rising => 'Rising',
        TrendDirection.steady => 'Steady',
        TrendDirection.falling => 'Falling',
      };
}

// ─── ThresholdAlert ───────────────────────────────────────────────────────────

@immutable
class ThresholdAlert {
  const ThresholdAlert({
    required this.id,
    required this.cityId,
    required this.cityName,
    required this.state,
    required this.river,
    required this.level,
    required this.currentValue,
    required this.warningLevel,
    required this.dangerLevel,
    required this.hfl,
    required this.breachMargin,
    required this.fillPercent,
    required this.timestamp,
    this.isDischarge = false,
    this.previousValue,
    this.trend = TrendDirection.steady,
    this.isSeen = false,
  });

  final String id;
  final String cityId;
  final String cityName;
  final String state;
  final String river;
  final AlertLevel level;
  final double currentValue;
  final double warningLevel;
  final double dangerLevel;
  final double hfl;
  final double breachMargin;
  final double fillPercent;
  final DateTime timestamp;
  final bool isDischarge;
  final double? previousValue;
  final TrendDirection trend;
  final bool isSeen;

  ThresholdAlert copyWith({
    String? id,
    String? cityId,
    String? cityName,
    String? state,
    String? river,
    AlertLevel? level,
    double? currentValue,
    double? warningLevel,
    double? dangerLevel,
    double? hfl,
    double? breachMargin,
    double? fillPercent,
    DateTime? timestamp,
    bool? isDischarge,
    double? previousValue,
    TrendDirection? trend,
    bool? isSeen,
  }) {
    return ThresholdAlert(
      id: id ?? this.id,
      cityId: cityId ?? this.cityId,
      cityName: cityName ?? this.cityName,
      state: state ?? this.state,
      river: river ?? this.river,
      level: level ?? this.level,
      currentValue: currentValue ?? this.currentValue,
      warningLevel: warningLevel ?? this.warningLevel,
      dangerLevel: dangerLevel ?? this.dangerLevel,
      hfl: hfl ?? this.hfl,
      breachMargin: breachMargin ?? this.breachMargin,
      fillPercent: fillPercent ?? this.fillPercent,
      timestamp: timestamp ?? this.timestamp,
      isDischarge: isDischarge ?? this.isDischarge,
      previousValue: previousValue ?? this.previousValue,
      trend: trend ?? this.trend,
      isSeen: isSeen ?? this.isSeen,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThresholdAlert &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ThresholdAlert($cityName, $level, $currentValue)';
}
