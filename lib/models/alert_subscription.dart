// lib/models/alert_subscription.dart  Step 3.1
// Hive-persisted model representing a user's watch subscription on a gauge station.

import 'package:hive_flutter/hive_flutter.dart';

part 'alert_subscription.g.dart';

@HiveType(typeId: 10)
class AlertSubscription extends HiveObject {
  @HiveField(0) final String stationId;
  @HiveField(1) final String cityName;
  @HiveField(2) final String riverName;
  /// Custom threshold in metres. null = use station's own danger level.
  @HiveField(3) final double? customThresholdMetres;
  /// Radius in km within which the user wants to receive alerts.
  @HiveField(4) final double notifyRadiusKm;
  /// If true, only notify when a BREACH is predicted (predicted24h >= danger).
  @HiveField(5) final bool breachOnlyMode;
  @HiveField(6) final DateTime createdAt;

  AlertSubscription({
    required this.stationId,
    required this.cityName,
    required this.riverName,
    this.customThresholdMetres,
    this.notifyRadiusKm = 50.0,
    this.breachOnlyMode = false,
    required this.createdAt,
  });

  AlertSubscription copyWith({
    double? customThresholdMetres,
    double? notifyRadiusKm,
    bool?   breachOnlyMode,
  }) {
    return AlertSubscription(
      stationId:             stationId,
      cityName:              cityName,
      riverName:             riverName,
      customThresholdMetres: customThresholdMetres ?? this.customThresholdMetres,
      notifyRadiusKm:        notifyRadiusKm        ?? this.notifyRadiusKm,
      breachOnlyMode:        breachOnlyMode        ?? this.breachOnlyMode,
      createdAt:             createdAt,
    );
  }

  @override
  String toString() =>
      'AlertSubscription($cityName / $stationId, '
      'radius: ${notifyRadiusKm}km, '
      'threshold: ${customThresholdMetres ?? "danger"}m, '
      'breachOnly: $breachOnlyMode)';
}

// ── Pre-generated TypeAdapter (hive_generator removed to avoid analyzer conflict)
// Regenerate with: dart run build_runner build --delete-conflicting-outputs
@GeneratedAdapters([AlertSubscription])
void _placeholder() {}
