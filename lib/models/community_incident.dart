class CommunityIncident {
  final String id;
  final IncidentType type;
  final String headline;
  final String description;
  final double lat;
  final double lng;
  final String district;
  final DateTime reportedAt;
  final String submittedBy;
  final List<String> photoUrls;
  bool verified;
  int upvotes;
  bool synced;

  CommunityIncident({
    required this.id,
    required this.type,
    required this.headline,
    required this.description,
    required this.lat,
    required this.lng,
    required this.district,
    required this.reportedAt,
    required this.submittedBy,
    required this.photoUrls,
    this.verified = false,
    this.upvotes = 0,
    this.synced = false,
  });

  String? get imagePath => photoUrls.isNotEmpty ? photoUrls.first : null;

  Future<void> save() async {}

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'headline': headline,
        'description': description,
        'lat': lat,
        'lng': lng,
        'district': district,
        'reported_at': reportedAt.toIso8601String(),
        'submitted_by': submittedBy,
        'photo_urls': photoUrls,
        'verified': verified,
        'upvotes': upvotes,
        'synced': synced,
      };

  factory CommunityIncident.fromJson(Map<String, dynamic> j) =>
      CommunityIncident(
        id: j['id'] as String,
        type: IncidentType.values.firstWhere(
          (e) => e.name == j['type'],
          orElse: () => IncidentType.other,
        ),
        headline: j['headline'] as String,
        description: j['description'] as String,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        district: j['district'] as String,
        reportedAt: DateTime.parse(j['reported_at'] as String),
        submittedBy: j['submitted_by'] as String,
        photoUrls: (j['photo_urls'] as List?)?.cast<String>() ?? const [],
        verified: j['verified'] as bool? ?? false,
        upvotes: j['upvotes'] as int? ?? 0,
        synced: j['synced'] as bool? ?? false,
      );
}

enum IncidentType {
  flooding,
  embankmentBreach,
  roadBlocked,
  waterlogging,
  evacuationNeeded,
  rescueNeeded,
  infrastructureDamage,
  other,
}

extension IncidentTypeLabel on IncidentType {
  String get label {
    switch (this) {
      case IncidentType.flooding:
        return 'Flooding';
      case IncidentType.embankmentBreach:
        return 'Embankment Breach';
      case IncidentType.roadBlocked:
        return 'Road Blocked';
      case IncidentType.waterlogging:
        return 'Waterlogging';
      case IncidentType.evacuationNeeded:
        return 'Evacuation Needed';
      case IncidentType.rescueNeeded:
        return 'Rescue Needed';
      case IncidentType.infrastructureDamage:
        return 'Infrastructure Damage';
      case IncidentType.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case IncidentType.flooding:
        return '🚨';
      case IncidentType.embankmentBreach:
        return '🚧';
      case IncidentType.roadBlocked:
        return '🚫';
      case IncidentType.waterlogging:
        return '💧';
      case IncidentType.evacuationNeeded:
        return '🏎️';
      case IncidentType.rescueNeeded:
        return '🚑';
      case IncidentType.infrastructureDamage:
        return '🏗️';
      case IncidentType.other:
        return 'ℹ️';
    }
  }

  String get emoji => icon;
}
