// lib/models/alert_subscription.dart  v1.0 — Step 3.1
// AlertSubscription: persisted per-station watch entry.
// Stored in Hive box 'subscriptions' (manual adapter — no build_runner).

import 'package:hive/hive.dart';

part 'alert_subscription.g.dart';

@HiveType(typeId: 10)
class AlertSubscription {
  @HiveField(0) final String stationId;
  @HiveField(1) final String cityName;
  /// null = use default warning/danger thresholds from FloodData
  @HiveField(2) final double? customThresholdLevel;
  /// true = only notify when predicted breach (willBreachDanger), not at every level rise
  @HiveField(3) final bool notifyOnBreachOnly;
  /// radius in km; 0 = always notify regardless of user location
  @HiveField(4) final double radiusKm;
  @HiveField(5) final DateTime createdAt;

  const AlertSubscription({
    required this.stationId,
    required this.cityName,
    this.customThresholdLevel,
    this.notifyOnBreachOnly = false,
    this.radiusKm = 50.0,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'stationId':             stationId,
        'cityName':              cityName,
        'customThresholdLevel':  customThresholdLevel,
        'notifyOnBreachOnly':    notifyOnBreachOnly,
        'radiusKm':              radiusKm,
        'createdAt':             createdAt.toIso8601String(),
      };

  factory AlertSubscription.fromJson(Map<String, dynamic> j) =>
      AlertSubscription(
        stationId:            j['stationId'] as String,
        cityName:             j['cityName'] as String,
        customThresholdLevel: (j['customThresholdLevel'] as num?)?.toDouble(),
        notifyOnBreachOnly:   j['notifyOnBreachOnly'] as bool? ?? false,
        radiusKm:             (j['radiusKm'] as num?)?.toDouble() ?? 50.0,
        createdAt:            DateTime.parse(j['createdAt'] as String),
      );

  AlertSubscription copyWith({
    double? customThresholdLevel,
    bool?   notifyOnBreachOnly,
    double? radiusKm,
  }) =>
      AlertSubscription(
        stationId:            stationId,
        cityName:             cityName,
        customThresholdLevel: customThresholdLevel ?? this.customThresholdLevel,
        notifyOnBreachOnly:   notifyOnBreachOnly   ?? this.notifyOnBreachOnly,
        radiusKm:             radiusKm             ?? this.radiusKm,
        createdAt:            createdAt,
      );
}
