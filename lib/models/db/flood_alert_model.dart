// Plain Dart model — no freezed / json_serializable
// Maps to: public.flood_alerts
// Enums serialized via .name (Dart 2.15+)

enum AlertSeverity { low, moderate, high, critical, extreme }
enum AlertStatus { active, resolved, expired, pending }

AlertSeverity alertSeverityFromString(String s) =>
    AlertSeverity.values.firstWhere((e) => e.name == s,
        orElse: () => AlertSeverity.low);

AlertStatus alertStatusFromString(String s) =>
    AlertStatus.values.firstWhere((e) => e.name == s,
        orElse: () => AlertStatus.pending);

class FloodAlertModel {
  final String id;
  final String title;
  final String? description;
  final AlertSeverity severity;
  final AlertStatus status;
  final String? district;
  final String? state;
  final double? latitude;
  final double? longitude;
  final double? radiusKm;
  final String? riverName;
  final double? currentWaterLevel;
  final double? dangerLevel;
  final double? warningLevel;
  final String? issuedBy;
  final DateTime issuedAt;
  final DateTime? expiresAt;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FloodAlertModel({
    required this.id,
    required this.title,
    this.description,
    required this.severity,
    required this.status,
    this.district,
    this.state,
    this.latitude,
    this.longitude,
    this.radiusKm,
    this.riverName,
    this.currentWaterLevel,
    this.dangerLevel,
    this.warningLevel,
    this.issuedBy,
    required this.issuedAt,
    this.expiresAt,
    this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FloodAlertModel.fromJson(Map<String, dynamic> json) => FloodAlertModel(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        severity: alertSeverityFromString(json['severity'] as String),
        status: alertStatusFromString(json['status'] as String),
        district: json['district'] as String?,
        state: json['state'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        radiusKm: (json['radius_km'] as num?)?.toDouble(),
        riverName: json['river_name'] as String?,
        currentWaterLevel: (json['current_water_level'] as num?)?.toDouble(),
        dangerLevel: (json['danger_level'] as num?)?.toDouble(),
        warningLevel: (json['warning_level'] as num?)?.toDouble(),
        issuedBy: json['issued_by'] as String?,
        issuedAt: DateTime.parse(json['issued_at'] as String),
        expiresAt: json['expires_at'] != null
            ? DateTime.parse(json['expires_at'] as String)
            : null,
        resolvedAt: json['resolved_at'] != null
            ? DateTime.parse(json['resolved_at'] as String)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'severity': severity.name,
        'status': status.name,
        'district': district,
        'state': state,
        'latitude': latitude,
        'longitude': longitude,
        'radius_km': radiusKm,
        'river_name': riverName,
        'current_water_level': currentWaterLevel,
        'danger_level': dangerLevel,
        'warning_level': warningLevel,
        'issued_by': issuedBy,
        'issued_at': issuedAt.toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
        'resolved_at': resolvedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  bool get isActive => status == AlertStatus.active;
  bool get isCriticalOrAbove =>
      severity == AlertSeverity.critical || severity == AlertSeverity.extreme;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is FloodAlertModel && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'FloodAlertModel(id: $id, severity: ${severity.name}, status: ${status.name})';
}
