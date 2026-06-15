// lib/widgets/map/bihar_district_heatmap.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/alert_engine.dart';
import '../../models/river_station.dart';
import '../../theme/app_palette.dart';
import '../../theme/river_colors.dart';
import '../../providers/merged_stations_provider.dart';
import 'district_bottom_sheet.dart';
import '../../constants/india_geodata.dart';

class BiharDistrictHeatmap extends ConsumerStatefulWidget {
  const BiharDistrictHeatmap({super.key});
  @override
  ConsumerState<BiharDistrictHeatmap> createState() =>
      _BiharDistrictHeatmapState();
}

class _BiharDistrictHeatmapState
    extends ConsumerState<BiharDistrictHeatmap> {
  @override
  Widget build(BuildContext context) {
    final stations = ref.watch(mergedStationsProvider);
    final t        = RiverColors.of(context);

    // Group stations by district (city field)
    final Map<String, List<RiverStation>> byDistrict = {};
    for (final s in stations) {
      byDistrict.putIfAbsent(s.city, () => []).add(s);
    }

    return FlutterMap(
      options: const MapOptions(
        initialCenter: LatLng(25.5, 85.1),
        initialZoom: 7,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.opsflood.app',
        ),
        // District polygon overlays
        PolygonLayer(
          polygons: byDistrict.entries.map((entry) {
            final sev    = _worstSeverity(entry.value);
            final isDanger = sev == AlertSeverity.emergency ||
                             sev == AlertSeverity.critical;
            return Polygon(
              points: _districtPolygon(entry.key),
              color:        _severityFill(sev),
              borderColor:  _severityBorder(sev),
              borderStrokeWidth: isDanger ? 2.5 : 1.0,
            );
          }).toList(),
        ),
        // Station markers
        MarkerLayer(
          markers: stations.map((s) {
            final sev = _stationSeverity(s);
            final col = _severityBorder(sev);
            return Marker(
              point: LatLng(s.lat, s.lon),
              width: 20,
              height: 20,
              child: GestureDetector(
                onTap: () => _showSheet(context, s.city, byDistrict[s.city] ?? [s]),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: col.withValues(alpha: 0.85),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showSheet(
      BuildContext context, String district, List<RiverStation> stations) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          DistrictBottomSheet(district: district, stations: stations),
    );
  }
}

/// Returns a simple bounding-box polygon for a district from geodata.
List<LatLng> _districtPolygon(String district) {
  final entry = kBiharDistrictCentroids[district];
  if (entry == null) return [];
  final lat = entry.latitude;
  final lon = entry.longitude;
  const d = 0.25;
  return [
    LatLng(lat + d, lon - d),
    LatLng(lat + d, lon + d),
    LatLng(lat - d, lon + d),
    LatLng(lat - d, lon - d),
  ];
}

AlertSeverity _worstSeverity(List<RiverStation> stations) {
  AlertSeverity worst = AlertSeverity.info;
  for (final s in stations) {
    final sev = _stationSeverity(s);
    if (sev.priority > worst.priority) worst = sev;
  }
  return worst;
}

AlertSeverity _stationSeverity(RiverStation s) {
  if (s.hfl > 0 && s.current >= s.hfl)        return AlertSeverity.emergency;
  if (s.danger > 0 && s.current >= s.danger)   return AlertSeverity.emergency;
  if (s.warning > 0 && s.current >= s.warning) return AlertSeverity.critical;
  if (s.progressPct >= 0.75)                   return AlertSeverity.warning;
  return AlertSeverity.info;
}

Color _severityFill(AlertSeverity sev) {
  switch (sev) {
    case AlertSeverity.emergency: return AppPalette.critical.withValues(alpha: 0.28);
    case AlertSeverity.critical:  return AppPalette.danger.withValues(alpha: 0.22);
    case AlertSeverity.warning:   return AppPalette.warning.withValues(alpha: 0.18);
    case AlertSeverity.info:      return AppPalette.safe.withValues(alpha: 0.08);
  }
}

Color _severityBorder(AlertSeverity sev) {
  switch (sev) {
    case AlertSeverity.emergency: return AppPalette.critical.withValues(alpha: 0.80);
    case AlertSeverity.critical:  return AppPalette.danger.withValues(alpha: 0.70);
    case AlertSeverity.warning:   return AppPalette.warning.withValues(alpha: 0.60);
    case AlertSeverity.info:      return AppPalette.safe.withValues(alpha: 0.30);
  }
}
