// lib/widgets/map/map_markers.dart
// v2.0 — 5-colour severity system
//
// gaugeRiskFromLevels() / RiverStation.riskLevel emits:
//   'EXTREME'  → above HFL   → magenta  #E040FB
//   'CRITICAL' → above DL    → deep red #D32F2F
//   'DANGER'   → above WL    → orange   #FF6D00
//   'NORMAL'   → below WL    → green    #388E3C
//
// FloodStation.riskLevel (API legacy labels also handled):
//   'SEVERE'   → #FF5500  orange-red
//   'WARNING'  → #FBC02D  amber
//   'HIGH'     → alias for CRITICAL
//   'MODERATE' → alias for WARNING
//   'LOW'      → alias for NORMAL

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/flood_station.dart';
import 'station_coord_seed.dart';

class MapMarkers extends StatefulWidget {
  const MapMarkers({
    super.key,
    required this.stations,
    required this.onStationTap,
  });

  final List<FloodStation> stations;
  final void Function(FloodStation) onStationTap;

  @override
  State<MapMarkers> createState() => _MapMarkersState();
}

class _MapMarkersState extends State<MapMarkers>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  LatLng? _resolveCoord(FloodStation s) {
    if (s.lat != null && s.lon != null) return LatLng(s.lat!, s.lon!);
    return kStationCoords[s.city.toLowerCase().trim()];
  }

  Color _colorFor(String riskLevel) {
    switch (riskLevel.toUpperCase().trim()) {
      case 'EXTREME':            return const Color(0xFFE040FB); // magenta — above HFL
      case 'CRITICAL':
      case 'HIGH':               return const Color(0xFFD32F2F); // deep red — above DL
      case 'DANGER':
      case 'SEVERE':             return const Color(0xFFFF6D00); // orange — above WL
      case 'WARNING':
      case 'MODERATE':           return const Color(0xFFFBC02D); // amber — near WL
      case 'LOW':
      case 'NORMAL':             return const Color(0xFF388E3C); // green — safe
      default:                   return const Color(0xFF757575); // grey — unknown
    }
  }

  double _radiusFor(String riskLevel, double? capacityPercent) {
    if (capacityPercent != null) {
      if (capacityPercent > 100) return 20.0;
      if (capacityPercent >= 85)  return 16.0;
      if (capacityPercent >= 60)  return 13.0;
      return 10.0;
    }
    switch (riskLevel.toUpperCase().trim()) {
      case 'EXTREME':            return 20.0;
      case 'CRITICAL':
      case 'HIGH':               return 16.0;
      case 'DANGER':
      case 'SEVERE':             return 13.0;
      case 'WARNING':
      case 'MODERATE':           return 11.0;
      default:                   return  9.0;
    }
  }

  double _amplitudeFor(String riskLevel) {
    switch (riskLevel.toUpperCase().trim()) {
      case 'EXTREME':            return 4.0;
      case 'CRITICAL':
      case 'HIGH':               return 3.0;
      case 'DANGER':
      case 'SEVERE':             return 2.0;
      case 'WARNING':
      case 'MODERATE':           return 1.0;
      default:                   return 0.0; // no pulse for NORMAL
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];

    for (final station in widget.stations) {
      final coord = _resolveCoord(station);
      if (coord == null) continue;

      final color     = _colorFor(station.riskLevel);
      final radius    = _radiusFor(station.riskLevel, station.capacityPercent);
      final amplitude = _amplitudeFor(station.riskLevel);
      final wh        = (radius + radius * 3.0 + 4) * 2;

      markers.add(
        Marker(
          point:  coord,
          width:  wh,
          height: wh,
          child: GestureDetector(
            onTap: () => widget.onStationTap(station),
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _animation,
                builder: (_, __) => CustomPaint(
                  painter: _PulseMarkerPainter(
                    color:     color,
                    radius:    radius,
                    amplitude: amplitude,
                    animValue: _animation.value,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: MarkerLayer(markers: markers),
    );
  }
}

class _PulseMarkerPainter extends CustomPainter {
  const _PulseMarkerPainter({
    required this.color,
    required this.radius,
    required this.amplitude,
    required this.animValue,
  });

  final Color  color;
  final double radius;
  final double amplitude;
  final double animValue;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 1. Pulse ring
    if (amplitude > 0) {
      final pulseRadius  = radius + (amplitude * radius * animValue);
      final pulseOpacity = (1.0 - animValue) * 0.65;
      canvas.drawCircle(
        center, pulseRadius,
        Paint()
          ..color       = color.withOpacity(pulseOpacity)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    // 2. White border
    canvas.drawCircle(
      center, radius + 1.5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    // 3. Solid fill
    canvas.drawCircle(
      center, radius,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _PulseMarkerPainter old) =>
      old.animValue != animValue ||
      old.color     != color     ||
      old.radius    != radius;
}
