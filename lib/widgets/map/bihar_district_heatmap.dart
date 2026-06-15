// lib/widgets/map/bihar_district_heatmap.dart
// Adds the missing `visible` parameter that BiharRiverMapScreen passes.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/river_station.dart';

class BiharDistrictHeatmap extends StatelessWidget {
  final List<RiverStation> stations;
  final MapController?     mapController;
  final bool               visible;

  const BiharDistrictHeatmap({
    super.key,
    this.stations     = const [],
    this.mapController,
    this.visible      = true,        // ← was missing — fixes the compile error
  });

  @override
  Widget build(BuildContext context) {
    if (!visible || stations.isEmpty) return const SizedBox.shrink();

    return PolygonLayer(
      polygons: _biharDistricts.entries.map((entry) {
        final district = entry.key;
        final bbox     = entry.value; // [minLat, minLon, maxLat, maxLon]
        final color    = _districtColor(district, stations);
        return Polygon(
          points: [
            LatLng(bbox[0], bbox[1]),
            LatLng(bbox[0], bbox[3]),
            LatLng(bbox[2], bbox[3]),
            LatLng(bbox[2], bbox[1]),
          ],
          color:       color.withValues(alpha: 0.28),
          borderColor: color.withValues(alpha: 0.55),
          borderStrokeWidth: 1.2,
        );
      }).toList(),
    );
  }

  Color _districtColor(String district, List<RiverStation> stations) {
    final match = stations
        .where((s) => s.district.toLowerCase() == district.toLowerCase())
        .toList();
    if (match.isEmpty) return Colors.blueGrey;
    final worst = match.reduce((a, b) =>
        _riskOrder(a.riskLevel) < _riskOrder(b.riskLevel) ? a : b);
    return _levelColor(worst.riskLevel);
  }

  static int _riskOrder(String r) {
    switch (r.toUpperCase()) {
      case 'CRITICAL': return 0;
      case 'SEVERE':   return 1;
      case 'HIGH':     return 2;
      case 'MODERATE': return 3;
      default:         return 4;
    }
  }

  static Color _levelColor(String r) {
    switch (r.toUpperCase()) {
      case 'CRITICAL': return const Color(0xFFE53935);
      case 'SEVERE':   return const Color(0xFFF57C00);
      case 'HIGH':     return const Color(0xFFFDD835);
      case 'MODERATE': return const Color(0xFF29B6F6);
      default:         return const Color(0xFF43A047);
    }
  }

  // ── Bihar district bounding boxes [minLat, minLon, maxLat, maxLon] ──────
  static const _biharDistricts = <String, List<double>>{
    'Patna':        [25.35, 84.80, 25.75, 85.45],
    'Muzaffarpur':  [25.95, 84.80, 26.45, 85.50],
    'Bhagalpur':    [25.00, 86.70, 25.50, 87.40],
    'Gaya':         [24.40, 84.60, 25.00, 85.20],
    'Darbhanga':    [25.90, 85.50, 26.30, 86.20],
    'Samastipur':   [25.70, 85.50, 26.10, 86.10],
    'Madhubani':    [26.10, 85.80, 26.70, 86.50],
    'Sitamarhi':    [26.40, 85.30, 26.90, 85.90],
    'Saran':        [25.70, 84.50, 26.10, 85.10],
    'Vaishali':     [25.60, 85.10, 26.00, 85.60],
    'East Champaran': [26.50, 84.60, 27.10, 85.40],
    'West Champaran': [26.70, 83.80, 27.40, 84.70],
    'Siwan':        [25.90, 83.90, 26.40, 84.60],
    'Gopalganj':    [26.20, 83.90, 26.80, 84.60],
    'Rohtas':       [24.40, 83.50, 25.10, 84.30],
    'Kaimur':       [24.80, 83.10, 25.40, 83.80],
    'Aurangabad':   [24.50, 84.00, 24.90, 84.80],
    'Nawada':       [24.60, 85.40, 25.10, 86.00],
    'Nalanda':      [25.00, 85.30, 25.40, 86.00],
    'Sheikhpura':   [25.10, 85.80, 25.50, 86.30],
    'Lakhisarai':   [25.10, 85.90, 25.50, 86.40],
    'Jamui':        [24.60, 85.90, 25.20, 86.60],
    'Banka':        [24.70, 86.70, 25.20, 87.30],
    'Munger':       [25.20, 86.30, 25.60, 86.80],
    'Begusarai':    [25.30, 85.80, 25.80, 86.50],
    'Khagaria':     [25.40, 86.30, 25.80, 87.00],
    'Supaul':       [25.90, 86.30, 26.60, 87.10],
    'Araria':       [26.00, 87.20, 26.60, 87.90],
    'Kishanganj':   [25.90, 87.70, 26.50, 88.20],
    'Purnia':       [25.50, 87.20, 26.10, 87.90],
    'Katihar':      [25.30, 87.30, 25.90, 88.00],
    'Madhepura':    [25.60, 86.70, 26.10, 87.30],
    'Saharsa':      [25.60, 86.40, 26.00, 87.00],
    'Sheohar':      [26.30, 85.20, 26.70, 85.60],
    'Bhojpur':      [25.30, 84.20, 25.70, 84.90],
    'Buxar':        [25.40, 83.70, 25.80, 84.40],
    'Jehanabad':    [25.10, 84.80, 25.50, 85.30],
    'Arwal':        [25.10, 84.50, 25.40, 85.00],
  };
}
