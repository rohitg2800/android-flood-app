class FloodAlert {
  final String id;
  final String title;
  final String severity; // low, medium, high, critical
  final double locationLat;
  final double locationLng;
  final String areaName;
  final String description;
  final DateTime issuedAt;
  final DateTime? expiresAt;
  final bool isActive;

  FloodAlert({
    required this.id,
    required this.title,
    required this.severity,
    required this.locationLat,
    required this.locationLng,
    required this.areaName,
    required this.description,
    required this.issuedAt,
    this.expiresAt,
    this.isActive = true,
  });

  factory FloodAlert.fromJson(Map<String, dynamic> json) => FloodAlert(
    id: json['id'],
    title: json['title'],
    severity: json['severity'],
    locationLat: double.parse(json['location_lat'].toString()),
    locationLng: double.parse(json['location_lng'].toString()),
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

  Color get severityColor {
    switch (severity) {
      case 'critical': return const Color(0xFFFF0000);
      case 'high':     return const Color(0xFFFF6B00);
      case 'medium':   return const Color(0xFFFFD700);
      default:         return const Color(0xFF00C853);
    }
  }
}
