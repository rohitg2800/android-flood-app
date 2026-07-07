class IncidentModel {
  final String id;
  final String reportedBy;
  final String? assignedTo;
  final String title;
  final String description;
  final String status; // open | assigned | in_progress | resolved
  final double latitude;
  final double longitude;
  final List<String> imageUrls;
  final DateTime createdAt;
  final DateTime updatedAt;

  IncidentModel({
    required this.id,
    required this.reportedBy,
    this.assignedTo,
    required this.title,
    required this.description,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.imageUrls,
    required this.createdAt,
    required this.updatedAt,
  });

  factory IncidentModel.fromJson(Map<String, dynamic> json) => IncidentModel(
    id: json['id'],
    reportedBy: json['reported_by'],
    assignedTo: json['assigned_to'],
    title: json['title'],
    description: json['description'],
    status: json['status'],
    latitude: json['latitude'],
    longitude: json['longitude'],
    imageUrls: List<String>.from(json['image_urls'] ?? []),
    createdAt: DateTime.parse(json['created_at']),
    updatedAt: DateTime.parse(json['updated_at']),
  );
}
