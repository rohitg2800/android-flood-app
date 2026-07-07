class FloodZoneModel {
  final String id;
  final String zoneName;
  final String riskLevel;
  final List<Map<String, double>> polygonCoordinates; // GeoJSON
  final DateTime lastUpdated;

  FloodZoneModel({
    required this.id,
    required this.zoneName,
    required this.riskLevel,
    required this.polygonCoordinates,
    required this.lastUpdated,
  });
}
