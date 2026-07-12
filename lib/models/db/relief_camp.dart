// Plain Dart model — no freezed / json_serializable
// Maps to: public.relief_camps
// Bonus computed getters: occupancyPercent, isFull

enum CampStatus { active, inactive, full, closed }

CampStatus campStatusFromString(String s) =>
    CampStatus.values.firstWhere((e) => e.name == s,
        orElse: () => CampStatus.inactive);

class ReliefCamp {
  final String id;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final String? district;
  final String? state;
  final int capacity;
  final int currentOccupancy;
  final CampStatus status;
  final bool hasMedical;
  final bool hasFood;
  final bool hasWater;
  final bool hasShelter;
  final String? contactPhone;
  final String? managedBy;
  final DateTime? openedAt;
  final DateTime? closedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReliefCamp({
    required this.id,
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    this.district,
    this.state,
    required this.capacity,
    this.currentOccupancy = 0,
    required this.status,
    this.hasMedical = false,
    this.hasFood = false,
    this.hasWater = false,
    this.hasShelter = false,
    this.contactPhone,
    this.managedBy,
    this.openedAt,
    this.closedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Occupancy percentage (0.0 – 100.0)
  double get occupancyPercent =>
      capacity > 0 ? (currentOccupancy / capacity * 100).clamp(0.0, 100.0) : 0;

  /// True when camp has no remaining capacity
  bool get isFull => currentOccupancy >= capacity;

  factory ReliefCamp.fromJson(Map<String, dynamic> json) => ReliefCamp(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String?,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        district: json['district'] as String?,
        state: json['state'] as String?,
        capacity: json['capacity'] as int,
        currentOccupancy: json['current_occupancy'] as int? ?? 0,
        status: campStatusFromString(json['status'] as String),
        hasMedical: json['has_medical'] as bool? ?? false,
        hasFood: json['has_food'] as bool? ?? false,
        hasWater: json['has_water'] as bool? ?? false,
        hasShelter: json['has_shelter'] as bool? ?? false,
        contactPhone: json['contact_phone'] as String?,
        managedBy: json['managed_by'] as String?,
        openedAt: json['opened_at'] != null
            ? DateTime.parse(json['opened_at'] as String)
            : null,
        closedAt: json['closed_at'] != null
            ? DateTime.parse(json['closed_at'] as String)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'district': district,
        'state': state,
        'capacity': capacity,
        'current_occupancy': currentOccupancy,
        'status': status.name,
        'has_medical': hasMedical,
        'has_food': hasFood,
        'has_water': hasWater,
        'has_shelter': hasShelter,
        'contact_phone': contactPhone,
        'managed_by': managedBy,
        'opened_at': openedAt?.toIso8601String(),
        'closed_at': closedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ReliefCamp && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ReliefCamp(id: $id, name: $name, occupancy: $currentOccupancy/$capacity)';
}
