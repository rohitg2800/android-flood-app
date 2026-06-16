// lib/screens/map_screen.dart
// MapScreen — Bihar Flood Command Center Map v9.2
// v9.2: Removed broken PulseMarker/AmberPulseMarker/StaticMarker calls
//       (widgets never existed). Markers now rendered via MapMarkers widget
//       which self-manages animation. Added onStationSelected to MapTopBar.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../models/river_station.dart';
import '../providers/map_command_provider.dart';
import '../providers/real_time_river_provider.dart';
import '../providers/live_engine_bridge_provider.dart';
import '../theme/rx.dart';
import '../widgets/map/map_widgets.dart';

// ── View constants ────────────────────────────────────────────────────────────
const _biharCenter = LatLng(25.5, 85.1);
const _biharZoom   = 6.8;
const _indiaCenter = LatLng(22.5, 80.0);
const _indiaZoom   = 4.5;

// ─────────────────────────────────────────────────────────────────────────────
class MapScreen extends ConsumerStatefulWidget {
  static const String route = '/map';
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with TickerProviderStateMixin {
  final _mapController = MapController();
  bool _showLegend = true;
  bool _showDrawer = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _flyTo(LatLng pt, double zoom) => _mapController.move(pt, zoom);

  // ── GeoJSON → Polygon layer ────────────────────────────────────────────────
  List<Polygon> _buildPolygons(
    Map<String, dynamic> geoJson,
    Map<String, DangerClass> riskMap,
  ) {
    final features = geoJson['features'] as List<dynamic>? ?? [];
    final polygons = <Polygon>[];

    for (final f in features) {
      final props = f['properties'] as Map<String, dynamic>? ?? {};
      final name  = (
        props['district'] ??
        props['District'] ??
        props['NAME_2']   ??
        props['name']     ??
        ''
      ).toString().toLowerCase();

      final dc  = riskMap[name] ?? DangerClass.normal;
      final geo = f['geometry'] as Map<String, dynamic>? ?? {};
      final type = geo['type']  as String? ?? '';

      final rings = <List<LatLng>>[];
      if (type == 'Polygon') {
        rings.addAll(_parseRings(geo['coordinates'] as List));
      } else if (type == 'MultiPolygon') {
        for (final p in (geo['coordinates'] as List)) {
          rings.addAll(_parseRings(p as List));
        }
      }

      for (final ring in rings) {
        if (ring.length < 3) continue;
        polygons.add(Polygon(
          points:            ring,
          color:             riskColor(dc),
          borderColor:       riskColor(dc, opacity: 0.7),
          borderStrokeWidth: 1.0,
        ));
      }
    }
    return polygons;
  }

  List<List<LatLng>> _parseRings(List raw) => raw
      .map((ring) => (ring as List)
          .map((pt) {
            final p = pt as List;
            return LatLng(
              (p[1] as num).toDouble(),
              (p[0] as num).toDouble(),
            );
          })
          .toList())
      .toList();

  void _onMarkerTap(RiverStation s) {
    HapticFeedback.selectionClick();
    ref.read(mapSelectedStationProvider.notifier).state = s;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => RiverPulsePopup(station: s),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rc       = context.rc;
    final mode     = ref.watch(mapViewModeProvider);
    final stations = ref.watch(mapStationsProvider);
    final distRisk = ref.watch(biharDistrictRiskProvider);
    final syncMeta = ref.watch(mapSyncMetaProvider);
    final geoAsync = ref.watch(biharGeoJsonProvider);
    final isBihar  = mode == MapViewMode.bihar;

    ref.watch(liveEngineStationsProvider);

    return Scaffold(
      backgroundColor: rc.scaffoldBg,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: isBihar ? _biharCenter : _indiaCenter,
              initialZoom:   isBihar ? _biharZoom   : _indiaZoom,
              minZoom: 3,
              maxZoom: 18,
              onTap: (_, __) =>
                  ref.read(mapSelectedStationProvider.notifier).state = null,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.opsflood.app',
              ),
              if (isBihar)
                geoAsync.when(
                  data:    (gj) => PolygonLayer(
                      polygons: _buildPolygons(gj, distRisk)),
                  loading: ()      => const SizedBox.shrink(),
                  error:   (_, __) => const SizedBox.shrink(),
                ),
              // ── Markers: MapMarkers handles animation internally ─────────
              MapMarkers(
                stations:      _toFloodStations(stations),
                onStationTap:  (fs) {
                  // Find matching RiverStation to reuse existing popup
                  final match = stations.where(
                    (s) => s.station.toLowerCase() == fs.city.toLowerCase(),
                  ).firstOrNull;
                  if (match != null) _onMarkerTap(match);
                },
              ),
            ],
          ),

          Positioned(
            top:   MediaQuery.of(context).padding.top + 8,
            left:  12,
            right: 12,
            child: MapTopBar(
              mode:           mode,
              syncMeta:       syncMeta,
              drawerOpen:     _showDrawer,
              onToggle: () {
                final next = isBihar
                    ? MapViewMode.national
                    : MapViewMode.bihar;
                ref.read(mapViewModeProvider.notifier).state = next;
                _flyTo(
                  next == MapViewMode.bihar ? _biharCenter : _indiaCenter,
                  next == MapViewMode.bihar ? _biharZoom   : _indiaZoom,
                );
              },
              onDrawerToggle: () =>
                  setState(() => _showDrawer = !_showDrawer),
              onStationSelected: (fs) {
                if (fs.lat != null && fs.lon != null) {
                  _flyTo(LatLng(fs.lat!, fs.lon!), 10);
                }
              },
            ),
          ),

          if (_showLegend)
            Positioned(
              bottom: _showDrawer ? 340 : 100,
              right:  12,
              child: MapSourceLegend(
                syncMeta: syncMeta,
                onClose:  () => setState(() => _showLegend = false),
              ),
            ),

          if (!_showLegend)
            Positioned(
              bottom: _showDrawer ? 340 : 100,
              right:  12,
              child: FloatingActionButton.small(
                heroTag:         'legend_fab',
                backgroundColor: rc.cardBg,
                onPressed: () => setState(() => _showLegend = true),
                child: Icon(Icons.layers_outlined,
                    color: rc.accent, size: 20),
              ),
            ),

          if (_showDrawer)
            MapTelemetrySheet(
              stations: stations,
              onClose:  () => setState(() => _showDrawer = false),
              onTap: (s) {
                if (coordFor(s) case final coord?) {
                  _flyTo(coord, 10);
                  setState(() => _showDrawer = false);
                }
                _onMarkerTap(s);
              },
            ),

          if (ref.watch(realTimeRiverProvider).isLoading)
            Positioned(
              top:   MediaQuery.of(context).padding.top + 72,
              left:  0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color:        rc.cardBg.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: rc.accent),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Fetching live data…',
                        style: TextStyle(
                          color:      rc.textPrimary,
                          fontSize:   12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── RiverStation → FloodStation adapter (for MapMarkers widget) ───────────────
// MapMarkers was rewritten in Task 3 to use FloodStation.
// This thin adapter converts the Riverpod RiverStation list on the fly
// so the existing provider chain doesn't need to change.
List<FloodStation> _toFloodStations(List<RiverStation> rs) {
  return rs.map((s) {
    final risk = switch (s.dangerClass) {
      DangerClass.extreme     => 'CRITICAL',
      DangerClass.severe      => 'HIGH',
      DangerClass.aboveNormal => 'MODERATE',
      DangerClass.normal      => 'LOW',
    };
    return FloodStation(
      id:           s.station,
      city:         s.station,
      state:        s.state,
      riverName:    s.river,
      riskLevel:    risk,
      currentLevel: s.current > 0 ? s.current : null,
      dangerLevel:  s.danger  > 0 ? s.danger  : null,
      warningLevel: s.warning > 0 ? s.warning : null,
      lat:          s.lat,
      lon:          s.lon,
      trend:        s.trend,
      dataSource:   s.isLive ? 'live' : 'static',
      lastUpdated:  null,
    );
  }).toList();
}
