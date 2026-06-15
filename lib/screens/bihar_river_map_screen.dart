// lib/screens/bihar_river_map_screen.dart
// OpsFlood — BiharRiverMapScreen v5.8
//
// v5.8 (15 Jun 2026 — unique per-risk-level station pins):
//   • _StationPin completely redesigned for visual hierarchy:
//       – CRITICAL  : large (30px) red rotated-square, pulsing ring,
//                     always shows ⚠ level label in red pill
//       – SEVERE    : medium (24px) orange circle, pulsing ring,
//                     always shows ▲ level label in orange pill
//       – MODERATE  : small (18px) gold rotated-diamond, NO pulsing ring,
//                     shows level label only when within 0.5 m of warning
//       – SAFE      : tiny (10px) green dot, NO icon, NO label
//                     (shows 💧 rain pill only when rainfall > 10 mm)
//       – noData    : micro (7px) grey dot, NO label whatsoever
//   • Marker width/height reduced for SAFE (44×44) and noData (28×28)
//     so they don't hog touch area and let danger pins be tapped easily.
//   • _PulsingRing speed unchanged (900 ms), restricted to CRITICAL/SEVERE.
//   • All _StationSheet / _LayerPanel / provider code unchanged from v5.7.
//
// v5.7 (15 Jun 2026 — ML fields wired into _StationSheet).
// v5.6.2 (14 Jun 2026 — map spam fix).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../data/bihar_rivers.dart';
import '../providers/map_live_index_provider.dart';
import '../providers/prediction_provider.dart';
import '../providers/real_time_river_provider.dart';
import '../providers/silent_tile_provider.dart';
import '../theme/river_theme.dart';
import 'city_detail_screen.dart';
import '../providers/flood_providers.dart';
import '../widgets/map/bihar_district_heatmap.dart';

// ────────────────────────────────────────────────────────────────────────────────
// Severity system
// ────────────────────────────────────────────────────────────────────────────────

enum RiskLevel { critical, severe, moderate, safe, noData }

RiskLevel _parseRisk(String? raw, {bool hasLiveData = true}) {
  if (!hasLiveData || raw == null || raw.isEmpty) return RiskLevel.noData;
  switch (raw.toUpperCase()) {
    case 'CRITICAL':
    case 'DANGER':
      return RiskLevel.critical;
    case 'SEVERE':
      return RiskLevel.severe;
    case 'MODERATE':
    case 'WARNING':
    case 'HIGH':
      return RiskLevel.moderate;
    case 'NORMAL':
    case 'SAFE':
    case 'LOW':
      return RiskLevel.safe;
    default:
      return RiskLevel.safe;
  }
}

Color _riskColor(RiskLevel level) {
  switch (level) {
    case RiskLevel.critical: return AppPalette.critical;
    case RiskLevel.severe:   return AppPalette.danger;
    case RiskLevel.moderate: return AppPalette.gold;
    case RiskLevel.safe:     return AppPalette.safe;
    case RiskLevel.noData:   return AppPalette.textGrey;
  }
}

String _riskLabel(RiskLevel level) {
  switch (level) {
    case RiskLevel.critical: return 'CRITICAL';
    case RiskLevel.severe:   return 'SEVERE';
    case RiskLevel.moderate: return 'WARNING';
    case RiskLevel.safe:     return 'SAFE';
    case RiskLevel.noData:   return 'NO DATA';
  }
}

IconData _riskIcon(RiskLevel level) {
  switch (level) {
    case RiskLevel.critical: return Icons.warning_rounded;
    case RiskLevel.severe:   return Icons.warning_amber_rounded;
    case RiskLevel.moderate: return Icons.info_rounded;
    case RiskLevel.safe:     return Icons.check_circle_rounded;
    case RiskLevel.noData:   return Icons.help_outline_rounded;
  }
}

Color _riskColour(String risk, RiverColors t) => _riskColor(_parseRisk(risk));

// ────────────────────────────────────────────────────────────────────────────────
// RainViewer URL
// ────────────────────────────────────────────────────────────────────────────────
const _rainViewerUrl =
    'https://tilecache.rainviewer.com/v2/radar/nowcast/{z}/{x}/{y}/2/1_1.png';

// ────────────────────────────────────────────────────────────────────────────────
// Tile styles
// ────────────────────────────────────────────────────────────────────────────────

enum _TileStyle { voyager, dark, osm, satellite, terrain, hybrid }

extension _TileStyleInfo on _TileStyle {
  String get label {
    switch (this) {
      case _TileStyle.voyager:   return 'Day';
      case _TileStyle.dark:      return 'Dark';
      case _TileStyle.osm:       return 'OSM';
      case _TileStyle.satellite: return 'Satellite';
      case _TileStyle.terrain:   return 'Terrain';
      case _TileStyle.hybrid:    return 'Hybrid';
    }
  }

  IconData get icon {
    switch (this) {
      case _TileStyle.voyager:   return Icons.wb_sunny_rounded;
      case _TileStyle.dark:      return Icons.dark_mode_rounded;
      case _TileStyle.osm:       return Icons.map_outlined;
      case _TileStyle.satellite: return Icons.satellite_alt_rounded;
      case _TileStyle.terrain:   return Icons.terrain_rounded;
      case _TileStyle.hybrid:    return Icons.layers_rounded;
    }
  }

  String get urlTemplate {
    switch (this) {
      case _TileStyle.voyager:
        return 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';
      case _TileStyle.dark:
        return 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
      case _TileStyle.osm:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case _TileStyle.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case _TileStyle.terrain:
        return 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
      case _TileStyle.hybrid:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    }
  }

  List<String> get subdomains {
    switch (this) {
      case _TileStyle.voyager:
      case _TileStyle.dark:
        return ['a', 'b', 'c', 'd'];
      case _TileStyle.terrain:
        return ['a', 'b', 'c'];
      default:
        return [];
    }
  }

  bool get retinaMode {
    switch (this) {
      case _TileStyle.voyager:
      case _TileStyle.dark:
        return true;
      default:
        return false;
    }
  }

  bool get needsLabelLayer => this == _TileStyle.hybrid;

  String get attribution {
    switch (this) {
      case _TileStyle.satellite:
      case _TileStyle.hybrid:
        return '© Esri';
      case _TileStyle.terrain:
        return '© OpenTopoMap contributors';
      default:
        return '© OpenStreetMap / CARTO';
    }
  }
}

const _biharCenter = LatLng(25.78, 85.82);
const _initialZoom = 7.4;

String _norm(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[()_\-]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

// ────────────────────────────────────────────────────────────────────────────────
// BiharRiverMapScreen
// ────────────────────────────────────────────────────────────────────────────────

class BiharRiverMapScreen extends ConsumerStatefulWidget {
  static const String route = '/bihar_river_map';
  const BiharRiverMapScreen({super.key});

  @override
  ConsumerState<BiharRiverMapScreen> createState() =>
      _BiharRiverMapScreenState();
}

class _BiharRiverMapScreenState extends ConsumerState<BiharRiverMapScreen> {
  final _mapCtrl = MapController();

  final _rainTileProvider = SilentTileProvider(
    maxAge: const Duration(minutes: 10),
  );

  String?    _filterRiver;
  RiskLevel? _filterRisk;
  _TileStyle _tileStyle         = _TileStyle.voyager;
  bool       _showPrecip        = false;
  double     _precipOpacity     = 0.65;
  bool       _showStations      = true;
  double     _stationOpacity    = 1.0;
  bool       _showHeatmap       = true;
  bool       _layerPanelOpen    = false;

  static final _rivers =
      kBiharGauges.map((g) => g.river).toSet().toList()..sort();

  @override
  void dispose() {
    _rainTileProvider.dispose();
    super.dispose();
  }

  MapStationData? _resolveMerged(
    BiharGauge gauge,
    Map<String, MapStationData> index,
  ) {
    final normStation  = _norm(gauge.station);
    final normRiver    = _norm(gauge.river);
    final direct       = index[normStation];
    if (direct != null) { return direct; }

    final stFirst = normStation.split(' ').first;
    final rvFirst = normRiver.split(' ').first;
    for (final entry in index.entries) {
      if (entry.key.contains(stFirst) &&
          entry.key.contains(rvFirst)) { return entry.value; }
    }
    for (final sd in index.values) {
      if (_norm(sd.river) != normRiver) { continue; }
      if (_norm(sd.city).contains(stFirst)) { return sd; }
    }
    return null;
  }

  void _showStationSheet(
    BuildContext context,
    BiharGauge gauge,
    MapStationData? live,
    RiverColors t,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _StationSheet(gauge: gauge, live: live, t: t),
    );
  }

  static double _markerW(RiskLevel lvl) {
    switch (lvl) {
      case RiskLevel.critical: return 80;
      case RiskLevel.severe:   return 70;
      case RiskLevel.moderate: return 60;
      case RiskLevel.safe:     return 44;
      case RiskLevel.noData:   return 28;
    }
  }

  static double _markerH(RiskLevel lvl) {
    switch (lvl) {
      case RiskLevel.critical: return 100;
      case RiskLevel.severe:   return 88;
      case RiskLevel.moderate: return 72;
      case RiskLevel.safe:     return 44;
      case RiskLevel.noData:   return 28;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t              = RiverColors.of(context);
    final liveIndex      = ref.watch(mapLiveIndexProvider);
    final mergedStations = ref.watch(mergedStationsProvider);

    final liveCount = liveIndex.values.where((s) => s.isLive).length;

    final gauges = kBiharGauges.where((g) {
      if (_filterRiver != null && g.river != _filterRiver) return false;
      if (_filterRisk != null) {
        final live  = _resolveMerged(g, liveIndex);
        final level = _parseRisk(live?.riskLabel,
            hasLiveData: live != null && live.isLive);
        if (level != _filterRisk) return false;
      }
      return true;
    }).toList();

    final Map<RiskLevel, int> riskCounts = {};
    for (final g in kBiharGauges) {
      final live  = _resolveMerged(g, liveIndex);
      final level = _parseRisk(live?.riskLabel,
          hasLiveData: live != null && live.isLive);
      riskCounts[level] = (riskCounts[level] ?? 0) + 1;
    }
    final critCount   = riskCounts[RiskLevel.critical] ?? 0;
    final severeCount = riskCounts[RiskLevel.severe]   ?? 0;
    final dangerTotal = critCount + severeCount;

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapCtrl,
            options: const MapOptions(
              initialCenter: _biharCenter,
              initialZoom:   _initialZoom,
              minZoom: 5.0,
              maxZoom: 16.0,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:          _tileStyle.urlTemplate,
                subdomains:           _tileStyle.subdomains,
                userAgentPackageName: 'com.rohitg.floodwatch',
                retinaMode:           _tileStyle.retinaMode,
              ),
              if (_tileStyle.needsLabelLayer)
                TileLayer(
                  urlTemplate:
                      'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
                  userAgentPackageName: 'com.rohitg.floodwatch',
                ),
              if (_showPrecip)
                Opacity(
                  opacity: _precipOpacity,
                  child: TileLayer(
                    urlTemplate:          _rainViewerUrl,
                    userAgentPackageName: 'com.rohitg.floodwatch',
                    tileProvider:         _rainTileProvider,
                  ),
                ),
              BiharDistrictHeatmap(
                stations:      mergedStations,
                mapController: _mapCtrl,
                visible:       _showHeatmap,
              ),
              // Station risk pins — 3 passes so CRITICAL renders on top
              if (_showStations)
                Opacity(
                  opacity: _stationOpacity,
                  child: MarkerLayer(
                    markers: [
                      // Pass 1 — SAFE + noData
                      ...gauges
                          .where((g) {
                            final live = _resolveMerged(g, liveIndex);
                            final lvl  = _parseRisk(live?.riskLabel,
                                hasLiveData: live != null && live.isLive);
                            return lvl == RiskLevel.safe ||
                                lvl == RiskLevel.noData;
                          })
                          .map((gauge) {
                            final live  = _resolveMerged(gauge, liveIndex);
                            final level = _parseRisk(live?.riskLabel,
                                hasLiveData: live != null && live.isLive);
                            return Marker(
                              point:  LatLng(gauge.lat, gauge.lon),
                              width:  _markerW(level),
                              height: _markerH(level),
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  _showStationSheet(context, gauge, live, t);
                                },
                                child: _StationPin(
                                  level:        level,
                                  rainfall:     live?.rainfall24h,
                                  currentLevel: live?.currentLevel,
                                  warningLevel: gauge.warningLevel,
                                ),
                              ),
                            );
                          }),
                      // Pass 2 — MODERATE
                      ...gauges
                          .where((g) {
                            final live = _resolveMerged(g, liveIndex);
                            final lvl  = _parseRisk(live?.riskLabel,
                                hasLiveData: live != null && live.isLive);
                            return lvl == RiskLevel.moderate;
                          })
                          .map((gauge) {
                            final live  = _resolveMerged(gauge, liveIndex);
                            const level = RiskLevel.moderate;
                            return Marker(
                              point:  LatLng(gauge.lat, gauge.lon),
                              width:  _markerW(level),
                              height: _markerH(level),
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  _showStationSheet(context, gauge, live, t);
                                },
                                child: _StationPin(
                                  level:        level,
                                  rainfall:     live?.rainfall24h,
                                  currentLevel: live?.currentLevel,
                                  warningLevel: gauge.warningLevel,
                                ),
                              ),
                            );
                          }),
                      // Pass 3 — SEVERE + CRITICAL (foreground, largest)
                      ...gauges
                          .where((g) {
                            final live = _resolveMerged(g, liveIndex);
                            final lvl  = _parseRisk(live?.riskLabel,
                                hasLiveData: live != null && live.isLive);
                            return lvl == RiskLevel.severe ||
                                lvl == RiskLevel.critical;
                          })
                          .map((gauge) {
                            final live  = _resolveMerged(gauge, liveIndex);
                            final level = _parseRisk(live?.riskLabel,
                                hasLiveData: live != null && live.isLive);
                            return Marker(
                              point:  LatLng(gauge.lat, gauge.lon),
                              width:  _markerW(level),
                              height: _markerH(level),
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  _showStationSheet(context, gauge, live, t);
                                },
                                child: _StationPin(
                                  level:        level,
                                  rainfall:     live?.rainfall24h,
                                  currentLevel: live?.currentLevel,
                                  warningLevel: gauge.warningLevel,
                                ),
                              ),
                            );
                          }),
                    ],
                  ),
                ),
            ],
          ),

          // ── AppBar overlay ──────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    // Back button
                    Material(
                      color: t.cardBg.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.of(context).pop(),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(Icons.arrow_back_ios_new_rounded,
                              color: t.textSecondary, size: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Title card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: t.cardBg.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: t.stroke),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.water_rounded,
                                color: t.accent, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Bihar River Map',
                                style: TextStyle(
                                  color:      t.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize:   14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Live count badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color:        AppPalette.safe.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                                border:       Border.all(
                                    color: AppPalette.safe.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                '$liveCount live',
                                style: TextStyle(
                                  color:      AppPalette.safe,
                                  fontSize:   10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (dangerTotal > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color:        AppPalette.critical.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                  border:       Border.all(
                                      color: AppPalette.critical.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  '⚠ $dangerTotal',
                                  style: TextStyle(
                                    color:      AppPalette.critical,
                                    fontSize:   10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Layer panel toggle
                    Material(
                      color: _layerPanelOpen
                          ? t.accent.withValues(alpha: 0.9)
                          : t.cardBg.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () =>
                            setState(() => _layerPanelOpen = !_layerPanelOpen),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(Icons.layers_rounded,
                              color: _layerPanelOpen
                                  ? Colors.white
                                  : t.textSecondary,
                              size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Risk filter chips ───────────────────────────────────────────
          Positioned(
            top: 70,
            left: 12,
            right: 12,
            child: SafeArea(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // River filter
                    _FilterChip(
                      label: _filterRiver ?? 'All rivers',
                      color: t.accent,
                      active: _filterRiver != null,
                      onTap: () => _showRiverPicker(context, t),
                    ),
                    const SizedBox(width: 6),
                    // Risk level filters
                    for (final lvl in RiskLevel.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _FilterChip(
                          label: _riskLabel(lvl),
                          color: _riskColor(lvl),
                          active: _filterRisk == lvl,
                          count: riskCounts[lvl],
                          onTap: () => setState(() =>
                              _filterRisk = _filterRisk == lvl ? null : lvl),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── Layer panel ─────────────────────────────────────────────────
          if (_layerPanelOpen)
            Positioned(
              top: 68,
              right: 12,
              child: SafeArea(
                child: _LayerPanel(
                  t:               t,
                  tileStyle:       _tileStyle,
                  showPrecip:      _showPrecip,
                  precipOpacity:   _precipOpacity,
                  showStations:    _showStations,
                  stationOpacity:  _stationOpacity,
                  showHeatmap:     _showHeatmap,
                  onTileStyle:     (s) => setState(() => _tileStyle = s),
                  onPrecipToggle:  (v) => setState(() => _showPrecip = v),
                  onPrecipOpacity: (v) => setState(() => _precipOpacity = v),
                  onStationsToggle:(v) => setState(() => _showStations = v),
                  onStationOpacity:(v) => setState(() => _stationOpacity = v),
                  onHeatmapToggle: (v) => setState(() => _showHeatmap = v),
                ),
              ),
            ),

          // ── Legend ──────────────────────────────────────────────────────
          Positioned(
            bottom: 24,
            left: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final lvl in [
                  RiskLevel.critical,
                  RiskLevel.severe,
                  RiskLevel.moderate,
                  RiskLevel.safe,
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color:        t.cardBg.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _riskColor(lvl).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                              color:  _riskColor(lvl),
                              shape:  BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _riskLabel(lvl),
                            style: TextStyle(
                              color:      t.textSecondary,
                              fontSize:   9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          if ((riskCounts[lvl] ?? 0) > 0) ...[
                            const SizedBox(width: 5),
                            Text(
                              '${riskCounts[lvl]}',
                              style: TextStyle(
                                color:      _riskColor(lvl),
                                fontSize:   9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── FAB: recenter ───────────────────────────────────────────────
          Positioned(
            bottom: 24,
            right: 12,
            child: FloatingActionButton.small(
              backgroundColor: t.cardBg,
              onPressed: () {
                _mapCtrl.move(_biharCenter, _initialZoom);
              },
              child: Icon(Icons.my_location_rounded,
                  color: t.accent, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  void _showRiverPicker(BuildContext context, RiverColors t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: t.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: t.stroke,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.clear_all_rounded, color: t.accent),
              title: Text('All Rivers',
                  style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700)),
              onTap: () {
                setState(() => _filterRiver = null);
                Navigator.pop(context);
              },
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _rivers.length,
                itemBuilder: (_, i) {
                  final river = _rivers[i];
                  return ListTile(
                    leading: Icon(Icons.water_rounded,
                        color: _filterRiver == river
                            ? t.accent
                            : t.textSecondary,
                        size: 18),
                    title: Text(river,
                        style: TextStyle(
                          color: _filterRiver == river
                              ? t.accent
                              : t.textPrimary,
                          fontWeight: _filterRiver == river
                              ? FontWeight.w700
                              : FontWeight.normal,
                        )),
                    onTap: () {
                      setState(() => _filterRiver = river);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────────
// _FilterChip
// ────────────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String   label;
  final Color    color;
  final bool     active;
  final int?     count;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.22)
              : Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? color : color.withValues(alpha: 0.3),
              width: active ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color:      active ? color : color.withValues(alpha: 0.7),
                fontSize:   11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 5),
              Text(
                '$count',
                style: TextStyle(
                  color:      active ? color : color.withValues(alpha: 0.6),
                  fontSize:   10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────────
// _StationPin  v5.8 — 5-level visual hierarchy
// ────────────────────────────────────────────────────────────────────────────────

class _StationPin extends StatelessWidget {
  final RiskLevel level;
  final double?   rainfall;
  final double?   currentLevel;
  final double?   warningLevel;

  const _StationPin({
    required this.level,
    this.rainfall,
    this.currentLevel,
    this.warningLevel,
  });

  @override
  Widget build(BuildContext context) {
    switch (level) {
      case RiskLevel.critical:
        return _CriticalPin(
          currentLevel: currentLevel,
          warningLevel: warningLevel,
        );
      case RiskLevel.severe:
        return _SeverePin(
          currentLevel: currentLevel,
          warningLevel: warningLevel,
        );
      case RiskLevel.moderate:
        return _ModeratePin(
          currentLevel: currentLevel,
          warningLevel: warningLevel,
        );
      case RiskLevel.safe:
        return _SafePin(rainfall: rainfall);
      case RiskLevel.noData:
        return _NoDataPin();
    }
  }
}

// ── CRITICAL pin ──────────────────────────────────────────────────────────────

class _CriticalPin extends StatelessWidget {
  final double? currentLevel;
  final double? warningLevel;
  const _CriticalPin({this.currentLevel, this.warningLevel});

  @override
  Widget build(BuildContext context) {
    final color = AppPalette.critical;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PulsingRing(
          color: color,
          child: Transform.rotate(
            angle: 0.785398, // 45°
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color:  color,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color:      color.withValues(alpha: 0.6),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Transform.rotate(
                  angle: -0.785398,
                  child: const Icon(Icons.warning_rounded,
                      color: Colors.white, size: 16),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        _LevelPill(
          label: currentLevel != null
              ? '⚠ ${currentLevel!.toStringAsFixed(1)}m'
              : '⚠ CRITICAL',
          color: color,
        ),
      ],
    );
  }
}

// ── SEVERE pin ────────────────────────────────────────────────────────────────

class _SeverePin extends StatelessWidget {
  final double? currentLevel;
  final double? warningLevel;
  const _SeverePin({this.currentLevel, this.warningLevel});

  @override
  Widget build(BuildContext context) {
    final color = AppPalette.danger;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PulsingRing(
          color: color,
          child: Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color:  color,
              shape:  BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:      color.withValues(alpha: 0.5),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.warning_amber_rounded,
                  color: Colors.white, size: 13),
            ),
          ),
        ),
        const SizedBox(height: 3),
        _LevelPill(
          label: currentLevel != null
              ? '▲ ${currentLevel!.toStringAsFixed(1)}m'
              : '▲ SEVERE',
          color: color,
        ),
      ],
    );
  }
}

// ── MODERATE pin ──────────────────────────────────────────────────────────────

class _ModeratePin extends StatelessWidget {
  final double? currentLevel;
  final double? warningLevel;
  const _ModeratePin({this.currentLevel, this.warningLevel});

  bool get _nearWarning {
    if (currentLevel == null || warningLevel == null) return false;
    return (warningLevel! - currentLevel!).abs() <= 0.5;
  }

  @override
  Widget build(BuildContext context) {
    const color = AppPalette.gold;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.rotate(
          angle: 0.785398,
          child: Container(
            width: 18, height: 18,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        if (_nearWarning) ...[
          const SizedBox(height: 3),
          _LevelPill(
            label: currentLevel != null
                ? '${currentLevel!.toStringAsFixed(1)}m'
                : 'WARN',
            color: color,
          ),
        ],
      ],
    );
  }
}

// ── SAFE pin ──────────────────────────────────────────────────────────────────

class _SafePin extends StatelessWidget {
  final double? rainfall;
  const _SafePin({this.rainfall});

  @override
  Widget build(BuildContext context) {
    final showRain = rainfall != null && rainfall! > 10;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10, height: 10,
          decoration: const BoxDecoration(
            color: AppPalette.safe,
            shape: BoxShape.circle,
          ),
        ),
        if (showRain) ...[
          const SizedBox(height: 2),
          _LevelPill(
            label: '💧 ${rainfall!.toStringAsFixed(0)}',
            color: Colors.lightBlue,
          ),
        ],
      ],
    );
  }
}

// ── NO DATA pin ───────────────────────────────────────────────────────────────

class _NoDataPin extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7, height: 7,
      decoration: BoxDecoration(
        color: AppPalette.textGrey.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
    );
  }
}

// ── _LevelPill ────────────────────────────────────────────────────────────────

class _LevelPill extends StatelessWidget {
  final String label;
  final Color  color;
  const _LevelPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border:       Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color:      color,
          fontSize:   8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── _PulsingRing ──────────────────────────────────────────────────────────────

class _PulsingRing extends StatefulWidget {
  final Widget child;
  final Color  color;
  const _PulsingRing({required this.child, required this.color});

  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>    _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width:  50 * _anim.value,
            height: 50 * _anim.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.color.withValues(alpha: 0.6 * (1 - _anim.value + 0.3)),
                width: 2,
              ),
            ),
          ),
          child!,
        ],
      ),
      child: widget.child,
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────────
// _StationSheet  v5.7
// ────────────────────────────────────────────────────────────────────────────────

class _StationSheet extends ConsumerWidget {
  final BiharGauge      gauge;
  final MapStationData? live;
  final RiverColors     t;

  const _StationSheet({
    required this.gauge,
    required this.live,
    required this.t,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = _parseRisk(live?.riskLabel,
        hasLiveData: live != null && live!.isLive);
    final color = _riskColor(level);

    // ML prediction (v5.7)
    final predAsync = live != null && live!.isLive
        ? ref.watch(predictionProvider(gauge.station))
        : null;

    return Container(
      decoration: BoxDecoration(
        color:        t.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border:       Border.all(color: t.stroke),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: t.stroke,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Station header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:        color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_riskIcon(level), color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gauge.station,
                          style: TextStyle(
                            color:      t.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize:   16,
                          ),
                        ),
                        Text(
                          gauge.river,
                          style: TextStyle(
                              color:    t.textSecondary,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color:        color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                      border:       Border.all(
                          color: color.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      _riskLabel(level),
                      style: TextStyle(
                        color:      color,
                        fontSize:   11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Live data row
              if (live != null && live!.isLive) ...[
                _DataRow(
                  t:     t,
                  icon:  Icons.water_rounded,
                  label: 'Current Level',
                  value: live!.currentLevel != null
                      ? '${live!.currentLevel!.toStringAsFixed(2)} m'
                      : '—',
                  color: color,
                ),
                if (gauge.warningLevel != null)
                  _DataRow(
                    t:     t,
                    icon:  Icons.warning_amber_rounded,
                    label: 'Warning Level',
                    value: '${gauge.warningLevel!.toStringAsFixed(2)} m',
                    color: AppPalette.gold,
                  ),
                if (gauge.dangerLevel != null)
                  _DataRow(
                    t:     t,
                    icon:  Icons.dangerous_rounded,
                    label: 'Danger Level',
                    value: '${gauge.dangerLevel!.toStringAsFixed(2)} m',
                    color: AppPalette.critical,
                  ),
                if (live!.rainfall24h != null)
                  _DataRow(
                    t:     t,
                    icon:  Icons.water_drop_rounded,
                    label: '24h Rainfall',
                    value: '${live!.rainfall24h!.toStringAsFixed(1)} mm',
                    color: Colors.lightBlue,
                  ),
                if (live!.trend != null)
                  _DataRow(
                    t:     t,
                    icon:  live!.trend == 'rising'
                        ? Icons.trending_up_rounded
                        : live!.trend == 'falling'
                            ? Icons.trending_down_rounded
                            : Icons.trending_flat_rounded,
                    label: 'Trend',
                    value: live!.trend!.toUpperCase(),
                    color: live!.trend == 'rising'
                        ? AppPalette.critical
                        : AppPalette.safe,
                  ),
                const SizedBox(height: 12),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'No live data available for this station.',
                    style: TextStyle(
                        color: t.textSecondary, fontSize: 13),
                  ),
                ),
              ],

              // ML prediction section (v5.7)
              if (predAsync != null)
                predAsync.when(
                  data: (pred) {
                    if (pred == null) return const SizedBox.shrink();
                    return _MlSection(t: t, pred: pred);
                  },
                  loading: () => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: t.accent),
                        ),
                        const SizedBox(width: 8),
                        Text('Loading ML prediction…',
                            style: TextStyle(
                                color: t.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),

              // Location
              _DataRow(
                t:     t,
                icon:  Icons.location_on_rounded,
                label: 'Location',
                value: '${gauge.lat.toStringAsFixed(4)}°N, '
                    '${gauge.lon.toStringAsFixed(4)}°E',
                color: t.accent,
              ),
              const SizedBox(height: 8),

              // Open City Detail button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('View City Detail',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      '/city_detail',
                      arguments: gauge.station,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── _MlSection ────────────────────────────────────────────────────────────────

class _MlSection extends StatelessWidget {
  final RiverColors t;
  final dynamic     pred; // FloodPrediction
  const _MlSection({required this.t, required this.pred});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        t.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: t.accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  color: t.accent, size: 14),
              const SizedBox(width: 6),
              Text(
                'ML PREDICTION',
                style: TextStyle(
                  color:      t.accent,
                  fontSize:   10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (pred.predictedLevel != null)
            Text(
              '${pred.predictedLevel!.toStringAsFixed(2)} m predicted (24h)',
              style: TextStyle(
                color:      t.textPrimary,
                fontSize:   13,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (pred.confidence != null) ...[
            const SizedBox(height: 4),
            Text(
              'Confidence: ${(pred.confidence! * 100).toStringAsFixed(0)}%',
              style: TextStyle(color: t.textSecondary, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

// ── _DataRow ──────────────────────────────────────────────────────────────────

class _DataRow extends StatelessWidget {
  final RiverColors t;
  final IconData    icon;
  final String      label;
  final String      value;
  final Color       color;

  const _DataRow({
    required this.t,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(color: t.textSecondary, fontSize: 12)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                color:      t.textPrimary,
                fontSize:   12,
                fontWeight: FontWeight.w700,
              )),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────────
// _LayerPanel
// ────────────────────────────────────────────────────────────────────────────────

class _LayerPanel extends StatelessWidget {
  final RiverColors  t;
  final _TileStyle   tileStyle;
  final bool         showPrecip;
  final double       precipOpacity;
  final bool         showStations;
  final double       stationOpacity;
  final bool         showHeatmap;
  final void Function(_TileStyle)   onTileStyle;
  final void Function(bool)         onPrecipToggle;
  final void Function(double)       onPrecipOpacity;
  final void Function(bool)         onStationsToggle;
  final void Function(double)       onStationOpacity;
  final void Function(bool)         onHeatmapToggle;

  const _LayerPanel({
    required this.t,
    required this.tileStyle,
    required this.showPrecip,
    required this.precipOpacity,
    required this.showStations,
    required this.stationOpacity,
    required this.showHeatmap,
    required this.onTileStyle,
    required this.onPrecipToggle,
    required this.onPrecipOpacity,
    required this.onStationsToggle,
    required this.onStationOpacity,
    required this.onHeatmapToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        t.cardBg.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: t.stroke),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('LAYERS',
              style: TextStyle(
                color:      t.textSecondary,
                fontSize:   10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              )),
          const SizedBox(height: 10),

          // Tile style
          Text('Map Style',
              style: TextStyle(
                  color: t.textSecondary, fontSize: 11)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _TileStyle.values.map((s) {
              final active = tileStyle == s;
              return GestureDetector(
                onTap: () => onTileStyle(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color:        active
                        ? t.accent.withValues(alpha: 0.2)
                        : t.cardBgElevated,
                    borderRadius: BorderRadius.circular(8),
                    border:       Border.all(
                        color: active ? t.accent : t.stroke),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(s.icon,
                          color:
                              active ? t.accent : t.textSecondary,
                          size: 12),
                      const SizedBox(width: 4),
                      Text(s.label,
                          style: TextStyle(
                            color:      active
                                ? t.accent
                                : t.textSecondary,
                            fontSize:   10,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Precipitation toggle
          _ToggleRow(
            t:       t,
            icon:    Icons.water_drop_rounded,
            label:   'Precipitation',
            value:   showPrecip,
            onChanged: onPrecipToggle,
          ),
          if (showPrecip) ...[
            const SizedBox(height: 6),
            Slider(
              value:     precipOpacity,
              onChanged: onPrecipOpacity,
              activeColor:   t.accent,
              inactiveColor: t.stroke,
              min: 0.1, max: 1.0,
            ),
          ],
          const SizedBox(height: 8),

          // Stations toggle
          _ToggleRow(
            t:       t,
            icon:    Icons.location_on_rounded,
            label:   'Stations',
            value:   showStations,
            onChanged: onStationsToggle,
          ),
          if (showStations) ...[
            const SizedBox(height: 6),
            Slider(
              value:     stationOpacity,
              onChanged: onStationOpacity,
              activeColor:   t.accent,
              inactiveColor: t.stroke,
              min: 0.2, max: 1.0,
            ),
          ],
          const SizedBox(height: 8),

          // Heatmap toggle
          _ToggleRow(
            t:       t,
            icon:    Icons.gradient_rounded,
            label:   'District Heatmap',
            value:   showHeatmap,
            onChanged: onHeatmapToggle,
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final RiverColors        t;
  final IconData           icon;
  final String             label;
  final bool               value;
  final void Function(bool) onChanged;

  const _ToggleRow({
    required this.t,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: t.textSecondary, size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  color: t.textSecondary, fontSize: 12)),
        ),
        Switch.adaptive(
          value:           value,
          onChanged:       onChanged,
          activeColor:     t.accent,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }
}
