// lib/models/alert_subscription.dart
// Hive-persisted model representing a user's watch subscription on a gauge.
import 'package:hive_flutter/hive_flutter.dart';


part 'alert_subscription.g.dart';

@HiveType(typeId: 10)
@HiveType(typeId: 1)
class AlertSubscription extends HiveObject {
  @HiveField(0)
  final String stationId;
  @HiveField(1)
  final String cityName;
  @HiveField(2)
  final String riverName;

  /// Custom threshold in metres. null = use station's own danger level.
  @HiveField(3)
  final double? customThresholdMetres;

  /// Radius in km within which the user wants to receive alerts.
  @HiveField(4)
  final double notifyRadiusKm;

  /// If true, only notify when a BREACH is predicted (predicted24h >= danger).
  @HiveField(5)
  final bool breachOnlyMode;
  @HiveField(6)
  final DateTime createdAt;

  AlertSubscription({
    required this.stationId,
    required this.cityName,
    required this.riverName,
    this.customThresholdMetres,
    this.notifyRadiusKm = 50.0,
    this.breachOnlyMode = false,
    required this.createdAt,
  });

  // ── Alias getters used by alert_engine.dart ────────────────────────────────
  /// Alias for customThresholdMetres (alert_engine uses this name).
  double? get customThresholdLevel => customThresholdMetres;

  /// Alias for breachOnlyMode.
  bool get notifyOnBreachOnly => breachOnlyMode;

  /// Alias for notifyRadiusKm.
  double get radiusKm => notifyRadiusKm;

  AlertSubscription copyWith({
    double? customThresholdMetres,
    double? notifyRadiusKm,
    bool? breachOnlyMode,
  }) =>
      AlertSubscription(
        stationId: stationId,
        cityName: cityName,
        riverName: riverName,
        customThresholdMetres:
            customThresholdMetres ?? this.customThresholdMetres,
        notifyRadiusKm: notifyRadiusKm ?? this.notifyRadiusKm,
        breachOnlyMode: breachOnlyMode ?? this.breachOnlyMode,
        createdAt: createdAt,
      );

  @override
  String toString() => 'AlertSubscription($cityName / $stationId, '
      'radius: ${notifyRadiusKm}km, '
      'threshold: ${customThresholdMetres ?? "danger"}m, '
      'breachOnly: $breachOnlyMode)';
}
// Note: @GeneratedAdapters annotation removed — not a valid Hive annotation.
