class AlertModel {
  final String id;
  final String title;
  final String severity; // low | medium | high | critical
  final double? locationLat;
  final double? locationLng;
  final String? areaName;
  final String description;
  final DateTime issuedAt;
  final DateTime? expiresAt;
  final bool isActive;

  const AlertModel({
    required this.id,
    required this.title,
    required this.severity,
    this.locationLat,
    this.locationLng,
    this.areaName,
    required this.description,
    required this.issuedAt,
    this.expiresAt,
    this.isActive = true,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) => AlertModel(
        id: json['id'],
        title: json['title'],
        severity: json['severity'],
        locationLat: json['location_lat']?.toDouble(),
        locationLng: json['location_lng']?.toDouble(),
        areaName: json['area_name'],
        description: json['description'] ?? '',
        issuedAt: DateTime.parse(json['issued_at']),
        expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at']) : null,
        isActive: json['is_active'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'severity': severity,
        'location_lat': locationLat,
        'location_lng': locationLng,
        'area_name': areaName,
        'description': description,
        'issued_at': issuedAt.toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
        'is_active': isActive,
      };

  // Severity color helper
  static const Map<String, int> severityColors = {
    'low': 0xFF4CAF50,
    'medium': 0xFFFF9800,
    'high': 0xFFF44336,
    'critical': 0xFF9C27B0,
  };

  int get severityColor => severityColors[severity] ?? 0xFF9E9E9E;
}
