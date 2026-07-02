import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';

// ── Model ──────────────────────────────────────────────────────────────────

class PumpStation {
  final String id;
  final String name;
  final String location;
  final double latitude;
  final double longitude;
  final String status; // 'operational' | 'maintenance' | 'critical' | 'offline'
  final double capacityPercent;
  final String? lastMaintenance;
  final String? nextMaintenance;
  final String? district;
  final String? contactNumber;

  const PumpStation({
    required this.id,
    required this.name,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.capacityPercent,
    this.lastMaintenance,
    this.nextMaintenance,
    this.district,
    this.contactNumber,
  });

  factory PumpStation.fromJson(Map<String, dynamic> json) => PumpStation(
        id: json['id']?.toString() ?? '',
        name: json['name'] ?? '',
        location: json['location'] ?? '',
        latitude: (json['latitude'] ?? 0).toDouble(),
        longitude: (json['longitude'] ?? 0).toDouble(),
        status: json['status'] ?? 'offline',
        capacityPercent: (json['capacity_percent'] ?? 0).toDouble(),
        lastMaintenance: json['last_maintenance'],
        nextMaintenance: json['next_maintenance'],
        district: json['district'],
        contactNumber: json['contact_number'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'status': status,
        'capacity_percent': capacityPercent,
        'last_maintenance': lastMaintenance,
        'next_maintenance': nextMaintenance,
        'district': district,
        'contact_number': contactNumber,
      };
}

class IssueReport {
  final String stationId;
  final String issueType;
  final String description;
  final String severity; // 'low' | 'medium' | 'high' | 'critical'
  final String? reporterName;
  final String? contactNumber;

  const IssueReport({
    required this.stationId,
    required this.issueType,
    required this.description,
    required this.severity,
    this.reporterName,
    this.contactNumber,
  });

  Map<String, dynamic> toJson() => {
        'station_id': stationId,
        'issue_type': issueType,
        'description': description,
        'severity': severity,
        'reporter_name': reporterName,
        'contact_number': contactNumber,
      };
}

// ── Repository ─────────────────────────────────────────────────────────────

final pumpStationRepositoryProvider = Provider<PumpStationRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return PumpStationRepository(client);
});

class PumpStationRepository {
  final ApiClient _client;
  PumpStationRepository(this._client);

  Future<List<PumpStation>> getAllStations({
    String? district,
    String? status,
    String? search,
  }) async {
    final queryParams = <String, dynamic>{};
    if (district != null) queryParams['district'] = district;
    if (status != null) queryParams['status'] = status;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final data = await _client.get(
      ApiEndpoints.pumpStations,
      queryParameters: queryParams,
    );

    final List<dynamic> list = data is List ? data : data['items'] ?? [];
    return list
        .map((e) => PumpStation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PumpStation> getStationById(String id) async {
    final data = await _client.get(ApiEndpoints.pumpStationById(id));
    return PumpStation.fromJson(data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getStationStatus(String id) async {
    final data = await _client.get(ApiEndpoints.pumpStationStatus(id));
    return data as Map<String, dynamic>;
  }

  Future<bool> reportIssue(IssueReport report) async {
    await _client.post(
      ApiEndpoints.reportPumpIssue(report.stationId),
      data: report.toJson(),
    );
    return true;
  }
}
