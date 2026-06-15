// lib/widgets/map/bihar_district_heatmap.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/alert_engine.dart';
import '../../models/river_station.dart';
import '../../theme/app_palette.dart';
import '../../providers/merged_stations_provider.dart';
import 'district_bottom_sheet.dart';

class BiharDistrictHeatmap extends ConsumerStatefulWidget {
  final List<RiverStation>? stations;
  // mapController accepted but ignored — keeps callers that pass it compiling.
  final dynamic mapController;
  const BiharDistrictHeatmap({super.key, this.stations, this.mapController});
  @override
  ConsumerState<BiharDistrictHeatmap> createState() =>
      _BiharDistrictHeatmapState();
}

class _BiharDistrictHeatmapState
    extends ConsumerState<BiharDistrictHeatmap> {
  @override
  Widget build(BuildContext context) {
    final List<RiverStation> stations =
        widget.stations ?? ref.watch(mergedStationsProvider);

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
        PolygonLayer(
          polygons: byDistrict.entries.map((entry) {
            final sev      = _worstSeverity(entry.value);
            final isDanger = sev == AlertSeverity.emergency ||
                             sev == AlertSeverity.critical;
            return Polygon(
              points:            _districtPolygon(entry.key),
              color:             _severityFill(sev),
              borderColor:       _severityBorder(sev),
              borderStrokeWidth: isDanger ? 2.5 : 1.0,
            );
          }).toList(),
        ),
        MarkerLayer(
          markers: stations
              .where((s) => s.lat != null && s.lon != null)
              .map((s) {
            final sev = _stationSeverity(s);
            final col = _severityBorder(sev);
            return Marker(
              point:  LatLng(s.lat!, s.lon!),
              width:  20,
              height: 20,
              child: GestureDetector(
                onTap: () => _showSheet(
                    context, s.city, byDistrict[s.city] ?? [s]),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:  col.withValues(alpha: 0.85),
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

List<LatLng> _districtPolygon(String district) {
  final centre = _kDistrictCentres[district];
  final lat = centre?.$1 ?? 25.5;
  final lon = centre?.$2 ?? 85.1;
  const d = 0.25;
  return [
    LatLng(lat + d, lon - d),
    LatLng(lat + d, lon + d),
    LatLng(lat - d, lon + d),
    LatLng(lat - d, lon - d),
  ];
}

const Map<String, (double, double)> _kDistrictCentres = {
  'Patna':          (25.594095, 85.137566),
  'Muzaffarpur':    (26.120889, 85.364723),
  'Darbhanga':      (26.152002, 85.897797),
  'Supaul':         (26.123549, 86.599485),
  'Bhagalpur':      (25.244541, 86.972142),
  'Samastipur':     (25.862600, 85.781300),
  'Vaishali':       (25.690000, 85.210000),
  'Saran':          (25.917300, 84.940000),
  'Sitamarhi':      (26.591500, 85.490300),
  'Madhubani':      (26.358200, 86.071800),
  'Gopalganj':      (26.467600, 84.436600),
  'Siwan':          (26.222700, 84.354900),
  'East Champaran': (26.655400, 84.917600),
  'West Champaran': (27.025000, 84.431700),
  'Araria':         (26.147700, 87.471700),
  'Kishanganj':     (26.099900, 87.940800),
  'Purnea':         (25.777700, 87.479800),
  'Katihar':        (25.539700, 87.573800),
};

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
