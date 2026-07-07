class AlertModel {
  final String id;
  final String title;
  final String severity; // low | medium | high | critical
  final double locationLat;
  final double locationLng;
  final String areaName;
  final String description;
  final DateTime issuedAt;
  final DateTime? expiresAt;
  final bool isActive;

  AlertModel({
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

  factory AlertModel.fromJson(Map<String, dynamic> json) => AlertModel(
    id: json['id'],
    title: json['title'],
    severity: json['severity'],
    locationLat: json['location_lat'],
    locationLng: json['location_lng'],
    areaName: json['area_name'],
    description: json['description'],
    issuedAt: DateTime.parse(json['issued_at']),
    expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at']) : null,
    isActive: json['is_active'] ?? true,
  );
}
