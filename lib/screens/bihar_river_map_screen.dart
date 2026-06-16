// File: lib/screens/bihar_river_map_screen.dart
// Updated: June 2026
// Changes: Wired FloodDataProvider + MapMarkers +
//          MapTopBar.onStationSelected + loading overlay (Task 5)
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../mixins/auto_refresh_mixin.dart';
import '../models/flood_station.dart';
import '../models/river_station.dart';
import '../providers/flood_data_provider.dart';
import '../providers/map_command_provider.dart';
import '../providers/real_time_river_provider.dart';
import '../providers/live_engine_bridge_provider.dart';
import '../theme/rx.dart';
import '../widgets/map/map_markers.dart';
import '../widgets/map/map_pulse_popup.dart';
import '../widgets/map/map_widgets.dart';

const _kBiharCenter = LatLng(25.78, 85.17);
const _kBiharZoom   = 7.2;

class BiharRiverMapScreen extends ConsumerStatefulWidget {
  const BiharRiverMapScreen({super.key});
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

  final Map<String, AnimationController> _pulseCtrl = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(mapViewModeProvider.notifier).state = MapViewMode.bihar;
      }
    });
  }

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
      final dc   = riskMap[name] ?? DangerClass.normal;
      final geo  = f['geometry'] as Map<String, dynamic>? ?? {};
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

  // ── Legacy WRD markers (kept for existing RiverStation layer) ────────────
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

  double _markerSize(RiverStation s) => switch (s.dangerClass) {
    DangerClass.extreme || DangerClass.severe => 58.0,
    DangerClass.aboveNormal                   => 50.0,
    DangerClass.normal                        => 44.0,
  };

  Widget _buildMarkerWidget(RiverStation s) {
    final level = _levelLabel(s);
    return switch (s.dangerClass) {
      DangerClass.extreme || DangerClass.severe => PulseMarker(
        dangerClass: s.dangerClass,
        ctrl:        _pulseFor(s.station),
        level:       level,
      ),
      DangerClass.aboveNormal => AmberPulseMarker(
        ctrl:  _pulseFor(s.station),
        level: level,
      ),
      DangerClass.normal => StaticMarker(
        dangerClass: s.dangerClass,
        level:       level,
        isLive:      s.isLive,
      ),
    };
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

  // ── Station popup for MapMarkers / MapTopBar ─────────────────────────────
  void _showStationPopup(FloodStation station) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => MapPulsePopup(station: station),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rc        = context.rc;
    final stations  = ref.watch(mapStationsProvider);
    final distRisk  = ref.watch(biharDistrictRiskProvider);
    final syncMeta  = ref.watch(mapSyncMetaProvider);
    final geoAsync  = ref.watch(biharGeoJsonProvider);
    final isLoading = ref.watch(wrdIsLoadingProvider);

    ref.watch(liveEngineStationsProvider);

    return ChangeNotifierProvider(
      create: (_) => FloodDataProvider(),
      child: Scaffold(
        backgroundColor: rc.scaffoldBg,
        body: refreshIndicator(
          child: Stack(
            children: [
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
                  geoAsync.when(
                    data:    (gj) => PolygonLayer(
                        polygons: _buildPolygons(gj, distRisk)),
                    loading: () => const SizedBox.shrink(),
                    error:   (_, __) => const SizedBox.shrink(),
                  ),
                  // Legacy WRD markers
                  MarkerLayer(markers: _buildMarkers(stations)),
                  // GloFAS live markers from FloodDataProvider
                  Consumer<FloodDataProvider>(
                    builder: (_, provider, __) => MapMarkers(
                      stations:     provider.biharStations,
                      onStationTap: _showStationPopup,
                    ),
                  ),
                ],
              ),

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
                  onRefresh:      onManualRefresh,
                  onStationSelected: (station) {
                    if (station.lat != null && station.lon != null) {
                      _mapController.move(
                        LatLng(station.lat!, station.lon!),
                        13.0,
                      );
                    }
                    _showStationPopup(station);
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
                    heroTag:         'bmap_legend_fab',
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
                      _mapController.move(coord, 10);
                      setState(() => _showDrawer = false);
                    }
                    _onMarkerTap(s);
                  },
                ),

              // Legacy WRD loading indicator
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

              // GloFAS loading overlay
              Consumer<FloodDataProvider>(
                builder: (_, p, __) {
                  if (!p.isLoading || p.allStations.isNotEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Positioned(
                    bottom: 24,
                    left:   0,
                    right:  0,
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
                              'Loading GloFAS stations\u2026',
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
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bihar-specific top bar ─────────────────────────────────────────────────────
class _BiharMapTopBar extends StatelessWidget {
  final SyncMeta syncMeta;
  final bool     isLoading;
  final int      stationCount;
  final bool     drawerOpen;
  final VoidCallback onDrawerToggle;
  final VoidCallback onRefresh;
  final void Function(FloodStation station) onStationSelected;

  const _BiharMapTopBar({
    required this.syncMeta,
    required this.isLoading,
    required this.stationCount,
    required this.drawerOpen,
    required this.onDrawerToggle,
    required this.onRefresh,
    required this.onStationSelected,
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
                      color: rc.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
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
