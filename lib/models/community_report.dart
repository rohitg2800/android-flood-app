// lib/models/community_report.dart
// Phase 4 — Community & Crowd Reporting Accessibility
// Represents a user-submitted flood/hazard report from the community

enum ReportSeverity { low, medium, high, emergency }

enum ReportCategory {
  flooding,
  roadBlocked,
  bridgeDamage,
  powerOutage,
  rescueNeeded,
  shelterAvailable,
  other,
}

class CommunityReport {
  final String? id;
  final String userId;
  final String? userName;
  final String district;
  final String? subDistrict;
  final double latitude;
  final double longitude;
  final ReportCategory category;
  final ReportSeverity severity;
  final String description;
  final String? photoUrl;
  final DateTime reportedAt;
  final bool isVerified;
  final int upvotes;

  const CommunityReport({
    this.id,
    required this.userId,
    this.userName,
    required this.district,
    this.subDistrict,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.severity,
    required this.description,
    this.photoUrl,
    required this.reportedAt,
    this.isVerified = false,
    this.upvotes = 0,
  });

  factory CommunityReport.fromJson(Map<String, dynamic> json) {
    return CommunityReport(
      id: json['id']?.toString(),
      userId: json['user_id']?.toString() ?? '',
      userName: json['user_name']?.toString(),
      district: json['district']?.toString() ?? '',
      subDistrict: json['sub_district']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      category: ReportCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => ReportCategory.other,
      ),
      severity: ReportSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
        orElse: () => ReportSeverity.low,
      ),
      description: json['description']?.toString() ?? '',
      photoUrl: json['photo_url']?.toString(),
      reportedAt: json['reported_at'] != null
          ? DateTime.tryParse(json['reported_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isVerified: json['is_verified'] as bool? ?? false,
      upvotes: json['upvotes'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      if (userName != null) 'user_name': userName,
      'district': district,
      if (subDistrict != null) 'sub_district': subDistrict,
      'latitude': latitude,
      'longitude': longitude,
      'category': category.name,
      'severity': severity.name,
      'description': description,
      if (photoUrl != null) 'photo_url': photoUrl,
      'reported_at': reportedAt.toIso8601String(),
      'is_verified': isVerified,
      'upvotes': upvotes,
    };
  }

  CommunityReport copyWith({
    String? id,
    String? userId,
    String? userName,
    String? district,
    String? subDistrict,
    double? latitude,
    double? longitude,
    ReportCategory? category,
    ReportSeverity? severity,
    String? description,
    String? photoUrl,
    DateTime? reportedAt,
    bool? isVerified,
    int? upvotes,
  }) {
    return CommunityReport(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      district: district ?? this.district,
      subDistrict: subDistrict ?? this.subDistrict,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      description: description ?? this.description,
      photoUrl: photoUrl ?? this.photoUrl,
      reportedAt: reportedAt ?? this.reportedAt,
      isVerified: isVerified ?? this.isVerified,
      upvotes: upvotes ?? this.upvotes,
    );
  }

  /// Human-readable severity label for TTS and accessibility
  String get severityLabel {
    switch (severity) {
      case ReportSeverity.low:
        return 'Low Severity';
      case ReportSeverity.medium:
        return 'Medium Severity';
      case ReportSeverity.high:
        return 'High Severity';
      case ReportSeverity.emergency:
        return 'EMERGENCY';
    }
  }

  /// Human-readable category label
  String get categoryLabel {
    switch (category) {
      case ReportCategory.flooding:
        return 'Flooding';
      case ReportCategory.roadBlocked:
        return 'Road Blocked';
      case ReportCategory.bridgeDamage:
        return 'Bridge Damage';
      case ReportCategory.powerOutage:
        return 'Power Outage';
      case ReportCategory.rescueNeeded:
        return 'Rescue Needed';
      case ReportCategory.shelterAvailable:
        return 'Shelter Available';
      case ReportCategory.other:
        return 'Other';
    }
  }

  /// Full TTS-ready announcement string for screen readers
  String get accessibilityAnnouncement {
    return '$severityLabel report in $district. '
        'Category: $categoryLabel. '
        '$description. '
        'Reported ${_timeAgo(reportedAt)}.';
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }
}
