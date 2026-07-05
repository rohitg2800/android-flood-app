/// WaterLevelReading model — Issue #45
library;

enum WaterLevelStatus { normal, warning, danger, critical }

extension WaterLevelStatusX on WaterLevelStatus {
  String get label => name[0].toUpperCase() + name.substring(1);

  static WaterLevelStatus fromString(String? s) {
    switch (s?.toLowerCase()) {
      case 'warning':
        return WaterLevelStatus.warning;
      case 'danger':
        return WaterLevelStatus.danger;
      case 'critical':
        return WaterLevelStatus.critical;
      default:
        return WaterLevelStatus.normal;
    }
  }
}

class WaterLevelReading {
  final String stationName;
  final double levelMeters;
  final double? flowRate;
  final WaterLevelStatus status;
  final DateTime recordedAt;

  const WaterLevelReading({
    required this.stationName,
    required this.levelMeters,
    this.flowRate,
    required this.status,
    required this.recordedAt,
  });

  factory WaterLevelReading.fromJson(Map<String, dynamic> json) =>
      WaterLevelReading(
        stationName: json['station_name'] as String? ?? '',
        levelMeters: (json['level_meters'] as num).toDouble(),
        flowRate: json['flow_rate'] != null
            ? (json['flow_rate'] as num).toDouble()
            : null,
        status: WaterLevelStatusX.fromString(json['status'] as String?),
        recordedAt: DateTime.parse(json['recorded_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'station_name': stationName,
        'level_meters': levelMeters,
        'flow_rate': flowRate,
        'status': status.label,
        'recorded_at': recordedAt.toIso8601String(),
      };
}
