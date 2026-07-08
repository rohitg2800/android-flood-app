// Module 6: Relief Camp Model

class ReliefCamp {
  final String id;
  final String name;
  final String? address;
  final String? district;
  final double? latitude;
  final double? longitude;
  final int capacity;
  final int currentOccupancy;
  final bool hasMedical;
  final bool hasFood;
  final bool hasDrinkingWater;
  final bool isActive;
  final String? contactPhone;

  const ReliefCamp({
    required this.id,
    required this.name,
    this.address,
    this.district,
    this.latitude,
    this.longitude,
    required this.capacity,
    this.currentOccupancy = 0,
    this.hasMedical = false,
    this.hasFood = false,
    this.hasDrinkingWater = false,
    this.isActive = true,
    this.contactPhone,
  });

  int get availableSpace => capacity - currentOccupancy;
  double get occupancyPercent => capacity > 0 ? currentOccupancy / capacity : 0;

  factory ReliefCamp.fromJson(Map<String, dynamic> json) {
    return ReliefCamp(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      district: json['district'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      capacity: json['capacity'] as int? ?? 0,
      currentOccupancy: json['current_occupancy'] as int? ?? 0,
      hasMedical: json['has_medical'] as bool? ?? false,
      hasFood: json['has_food'] as bool? ?? false,
      hasDrinkingWater: json['has_drinking_water'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      contactPhone: json['contact_phone'] as String?,
    );
  }
}
