// File: lib/widgets/map/map_markers.dart
// Updated: June 2026
// Changes: Full rewrite — kStationCoords direct lookup,
//          all FloodStation stations, pulse animation

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/flood_station.dart';
import 'station_coord_seed.dart'; // for kStationCoords map ONLY

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
    )
      ..repeat();
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
    switch (riskLevel) {
      case 'CRITICAL':
        return const Color(0xFFC62828);
      case 'HIGH':
        return const Color(0xFFFF8F00);
      case 'MODERATE':
        return const Color(0xFFF57F17);
      case 'LOW':
        return const Color(0xFF2E7D32);
      default:
        return const Color(0xFF757575);
    }
  }

  double _radiusFor(double? capacityPercent) {
    if (capacityPercent == null || capacityPercent < 50) return 10.0;
    if (capacityPercent <= 85) return 13.0;
    if (capacityPercent <= 100) return 16.0;
    return 20.0;
  }

  double _amplitudeFor(String riskLevel) {
    switch (riskLevel) {
      case 'CRITICAL':
        return 3.0;
      case 'HIGH':
        return 2.0;
      case 'MODERATE':
        return 1.0;
      case 'LOW':
        return 0.5;
      default:
        return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];

    for (final station in widget.stations) {
      final coord = _resolveCoord(station);
      if (coord == null) continue;

      final color = _colorFor(station.riskLevel);
      final radius = _radiusFor(station.capacityPercent);
      final amplitude = _amplitudeFor(station.riskLevel);

      final widthHeight = (radius + radius * 3.0 + 4) * 2;

      markers.add(
        Marker(
          point: coord,
          width: widthHeight,
          height: widthHeight,
          child: GestureDetector(
            onTap: () => widget.onStationTap(station),
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _animation,
                builder: (_, __) => CustomPaint(
                  painter: _PulseMarkerPainter(
                    color: color,
                    radius: radius,
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
  _PulseMarkerPainter({
    required this.color,
    required this.radius,
    required this.amplitude,
    required this.animValue,
  });

  final Color color;
  final double radius;
  final double amplitude;
  final double animValue;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 1. Pulse ring (only if amplitude > 0)
    if (amplitude > 0) {
      final pulseRadius = radius + (amplitude * radius * animValue);
      final pulseOpacity = (1.0 - animValue) * 0.6;

      canvas.drawCircle(
        center,
        pulseRadius,
        Paint()
          ..color = color.withOpacity(pulseOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    // 2. White border
    canvas.drawCircle(
      center,
      radius + 1.5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // 3. Solid dot
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _PulseMarkerPainter old) =>
      old.animValue != animValue || old.color != color;
}

