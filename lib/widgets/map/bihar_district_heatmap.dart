// lib/widgets/map/bihar_district_heatmap.dart
// Uses riskLabel getter (via RiverStation.riskLabel) and city as district proxy.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../models/river_station.dart';

class BiharDistrictHeatmap extends StatelessWidget {
  final List<RiverStation>? stations;
  final MapController?      mapController;
  final bool                visible;

  const BiharDistrictHeatmap({
    super.key,
    this.stations,
    this.mapController,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible || stations == null || stations!.isEmpty) {
      return const SizedBox.shrink();
    }
    return _HeatmapLayer(stations: stations!, mapController: mapController);
  }
}

class _HeatmapLayer extends StatelessWidget {
  final List<RiverStation> stations;
  final MapController?     mapController;
  const _HeatmapLayer({required this.stations, this.mapController});

  /// Find the worst-risk station for a given district name.
  /// RiverStation has no .district field — we use .city as the district proxy
  /// (consistent with how city/district are populated from CWC data).
  RiverStation? _worstForDistrict(String district) {
    final matching = stations
        .where((s) => s.city.toLowerCase() == district.toLowerCase())
        .toList();
    if (matching.isEmpty) return null;
    return matching.reduce(
        (a, b) => _riskOrder(a.riskLabel) < _riskOrder(b.riskLabel) ? a : b);
  }

  int _riskOrder(String label) {
    switch (label.toUpperCase()) {
      case 'EXTREME':  return 0;
      case 'CRITICAL': return 1;
      case 'DANGER':   return 2;
      case 'HIGH':     return 3;
      case 'WARNING':  return 4;
      case 'MODERATE': return 5;
      default:         return 6;
    }
  }

  Color _levelColor(String label) {
    switch (label.toUpperCase()) {
      case 'EXTREME':  return const Color(0xFFAA00FF);
      case 'CRITICAL': return const Color(0xFFFF1A44);
      case 'DANGER':   return const Color(0xFFFF5500);
      case 'HIGH':     return const Color(0xFFFFA520);
      case 'WARNING':  return const Color(0xFFFFD700);
      case 'MODERATE': return const Color(0xFF10E88A);
      default:         return const Color(0xFF1E3A5F);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Derive unique district names from station.city
    final districts = stations.map((s) => s.city).toSet();
    return Stack(
      children: districts.map((district) {
        final worst = _worstForDistrict(district);
        if (worst == null) return const SizedBox.shrink();
        final color = _levelColor(worst.riskLabel);
        // Render as a coloured circle at station position
        if (worst.lat == null || worst.lon == null) return const SizedBox.shrink();
        return Positioned(
          // Positioning is handled by flutter_map — this is a placeholder layout.
          // In production wire via FlutterMap CircleLayer.
          child: Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.5),
              shape: BoxShape.circle,
              border: Border.all(color: color),
            ),
          ),
        );
      }).toList(),
    );
  }
}
