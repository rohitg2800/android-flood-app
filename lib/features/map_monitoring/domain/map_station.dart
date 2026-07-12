import 'package:flutter/material.dart';

enum MapStationSeverity { critical, severe, warning, normal, noData }

class MapStation {
  final String id;
  final String name;
  final String river;
  final double lat;
  final double lon;
  final double current;
  final double warning;
  final double danger;
  final MapStationSeverity severity;

  const MapStation({
    required this.id,
    required this.name,
    required this.river,
    required this.lat,
    required this.lon,
    required this.current,
    required this.warning,
    required this.danger,
    required this.severity,
  });

  Color get severityColor {
    switch (severity) {
      case MapStationSeverity.critical:
        return const Color(0xFFFF4D5A);
      case MapStationSeverity.severe:
        return const Color(0xFFFF8C42);
      case MapStationSeverity.warning:
        return const Color(0xFFFFC857);
      case MapStationSeverity.normal:
        return const Color(0xFF3ACC8A);
      case MapStationSeverity.noData:
        return const Color(0xFF7A8290);
    }
  }

  String get severityLabel {
    switch (severity) {
      case MapStationSeverity.critical:
        return 'CRITICAL';
      case MapStationSeverity.severe:
        return 'SEVERE';
      case MapStationSeverity.warning:
        return 'WARNING';
      case MapStationSeverity.normal:
        return 'NORMAL';
      case MapStationSeverity.noData:
        return 'NO DATA';
    }
  }

  double get fillRatio {
    if (danger <= 0) return 0;
    return (current / danger).clamp(0.0, 1.0);
  }
}
