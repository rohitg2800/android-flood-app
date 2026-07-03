// lib/models/community_incident.dart
import 'package:hive/hive.dart';

part 'community_incident.g.dart';

@HiveType(typeId: 30)
enum IncidentType {
  @HiveField(0)
  flooding,
  @HiveField(1)
  embankmentBreach,
  @HiveField(2)
  roadBlocked,
  @HiveField(3)
  waterlogging,
  @HiveField(4)
  evacuationNeeded,
  @HiveField(5)
  rescueNeeded,
  @HiveField(6)
  infrastructureDamage,
  @HiveField(7)
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

@HiveType(typeId: 31)
class CommunityIncident extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final IncidentType type;
  @HiveField(2)
  final String headline;
  @HiveField(3)
  final String description;
  @HiveField(4)
  final double lat;
  @HiveField(5)
  final double lng;
  @HiveField(6)
  final String district;
  @HiveField(7)
  final DateTime reportedAt;
  @HiveField(8)
  final String submittedBy;
  @HiveField(9)
  final List<String> photoUrls;
  @HiveField(10)
  bool verified; // moderator-verified flag
  @HiveField(11)
  int upvotes; // community upvote count

  /// Transient (not persisted to Hive) — tracks whether this incident
  /// has been successfully synced to Firestore. Set by IncidentSyncService.
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

  /// First photo URL, or null if no photos attached.
  String? get imagePath => photoUrls.isNotEmpty ? photoUrls.first : null;

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
        type: IncidentType.values.byName(j['type'] as String? ?? 'other'),
        headline: j['headline'] as String? ?? '',
        description: j['description'] as String? ?? '',
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        district: j['district'] as String? ?? '',
        reportedAt: DateTime.parse(j['reported_at'] as String),
        submittedBy: j['submitted_by'] as String? ?? '',
        photoUrls: List<String>.from(j['photo_urls'] as List? ?? []),
        verified: j['verified'] as bool? ?? false,
        upvotes: j['upvotes'] as int? ?? 0,
        synced: j['synced'] as bool? ?? false,
      );
}
