// Geofencing Service
// Triggers alert when user enters a flood zone polygon

class GeofenceService {
  // TODO: Use geolocator + geofencing package
  // TODO: Load active flood zones from Neon
  // TODO: Check if user lat/lng is inside any polygon
  // TODO: Trigger notification if inside danger zone

  bool isInsidePolygon(double lat, double lng, List<Map<String, double>> polygon) {
    // Ray-casting algorithm
    int intersections = 0;
    for (int i = 0; i < polygon.length; i++) {
      final p1 = polygon[i];
      final p2 = polygon[(i + 1) % polygon.length];
      if ((p1['lat']! <= lat && lat < p2['lat']!) ||
          (p2['lat']! <= lat && lat < p1['lat']!)) {
        final xIntersect = (lat - p1['lat']!) / (p2['lat']! - p1['lat']!) *
            (p2['lng']! - p1['lng']!) + p1['lng']!;
        if (lng < xIntersect) intersections++;
      }
    }
    return intersections % 2 != 0;
  }
}
