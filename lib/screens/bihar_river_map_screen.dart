// lib/screens/bihar_river_map_screen.dart  v8.0  (15 Jun 2026)
//
// v8.0 — Full parity upgrade:
//   • Synced to SAME providers as MapScreen:
//       - mapStationsProvider   (Bihar-filtered live stations via mergedStations)
//       - biharDistrictRiskProvider  (polygon heatmap layer)
//       - biharGeoJsonProvider   (GeoJSON district boundaries)
//       - liveEngineStationsProvider (CWC FFEM live push)
//       - mapSyncMetaProvider    (freshness labels)
//   • Same marker system: PulseMarker / AmberPulseMarker / StaticMarker
//     (extreme/severe → red pulse, aboveNormal → amber pulse, normal → static)
//   • Same polygon heatmap layer (district risk colours)
//   • Themed UI using RiverColors instead of plain AppBar
//   • MapTopBar (Bihar-only, no toggle button)
//   • MapSourceLegend / floating legend FAB
//   • MapTelemetrySheet slide-up drawer
//   • RiverPulsePopup on station tap
//   • Loading indicator overlay
//   • AutoRefreshMixin kept for pull-to-refresh
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../mixins/auto_refresh_mixin.dart';
import '../models/river_station.dart';
import '../providers/map_command_provider.dart';
import '../providers/real_time_river_provider.dart';
import '../providers/live_engine_bridge_provider.dart';
import '../theme/rx.dart';
import '../widgets/map/map_widgets.dart';

const _kBiharCenter = LatLng(25.78, 85.17);
const _kBiharZoom   = 7.2;

class BiharRiverMapScreen extends ConsumerStatefulWidget {
  const BiharRiverMapScreen({super.key});

  /// Named route used by Navigator.pushNamed.
  static const String route = '/bihar-river-map';

  @override
  ConsumerState<BiharRiverMapScreen> createState() =>
      _BiharRiverMapScreenState();
}

class _BiharRiverMapScreenState extends ConsumerState<BiharRiverMapScreen>
    with AutoRefreshMixin, TickerProviderStateMixin {
  final _mapController = MapController();
  bool _showLegend = true;
  bool _showDrawer = false;

  // Pulse animation controllers keyed by station name.
  final Map<String, AnimationController> _pulseCtrl = {};

  @override
  void dispose() {
    _mapController.dispose();
    for (final c in _pulseCtrl.values) c.dispose();
    super.dispose();
  }

  AnimationController _pulseFor(String key) =>
      _pulseCtrl.putIfAbsent(
        key,
        () => AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1200),
        )..repeat(reverse: true),
      );

  // ── GeoJSON → Polygon layer ──────────────────────────────────────────────
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
      final type = geo['type'] as String? ?? '';
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

  // ── Marker builder ────────────────────────────────────────────────────────
  String? _levelLabel(RiverStation s) {
    if (s.current <= 0) return null;
    return '${s.current.toStringAsFixed(2)}m';
  }

  List<Marker> _buildMarkers(List<RiverStation> stations) {
    return [
      for (final s in stations)
        if (coordFor(s) case final coord?)
          Marker(
            point:  coord,
            width:  _markerSize(s),
            height: _markerSize(s),
            child:  GestureDetector(
              onTap: () => _onMarkerTap(s),
              child: _buildMarkerWidget(s),
            ),
          ),
    ];
  }

  double _markerSize(RiverStation s) {
    switch (s.dangerClass) {
      case DangerClass.extreme:
      case DangerClass.severe:      return 58;
      case DangerClass.aboveNormal: return 50;
      case DangerClass.normal:      return 44;
    }
  }

  Widget _buildMarkerWidget(RiverStation s) {
    final level = _levelLabel(s);
    switch (s.dangerClass) {
      case DangerClass.extreme:
      case DangerClass.severe:
        return PulseMarker(
          dangerClass: s.dangerClass,
          ctrl:        _pulseFor(s.station),
          level:       level,
        );
      case DangerClass.aboveNormal:
        return AmberPulseMarker(
          ctrl:  _pulseFor(s.station),
          level: level,
        );
      case DangerClass.normal:
        return StaticMarker(
          dangerClass: s.dangerClass,
          level:       level,
          isLive:      s.isLive,
        );
    }
  }

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
    // Bihar map always uses Bihar mode — force it in case provider defaults national.
    ref.read(mapViewModeProvider.notifier).state = MapViewMode.bihar;

    final stations = ref.watch(mapStationsProvider);       // Bihar-filtered live
    final distRisk = ref.watch(biharDistrictRiskProvider); // polygon colours
    final syncMeta = ref.watch(mapSyncMetaProvider);       // freshness
    final geoAsync = ref.watch(biharGeoJsonProvider);      // district GeoJSON
    final isLoading = ref.watch(wrdIsLoadingProvider);

    // Kick the live engine (same as MapScreen)
    ref.watch(liveEngineStationsProvider);

    return Scaffold(
      backgroundColor: rc.scaffoldBg,
      body: refreshIndicator(
        child: Stack(
          children: [
            // ── Base map + layers ──────────────────────────────────────────
            FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: _kBiharCenter,
                initialZoom:   _kBiharZoom,
                minZoom: 5,
                maxZoom: 18,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.opsflood.app',
                ),
                // District heatmap polygon layer
                geoAsync.when(
                  data:    (gj) => PolygonLayer(
                      polygons: _buildPolygons(gj, distRisk)),
                  loading: () => const SizedBox.shrink(),
                  error:   (_, __) => const SizedBox.shrink(),
                ),
                // Live station markers
                MarkerLayer(markers: _buildMarkers(stations)),
              ],
            ),

            // ── Themed top bar (Bihar-only, no Bihar/National toggle) ──────
            Positioned(
              top:   MediaQuery.of(context).padding.top + 8,
              left:  12,
              right: 12,
              child: _BiharMapTopBar(
                syncMeta:       syncMeta,
                isLoading:      isLoading,
                stationCount:   stations.length,
                drawerOpen:     _showDrawer,
                onDrawerToggle: () =>
                    setState(() => _showDrawer = !_showDrawer),
                onRefresh: onManualRefresh,
              ),
            ),

            // ── Legend ─────────────────────────────────────────────────────
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
                  heroTag:         'bmap_legend_fab',
                  backgroundColor: rc.cardBg,
                  onPressed: () => setState(() => _showLegend = true),
                  child: Icon(Icons.layers_outlined,
                      color: rc.accent, size: 20),
                ),
              ),

            // ── Telemetry drawer ────────────────────────────────────────────
            if (_showDrawer)
              MapTelemetrySheet(
                stations: stations,
                onClose:  () => setState(() => _showDrawer = false),
                onTap: (s) {
                  if (coordFor(s) case final coord?) {
                    _mapController.move(coord, 10);
                    setState(() => _showDrawer = false);
                  }
                  _onMarkerTap(s);
                },
              ),

            // ── Loading overlay ─────────────────────────────────────────────
            if (isLoading)
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
                          'Fetching live data\u2026',
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
      ),
    );
  }
}

// ── Bihar-specific top bar (no Bihar/National toggle) ─────────────────────────
class _BiharMapTopBar extends StatelessWidget {
  final SyncMeta syncMeta;
  final bool     isLoading;
  final int      stationCount;
  final bool     drawerOpen;
  final VoidCallback onDrawerToggle;
  final VoidCallback onRefresh;

  const _BiharMapTopBar({
    required this.syncMeta,
    required this.isLoading,
    required this.stationCount,
    required this.drawerOpen,
    required this.onDrawerToggle,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:        rc.cardBg.withOpacity(0.93),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: rc.stroke.withOpacity(0.4), width: 1),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.18),
            blurRadius: 12,
            offset:     const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color:        rc.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: rc.accent, size: 16),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bihar River Map',
                  style: TextStyle(
                    color:      rc.textPrimary,
                    fontSize:   14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$stationCount stations  \u2022  ${syncMeta.freshnessLabel}',
                  style: TextStyle(
                    color:    rc.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Refresh button
          GestureDetector(
            onTap: onRefresh,
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color:        rc.cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: rc.stroke.withOpacity(0.4), width: 1),
              ),
              child: isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: rc.accent),
                    )
                  : Icon(Icons.refresh_rounded,
                      color: rc.accent, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          // Telemetry drawer toggle
          GestureDetector(
            onTap: onDrawerToggle,
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: drawerOpen
                    ? rc.accent.withOpacity(0.18)
                    : rc.cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: drawerOpen
                        ? rc.accent.withOpacity(0.5)
                        : rc.stroke.withOpacity(0.4),
                    width: 1),
              ),
              child: Icon(
                drawerOpen
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.table_rows_rounded,
                color: rc.accent,
                size:  18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
