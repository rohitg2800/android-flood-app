// Plain Dart model — no freezed / json_serializable
// Maps to: public.water_level_readings

class WaterLevelReading {
  final String id;
  final String stationId;
  final double waterLevel;
  final double? rainfall;
  final double? flowRate;
  final double? temperature;
  final double? humidity;
  final String? dataSource; // 'manual' | 'sensor' | 'api'
  final bool isVerified;
  final DateTime recordedAt;
  final DateTime createdAt;

  const WaterLevelReading({
    required this.id,
    required this.stationId,
    required this.waterLevel,
    this.rainfall,
    this.flowRate,
    this.temperature,
    this.humidity,
    this.dataSource,
    this.isVerified = false,
    required this.recordedAt,
    required this.createdAt,
  });

  factory WaterLevelReading.fromJson(Map<String, dynamic> json) =>
      WaterLevelReading(
        id: json['id'] as String,
        stationId: json['station_id'] as String,
        waterLevel: (json['water_level'] as num).toDouble(),
        rainfall: (json['rainfall'] as num?)?.toDouble(),
        flowRate: (json['flow_rate'] as num?)?.toDouble(),
        temperature: (json['temperature'] as num?)?.toDouble(),
        humidity: (json['humidity'] as num?)?.toDouble(),
        dataSource: json['data_source'] as String?,
        isVerified: json['is_verified'] as bool? ?? false,
        recordedAt: DateTime.parse(json['recorded_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'station_id': stationId,
        'water_level': waterLevel,
        'rainfall': rainfall,
        'flow_rate': flowRate,
        'temperature': temperature,
        'humidity': humidity,
        'data_source': dataSource,
        'is_verified': isVerified,
        'recorded_at': recordedAt.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WaterLevelReading && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'WaterLevelReading(stationId: $stationId, level: $waterLevel, at: $recordedAt)';
}
