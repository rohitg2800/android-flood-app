// Module 3: Flood Alert Model

enum AlertSeverity { low, medium, high, critical }

class FloodAlert {
  final String id;
  final String title;
  final AlertSeverity severity;
  final double? locationLat;
  final double? locationLng;
  final String? areaName;
  final String? description;
  final DateTime issuedAt;
  final DateTime? expiresAt;
  final bool isActive;

  const FloodAlert({
    required this.id,
    required this.title,
    required this.severity,
    this.locationLat,
    this.locationLng,
    this.areaName,
    this.description,
    required this.issuedAt,
    this.expiresAt,
    this.isActive = true,
  });

  factory FloodAlert.fromJson(Map<String, dynamic> json) {
    return FloodAlert(
      id: json['id'] as String,
      title: json['title'] as String,
      severity: AlertSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
        orElse: () => AlertSeverity.low,
      ),
      locationLat: (json['location_lat'] as num?)?.toDouble(),
      locationLng: (json['location_lng'] as num?)?.toDouble(),
      areaName: json['area_name'] as String?,
      description: json['description'] as String?,
      issuedAt: DateTime.parse(json['issued_at'] as String),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'severity': severity.name,
    'location_lat': locationLat,
    'location_lng': locationLng,
    'area_name': areaName,
    'description': description,
    'issued_at': issuedAt.toIso8601String(),
    'expires_at': expiresAt?.toIso8601String(),
    'is_active': isActive,
  };
}
