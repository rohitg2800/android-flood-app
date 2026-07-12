// lib/models/river_monitoring.dart
import '../models/flood_data.dart';

class RiverLevelSnapshot {
  final double level;
  final DateTime timestamp;

  const RiverLevelSnapshot({required this.level, required this.timestamp});

  factory RiverLevelSnapshot.fromJson(Map<String, dynamic> j) {
    double d(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    return RiverLevelSnapshot(
      level: d(j['level'] ?? j['river_level'] ?? j['water_level']),
      timestamp: j['timestamp'] != null
          ? DateTime.tryParse(j['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'level': level,
        'timestamp': timestamp.toIso8601String(),
      };

  @override
  String toString() =>
      'RiverLevelSnapshot(${level}m @ ${timestamp.toIso8601String()})';
}

/// Thin wrapper returned by LiveFetchEngine.monitoringData.
class MultiLocationMonitoring {
  final List<FloodData> locations;
  final DateTime? lastUpdated;

  const MultiLocationMonitoring({
    required this.locations,
    this.lastUpdated,
  });

  int get totalLocations => locations.length;
  int get criticalCount =>
      locations.where((l) => l.riskLevel == 'CRITICAL').length;
  int get severeCount => locations.where((l) => l.riskLevel == 'SEVERE').length;
  int get moderateCount =>
      locations.where((l) => l.riskLevel == 'MODERATE').length;
  bool get hasCritical => criticalCount > 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// ImdAlert — IMD weather alert for a state/district.
// ─────────────────────────────────────────────────────────────────────────────
class ImdAlert {
  final String headline;
  final String description;
  final String severity; // RED | ORANGE | YELLOW | GREEN
  final String state;
  final String district;
  final DateTime? issuedAt;

  const ImdAlert({
    required this.headline,
    this.description = '',
    required this.severity,
    this.state = '',
    this.district = '',
    this.issuedAt,
  });

  factory ImdAlert.fromJson(Map<String, dynamic> j) => ImdAlert(
        headline: (j['headline'] as String?) ?? '',
        description: (j['description'] as String?) ?? '',
        severity: (j['severity'] as String?) ?? 'GREEN',
        state: (j['state'] as String?) ?? '',
        district: (j['district'] as String?) ?? '',
        issuedAt: j['issued_at'] != null
            ? DateTime.tryParse(j['issued_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'headline': headline,
        'description': description,
        'severity': severity,
        'state': state,
        'district': district,
        if (issuedAt != null) 'issued_at': issuedAt!.toIso8601String(),
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// NdmaAdvisory — NDMA advisory for a state.
// ─────────────────────────────────────────────────────────────────────────────
class NdmaAdvisory {
  final String title;
  final String body;
  final String state;
  final DateTime? issuedAt;

  const NdmaAdvisory({
    required this.title,
    this.body = '',
    this.state = '',
    this.issuedAt,
  });

  factory NdmaAdvisory.fromJson(Map<String, dynamic> j) => NdmaAdvisory(
        title: (j['title'] as String?) ?? '',
        body: (j['body'] as String?) ?? '',
        state: (j['state'] as String?) ?? '',
        issuedAt: j['issued_at'] != null
            ? DateTime.tryParse(j['issued_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
        'state': state,
        if (issuedAt != null) 'issued_at': issuedAt!.toIso8601String(),
      };
}
