// Module 5: Incident Model

enum IncidentStatus { open, assigned, inProgress, resolved }
enum IncidentPriority { low, medium, high, critical }

class Incident {
  final String id;
  final String? reportedBy;
  final String? assignedTo;
  final String title;
  final String? description;
  final IncidentStatus status;
  final IncidentPriority priority;
  final double? latitude;
  final double? longitude;
  final String? address;
  final List<String> imageUrls;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;

  const Incident({
    required this.id,
    this.reportedBy,
    this.assignedTo,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    this.latitude,
    this.longitude,
    this.address,
    this.imageUrls = const [],
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
  });

  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
      id: json['id'] as String,
      reportedBy: json['reported_by'] as String?,
      assignedTo: json['assigned_to'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: IncidentStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String).replaceAll('_', ''),
        orElse: () => IncidentStatus.open,
      ),
      priority: IncidentPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => IncidentPriority.medium,
      ),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      address: json['address'] as String?,
      imageUrls: List<String>.from(json['image_urls'] as List? ?? []),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
    );
  }
}
