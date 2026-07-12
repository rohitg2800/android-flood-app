// Plain Dart model — no freezed / json_serializable
// Maps to: public.sos_reports

enum SosStatus { pending, acknowledged, responding, resolved, false_alarm }

SosStatus sosStatusFromString(String s) =>
    SosStatus.values.firstWhere((e) => e.name == s,
        orElse: () => SosStatus.pending);

class SosReport {
  final String id;
  final String userId;
  final String? description;
  final double latitude;
  final double longitude;
  final String? address;
  final SosStatus status;
  final int numberOfPeople;
  final bool needsMedical;
  final bool needsBoat;
  final bool needsFood;
  final String? imageUrl;
  final String? assignedTo;
  final String? resolverNotes;
  final DateTime? acknowledgedAt;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SosReport({
    required this.id,
    required this.userId,
    this.description,
    required this.latitude,
    required this.longitude,
    this.address,
    required this.status,
    this.numberOfPeople = 1,
    this.needsMedical = false,
    this.needsBoat = false,
    this.needsFood = false,
    this.imageUrl,
    this.assignedTo,
    this.resolverNotes,
    this.acknowledgedAt,
    this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SosReport.fromJson(Map<String, dynamic> json) => SosReport(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        description: json['description'] as String?,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        address: json['address'] as String?,
        status: sosStatusFromString(json['status'] as String),
        numberOfPeople: json['number_of_people'] as int? ?? 1,
        needsMedical: json['needs_medical'] as bool? ?? false,
        needsBoat: json['needs_boat'] as bool? ?? false,
        needsFood: json['needs_food'] as bool? ?? false,
        imageUrl: json['image_url'] as String?,
        assignedTo: json['assigned_to'] as String?,
        resolverNotes: json['resolver_notes'] as String?,
        acknowledgedAt: json['acknowledged_at'] != null
            ? DateTime.parse(json['acknowledged_at'] as String)
            : null,
        resolvedAt: json['resolved_at'] != null
            ? DateTime.parse(json['resolved_at'] as String)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'status': status.name,
        'number_of_people': numberOfPeople,
        'needs_medical': needsMedical,
        'needs_boat': needsBoat,
        'needs_food': needsFood,
        'image_url': imageUrl,
        'assigned_to': assignedTo,
        'resolver_notes': resolverNotes,
        'acknowledged_at': acknowledgedAt?.toIso8601String(),
        'resolved_at': resolvedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  bool get isActive =>
      status == SosStatus.pending || status == SosStatus.responding;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is SosReport && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SosReport(id: $id, status: ${status.name}, people: $numberOfPeople)';
}
