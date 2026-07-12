import 'package:hive_flutter/hive_flutter.dart';
@HiveType(typeId: 10)
class AlertSubscription extends HiveObject {
  @HiveField(0)
  final String stationId;

  @HiveField(1)
  final String cityName;

  @HiveField(2)
  final String riverName;

  @HiveField(3)
  final double? customThresholdMetres;

  @HiveField(4)
  final double notifyRadiusKm;

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

  double? get customThresholdLevel => customThresholdMetres;
  bool get notifyOnBreachOnly => breachOnlyMode;
  double get radiusKm => notifyRadiusKm;

  AlertSubscription copyWith({
    double? customThresholdMetres,
    double? notifyRadiusKm,
    bool? breachOnlyMode,
  }) {
    return AlertSubscription(
      stationId: stationId,
      cityName: cityName,
      riverName: riverName,
      customThresholdMetres:
          customThresholdMetres ?? this.customThresholdMetres,
      notifyRadiusKm: notifyRadiusKm ?? this.notifyRadiusKm,
      breachOnlyMode: breachOnlyMode ?? this.breachOnlyMode,
      createdAt: createdAt,
    );
  }

  @override
  String toString() =>
      'AlertSubscription($cityName / $stationId, radius: ${notifyRadiusKm}km, threshold: ${customThresholdMetres ?? "danger"}m, breachOnly: $breachOnlyMode)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlertSubscription &&
          runtimeType == other.runtimeType &&
          stationId == other.stationId &&
          cityName == other.cityName &&
          riverName == other.riverName &&
          customThresholdMetres == other.customThresholdMetres &&
          notifyRadiusKm == other.notifyRadiusKm &&
          breachOnlyMode == other.breachOnlyMode;

  @override
  int get hashCode => Object.hash(
        stationId,
        cityName,
        riverName,
        customThresholdMetres,
        notifyRadiusKm,
        breachOnlyMode,
      );
}
