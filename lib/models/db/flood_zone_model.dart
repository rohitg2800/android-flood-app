// Plain Dart model — no freezed / json_serializable
// Maps to: public.flood_zones

enum RiskLevel { low, medium, high, very_high, extreme }

RiskLevel riskLevelFromString(String s) =>
    RiskLevel.values.firstWhere((e) => e.name == s,
        orElse: () => RiskLevel.low);

class FloodZone {
  final String id;
  final String name;
  final RiskLevel riskLevel;
  final String? district;
  final String? state;
  final double? centerLatitude;
  final double? centerLongitude;
  final double? areaKm2;
  final int? populationAtRisk;
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FloodZone({
    required this.id,
    required this.name,
    required this.riskLevel,
    this.district,
    this.state,
    this.centerLatitude,
    this.centerLongitude,
    this.areaKm2,
    this.populationAtRisk,
    this.description,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FloodZone.fromJson(Map<String, dynamic> json) => FloodZone(
        id: json['id'] as String,
        name: json['name'] as String,
        riskLevel: riskLevelFromString(json['risk_level'] as String),
        district: json['district'] as String?,
        state: json['state'] as String?,
        centerLatitude: (json['center_latitude'] as num?)?.toDouble(),
        centerLongitude: (json['center_longitude'] as num?)?.toDouble(),
        areaKm2: (json['area_km2'] as num?)?.toDouble(),
        populationAtRisk: json['population_at_risk'] as int?,
        description: json['description'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'risk_level': riskLevel.name,
        'district': district,
        'state': state,
        'center_latitude': centerLatitude,
        'center_longitude': centerLongitude,
        'area_km2': areaKm2,
        'population_at_risk': populationAtRisk,
        'description': description,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is FloodZone && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
