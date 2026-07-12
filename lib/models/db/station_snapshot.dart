// Plain Dart model — no freezed / json_serializable
// Maps to: public.station_snapshots

enum StationStatus { normal, warning, danger, critical, offline }

StationStatus stationStatusFromString(String s) =>
    StationStatus.values.firstWhere((e) => e.name == s,
        orElse: () => StationStatus.normal);

class StationSnapshot {
  final String id;
  final String stationId;
  final double? currentLevel;
  final double? dangerLevel;
  final double? warningLevel;
  final double? normalLevel;
  final StationStatus status;
  final double? rainfall24h;
  final double? flowRate;
  final String? trend; // 'rising' | 'falling' | 'stable'
  final DateTime snapshotAt;
  final DateTime createdAt;

  const StationSnapshot({
    required this.id,
    required this.stationId,
    this.currentLevel,
    this.dangerLevel,
    this.warningLevel,
    this.normalLevel,
    required this.status,
    this.rainfall24h,
    this.flowRate,
    this.trend,
    required this.snapshotAt,
    required this.createdAt,
  });

  factory StationSnapshot.fromJson(Map<String, dynamic> json) => StationSnapshot(
        id: json['id'] as String,
        stationId: json['station_id'] as String,
        currentLevel: (json['current_level'] as num?)?.toDouble(),
        dangerLevel: (json['danger_level'] as num?)?.toDouble(),
        warningLevel: (json['warning_level'] as num?)?.toDouble(),
        normalLevel: (json['normal_level'] as num?)?.toDouble(),
        status: stationStatusFromString(json['status'] as String),
        rainfall24h: (json['rainfall_24h'] as num?)?.toDouble(),
        flowRate: (json['flow_rate'] as num?)?.toDouble(),
        trend: json['trend'] as String?,
        snapshotAt: DateTime.parse(json['snapshot_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'station_id': stationId,
        'current_level': currentLevel,
        'danger_level': dangerLevel,
        'warning_level': warningLevel,
        'normal_level': normalLevel,
        'status': status.name,
        'rainfall_24h': rainfall24h,
        'flow_rate': flowRate,
        'trend': trend,
        'snapshot_at': snapshotAt.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  bool get isAboveDanger =>
      currentLevel != null &&
      dangerLevel != null &&
      currentLevel! >= dangerLevel!;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StationSnapshot && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
