// lib/widgets/map/bihar_district_heatmap.dart
// PHASE 4B — District risk heatmap overlay for BiharRiverMapScreen
//
// Renders all 38 Bihar districts as coloured rounded-rect overlays on top
// of the existing FlutterMap.  Each district tile:
//   • fill colour  = worst-station risk (safe / warning / danger / emergency)
//   • animated pulse border when above danger
//   • tap  → opens DistrictBottomSheet with all stations in that district
//
// Drop-in usage inside BiharRiverMapScreen's Stack:
// ```dart
// BiharDistrictHeatmap(
//   stations: mergedStations,
//   mapController: _mapCtrl,
// )
// ```
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/river_station.dart';
import '../../theme/app_palette.dart';
import '../../services/alert_engine.dart';
import 'district_bottom_sheet.dart';

// ───────────────────────────────────────────────────────────────────────────────
// District centre coords for all 38 Bihar districts
// ───────────────────────────────────────────────────────────────────────────────
const List<_DistrictMeta> _kDistricts = [
  _DistrictMeta('Patna',          25.5941, 85.1376),
  _DistrictMeta('Gaya',           24.7955, 85.0002),
  _DistrictMeta('Bhagalpur',      25.2425, 86.9842),
  _DistrictMeta('Muzaffarpur',    26.1209, 85.3647),
  _DistrictMeta('Darbhanga',      26.1542, 85.8918),
  _DistrictMeta('Purnia',         25.7771, 87.4753),
  _DistrictMeta('Saharsa',        25.8772, 86.5951),
  _DistrictMeta('Sitamarhi',      26.5933, 85.4900),
  _DistrictMeta('Madhubani',      26.3583, 86.0719),
  _DistrictMeta('Supaul',         26.1232, 86.6000),
  _DistrictMeta('Araria',         26.1473, 87.5154),
  _DistrictMeta('Kishanganj',     26.0954, 87.9415),
  _DistrictMeta('Katihar',        25.5378, 87.5760),
  _DistrictMeta('Khagaria',       25.5021, 86.4666),
  _DistrictMeta('Begusarai',      25.4182, 86.1272),
  _DistrictMeta('Samastipur',     25.8637, 85.7819),
  _DistrictMeta('Vaishali',       25.6921, 85.2018),
  _DistrictMeta('Saran',          25.9196, 84.7401),
  _DistrictMeta('Siwan',          26.2196, 84.3550),
  _DistrictMeta('Gopalganj',      26.4693, 84.4377),
  _DistrictMeta('East Champaran', 26.7765, 84.9165),
  _DistrictMeta('West Champaran', 27.1045, 84.3965),
  _DistrictMeta('Sheohar',        26.5176, 85.2959),
  _DistrictMeta('Nalanda',        25.1352, 85.4439),
  _DistrictMeta('Nawada',         24.8869, 85.5440),
  _DistrictMeta('Aurangabad',     24.7526, 84.3742),
  _DistrictMeta('Arwal',          25.2421, 84.6824),
  _DistrictMeta('Jehanabad',      25.2118, 84.9964),
  _DistrictMeta('Rohtas',         24.9867, 83.8048),
  _DistrictMeta('Kaimur',         25.0459, 83.5993),
  _DistrictMeta('Buxar',          25.5645, 83.9828),
  _DistrictMeta('Bhojpur',        25.5602, 84.4602),
  _DistrictMeta('Munger',         25.3749, 86.4738),
  _DistrictMeta('Lakhisarai',     25.1579, 86.0940),
  _DistrictMeta('Sheikhpura',     25.1406, 85.8476),
  _DistrictMeta('Jamui',          24.9286, 86.2243),
  _DistrictMeta('Banka',          24.8845, 86.9259),
];

class _DistrictMeta {
  final String name;
  final double lat;
  final double lon;
  const _DistrictMeta(this.name, this.lat, this.lon);
}

// ───────────────────────────────────────────────────────────────────────────────
// Risk severity helpers (district-level)
// ───────────────────────────────────────────────────────────────────────────────
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
    default:                      return AppPalette.safe.withValues(alpha: 0.10);
  }
}

Color _severityBorder(AlertSeverity sev) {
  switch (sev) {
    case AlertSeverity.emergency: return AppPalette.critical.withValues(alpha: 0.80);
    case AlertSeverity.critical:  return AppPalette.danger.withValues(alpha: 0.70);
    case AlertSeverity.warning:   return AppPalette.warning.withValues(alpha: 0.60);
    default:                      return AppPalette.safe.withValues(alpha: 0.35);
  }
}

// ───────────────────────────────────────────────────────────────────────────────
// Main widget
// ───────────────────────────────────────────────────────────────────────────────
class BiharDistrictHeatmap extends StatefulWidget {
  final List<RiverStation> stations;
  final MapController mapController;
  final bool visible;

  const BiharDistrictHeatmap({
    super.key,
    required this.stations,
    required this.mapController,
    this.visible = true,
  });

  @override
  State<BiharDistrictHeatmap> createState() =>
      _BiharDistrictHeatmapState();
}

class _BiharDistrictHeatmapState extends State<BiharDistrictHeatmap>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  // district name → stations
  late Map<String, List<RiverStation>> _byDistrict;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _rebuildIndex();
  }

  @override
  void didUpdateWidget(BiharDistrictHeatmap old) {
    super.didUpdateWidget(old);
    if (old.stations != widget.stations) _rebuildIndex();
  }

  void _rebuildIndex() {
    _byDistrict = {};
    for (final s in widget.stations) {
      // FIX: RiverStation has no .district field — use .city as the bucket key
      final key = s.city.isNotEmpty ? s.city : s.river;
      _byDistrict.putIfAbsent(key, () => []).add(s);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  List<RiverStation> _stationsFor(String districtName) {
    // fuzzy match against city (the closest field to district on RiverStation)
    final lower = districtName.toLowerCase();
    return widget.stations
        .where((s) => s.city.toLowerCase().contains(lower))
        .toList();
  }

  void _onDistrictTap(BuildContext ctx, _DistrictMeta d) {
    final stations = _stationsFor(d.name);
    showModalBottomSheet(
      context:     ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DistrictBottomSheet(
        districtName: d.name,
        stations:     stations,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (ctx, _) {
        return MarkerLayer(
          markers: _kDistricts.map((d) {
            final stations = _stationsFor(d.name);
            final sev      = _worstSeverity(stations);
            final isDanger = sev == AlertSeverity.emergency ||
                             sev == AlertSeverity.critical;
            final fill     = _severityFill(sev);
            final border   = _severityBorder(sev);
            final pulse    = isDanger ? _pulseAnim.value : 1.0;

            return Marker(
              point:  LatLng(d.lat, d.lon),
              width:  90,
              height: 40,
              child:  GestureDetector(
                onTap: () => _onDistrictTap(ctx, d),
                child: Opacity(
                  opacity: pulse,
                  child: Container(
                    decoration: BoxDecoration(
                      color:        fill,
                      borderRadius: BorderRadius.circular(10),
                      border:       Border.all(color: border, width: isDanger ? 1.5 : 1.0),
                      boxShadow: isDanger
                          ? [
                              BoxShadow(
                                color:      border.withValues(alpha: 0.35),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(
                      d.name,
                      style: TextStyle(
                        color:      isDanger ? border : AppPalette.textGrey,
                        fontSize:   9.5,
                        fontWeight: isDanger ? FontWeight.w800 : FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                      textAlign:  TextAlign.center,
                      maxLines:   2,
                      overflow:   TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
