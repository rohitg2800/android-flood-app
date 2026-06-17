// File: lib/screens/bihar_river_map_screen.dart
// Updated: June 2026
// Changes:
//   - Severity chip filter row (NORMAL / WARNING / DANGER / CRITICAL)
//   - Hide-NORMAL FAB (eye icon)
//   - _toFloodStations() respects effectiveVisibleClassesProvider
//   - MapTelemetrySheet now receives totalCount
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart' as pv;

import '../mixins/auto_refresh_mixin.dart';
import '../models/flood_station.dart';
import '../models/river_station.dart';
import '../providers/flood_data_provider.dart';
import '../providers/map_command_provider.dart';
import '../providers/map_severity_filter_provider.dart';
import '../providers/real_time_river_provider.dart';
import '../providers/live_engine_bridge_provider.dart';
import '../theme/rx.dart';
import '../widgets/map/map_widgets.dart';

const _kBiharCenter  = LatLng(25.78, 85.17);
const _kBiharZoom   = 7.2;
const _kIndiaCenter  = LatLng(22.5, 80.0);
const _kIndiaZoom    = 4.5;

// ── Chip label / colour helpers ───────────────────────────────────────────────
_ChipMeta _chipMeta(DangerClass dc) => switch (dc) {
  DangerClass.extreme     => _ChipMeta('CRITICAL', const Color(0xFFC62828)),
  DangerClass.severe      => _ChipMeta('DANGER',   const Color(0xFFE65100)),
  DangerClass.aboveNormal => _ChipMeta('WARNING',  const Color(0xFFF9A825)),
  DangerClass.normal      => _ChipMeta('NORMAL',   const Color(0xFF2E7D32)),
};

class _ChipMeta {
  final String label;
  final Color  color;
  const _ChipMeta(this.label, this.color);
}

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
        ref.read(mapViewModeProvider.notifier).set(MapViewMode.bihar);
      }
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    for (final c in _pulseCtrl.values) c.dispose();
    super.dispose();
  }

  // ── GeoJSON → Polygon layer ──────────────────────────────────────────────
  // ignore: unused_element
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

  // ignore: unused_element
  String? _levelLabel(RiverStation s) {
    if (s.current <= 0) return null;
    return '${s.current.toStringAsFixed(2)}m';
  }

  void _onMarkerTap(RiverStation s) {
    HapticFeedback.selectionClick();
    ref.read(mapSelectedStationProvider.notifier).set(s);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => RiverPulsePopup(station: s),
    );
  }

  void _showStationPopup(FloodStation station) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FloodStationSheet(station: station),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rc             = context.rc;
    final mode           = ref.watch(mapViewModeProvider);
    final isBihar        = mode == MapViewMode.bihar;
    final allStations    = ref.watch(liveEngineStationsProvider);
    final distRisk       = ref.watch(biharDistrictRiskProvider);
    final syncMeta       = ref.watch(mapSyncMetaProvider);
    final geoAsync       = ref.watch(biharGeoJsonProvider);
    final isLoading      = ref.watch(wrdIsLoadingProvider);
    final activeFilters  = ref.watch(activeFiltersProvider);
    final hideNormal     = ref.watch(hideNormalProvider);
    final visibleClasses = ref.watch(effectiveVisibleClassesProvider);

    // Apply filter to station list
    final filteredStations = visibleClasses == null
        ? allStations
        : allStations
            .where((s) => visibleClasses.contains(s.dangerClass))
            .toList();

    final isFilterActive = visibleClasses != null;

    return pv.ChangeNotifierProvider(
      create: (_) => FloodDataProvider(),
      child: Scaffold(
        backgroundColor: rc.scaffoldBg,
        body: refreshIndicator(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: isBihar ? _kBiharCenter : _kIndiaCenter,
                  initialZoom:   isBihar ? _kBiharZoom   : _kIndiaZoom,
                  minZoom: 3,
                  maxZoom: 18,
                  onTap: (_, __) =>
                      ref.read(mapSelectedStationProvider.notifier).set(null),
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
                  // Filtered markers
                  MapMarkers(
                    stations:     _toFloodStations(filteredStations),
                    onStationTap: _showStationPopup,
                  ),
                ],
              ),

              // ── Top bar ──────────────────────────────────────────────────
              Positioned(
                top:   MediaQuery.of(context).padding.top + 8,
                left:  12,
                right: 12,
                child: _BiharMapTopBar(
                  syncMeta:       syncMeta,
                  isLoading:      isLoading,
                  stationCount:   filteredStations.length,
                  totalCount:     allStations.length,
                  drawerOpen:     _showDrawer,
                  onDrawerToggle: () =>
                      setState(() => _showDrawer = !_showDrawer),
                  onToggle: () {
                    final next = isBihar
                        ? MapViewMode.national
                        : MapViewMode.bihar;
                    ref.read(mapViewModeProvider.notifier).set(next);
                    _mapController.move(
                      next == MapViewMode.bihar ? _kBiharCenter : _kIndiaCenter,
                      next == MapViewMode.bihar ? _kBiharZoom   : _kIndiaZoom,
                    );
                  },
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

              // ── Severity chip row (shown above drawer when open) ──────────
              if (_showDrawer)
                Positioned(
                  bottom: MediaQuery.of(context).size.height * 0.45 + 4,
                  left:   0,
                  right:  0,
                  child: _SeverityChipBar(
                    activeFilters: activeFilters,
                    hideNormal:    hideNormal,
                    onToggleChip: (dc) =>
                        ref.read(activeFiltersProvider.notifier).toggle(dc),
                    onClear: () {
                      ref.read(activeFiltersProvider.notifier).clear();
                      ref.read(hideNormalProvider.notifier).clear();
                    },
                  ),
                ),

              // ── Legend ───────────────────────────────────────────────────
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

              // ── Hide-NORMAL FAB ──────────────────────────────────────────
              Positioned(
                bottom: _showDrawer ? 340 : 56,
                right:  12,
                child: FloatingActionButton.small(
                  heroTag:         'bmap_hide_normal_fab',
                  backgroundColor: hideNormal
                      ? rc.accent
                      : rc.cardBg,
                  tooltip: hideNormal
                      ? 'Showing elevated only — tap to reset'
                      : 'Hide NORMAL stations',
                  onPressed: () =>
                      ref.read(hideNormalProvider.notifier).toggle(),
                  child: Icon(
                    hideNormal
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: hideNormal ? rc.scaffoldBg : rc.accent,
                    size: 18,
                  ),
                ),
              ),

              // ── Telemetry drawer ─────────────────────────────────────────
              if (_showDrawer)
                MapTelemetrySheet(
                  stations:   filteredStations,
                  totalCount: allStations.length,
                  onClose:    () => setState(() => _showDrawer = false),
                  onTap: (s) {
                    if (coordFor(s) case final coord?) {
                      _mapController.move(coord, 10);
                      setState(() => _showDrawer = false);
                    }
                    _onMarkerTap(s);
                  },
                ),

              // ── Legacy WRD loading indicator ──────────────────────────────
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

              // ── GloFAS loading overlay ────────────────────────────────────
              pv.Consumer<FloodDataProvider>(
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

              // ── Filter active banner ──────────────────────────────────────
              if (isFilterActive && !_showDrawer)
                Positioned(
                  bottom: 56,
                  left:   60,
                  right:  60,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        ref.read(activeFiltersProvider.notifier).clear();
                        ref.read(hideNormalProvider.notifier).clear();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color:        rc.accent.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.filter_alt_rounded,
                                color: rc.scaffoldBg, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'Filter active — tap to clear',
                              style: TextStyle(
                                color:      rc.scaffoldBg,
                                fontSize:   11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Severity chip bar ─────────────────────────────────────────────────────────
class _SeverityChipBar extends StatelessWidget {
  final Set<DangerClass>      activeFilters;
  final bool                  hideNormal;
  final void Function(DangerClass) onToggleChip;
  final VoidCallback          onClear;

  const _SeverityChipBar({
    required this.activeFilters,
    required this.hideNormal,
    required this.onToggleChip,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    return Container(
      color: rc.scaffoldBg.withOpacity(0.94),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          ...DangerClass.values.map((dc) {
            final meta    = _chipMeta(dc);
            final isActive = activeFilters.contains(dc);
            final isDimmed = hideNormal && dc == DangerClass.normal;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => onToggleChip(dc),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isActive
                        ? meta.color
                        : meta.color.withOpacity(isDimmed ? 0.1 : 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: meta.color.withOpacity(
                          isActive ? 1.0 : (isDimmed ? 0.2 : 0.45)),
                      width: isActive ? 1.5 : 1.0,
                    ),
                  ),
                  child: Text(
                    meta.label,
                    style: TextStyle(
                      color: isActive
                          ? Colors.white
                          : meta.color.withOpacity(isDimmed ? 0.4 : 0.9),
                      fontSize:   11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          if (activeFilters.isNotEmpty)
            GestureDetector(
              onTap: onClear,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color:        rc.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: rc.stroke.withOpacity(0.5), width: 1),
                ),
                child: Text(
                  'CLEAR',
                  style: TextStyle(
                    color:      rc.textSecondary,
                    fontSize:   11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Inline FloodStation bottom sheet ─────────────────────────────────────────
class _FloodStationSheet extends StatelessWidget {
  final FloodStation station;
  const _FloodStationSheet({required this.station});

  @override
  Widget build(BuildContext context) {
    final s  = station;
    final rc = context.rc;
    final riskColor = switch (s.riskLevel) {
      'CRITICAL' => const Color(0xFFC62828),
      'HIGH'     => const Color(0xFFFF8F00),
      'MODERATE' => const Color(0xFFF57F17),
      'LOW'      => const Color(0xFF2E7D32),
      _          => const Color(0xFF757575),
    };
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        color: rc.cardBg,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: rc.stroke,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.city,
                          style: TextStyle(
                              color: rc.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                      Text('${s.riverName}  •  ${s.state}',
                          style: TextStyle(
                              color: rc.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: riskColor.withOpacity(0.5)),
                  ),
                  child: Text(s.riskLevel,
                      style: TextStyle(
                          color: riskColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (s.currentLevel != null)
              Text(
                'Level: ${s.currentLevel!.toStringAsFixed(2)} m'
                '${s.dangerLevel != null ? "  •  Danger: ${s.dangerLevel!.toStringAsFixed(2)} m" : ""}',
                style: TextStyle(
                    color: rc.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            if (s.trend != null) ...[
              const SizedBox(height: 6),
              Text('Trend: ${s.trend}  •  Source: ${s.dataSource}',
                  style: TextStyle(
                      color: rc.textSecondary, fontSize: 11)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded,
                    size: 16, color: rc.scaffoldBg),
                label: Text('Close',
                    style: TextStyle(color: rc.scaffoldBg)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: rc.accent,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bihar-specific top bar ─────────────────────────────────────────────────────
class _BiharMapTopBar extends StatelessWidget {
  final SyncMeta syncMeta;
  final bool     isLoading;
  final int      stationCount;   // filtered count
  final int      totalCount;     // unfiltered total
  final bool     drawerOpen;
  final VoidCallback onDrawerToggle;
  final VoidCallback onToggle;
  final VoidCallback onRefresh;
  final void Function(FloodStation station) onStationSelected;

  const _BiharMapTopBar({
    required this.syncMeta,
    required this.isLoading,
    required this.stationCount,
    required this.totalCount,
    required this.drawerOpen,
    required this.onDrawerToggle,
    required this.onToggle,
    required this.onRefresh,
    required this.onStationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final rc         = context.rc;
    final isFiltered = stationCount != totalCount;
    final countLabel = isFiltered
        ? '$stationCount / $totalCount'
        : '$stationCount stations';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:        rc.cardBg.withOpacity(0.93),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isFiltered
                ? rc.accent.withOpacity(0.6)
                : rc.stroke.withOpacity(0.4),
            width: isFiltered ? 1.5 : 1),
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
                  '$countLabel  \u2022  ${syncMeta.freshnessLabel}',
                  style: TextStyle(
                    color: isFiltered ? rc.accent : rc.textSecondary,
                    fontSize: 11,
                  ),
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
            onTap: onToggle,
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color:        rc.cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: rc.stroke.withOpacity(0.4), width: 1),
              ),
              child: Icon(Icons.public_rounded,
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

List<FloodStation> _toFloodStations(List<RiverStation> rs) {
  return rs.map<FloodStation>((s) {
    final risk = switch (s.dangerClass) {
      DangerClass.extreme     => 'CRITICAL',
      DangerClass.severe      => 'HIGH',
      DangerClass.aboveNormal => 'MODERATE',
      DangerClass.normal      => 'LOW',
    };
    return FloodStation(
      city:         s.station,
      state:        s.state,
      riverName:    s.river,
      riskLevel:    risk,
      status:       s.isLive ? 'live' : 'static',
      dataSource:   s.isLive ? 'live' : 'static',
      currentLevel: s.hasData ? s.current : null,
      dangerLevel:  s.danger  > 0 ? s.danger  : null,
      warningLevel: s.warning > 0 ? s.warning : null,
      lat:          s.lat,
      lon:          s.lon,
      trend:        s.trend,
    );
  }).toList();
}
