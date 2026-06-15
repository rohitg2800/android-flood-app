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
// v5.7 (15 Jun 2026 — ML fields wired into _StationSheet):
//   • _StationSheet now watches predictionProvider(gauge.station) when live
//     data is present; a new _mlSection() is rendered between
//     _changeSection() and _riverSection().
//
// v5.6.2 (14 Jun 2026 — map spam fix):
//   • Replace NetworkTileProvider for RainViewer with SilentTileProvider.
//
// v5.6.1 (14 Jun 2026 — analyze fixes).
// v5.6   (14 Jun 2026 — Phase 4B wire).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../data/bihar_rivers.dart';
import '../providers/map_live_index_provider.dart';
import '../providers/prediction_provider.dart';         // ← v5.7 ML
import '../providers/real_time_river_provider.dart'; // mergedStationsProvider
import '../providers/silent_tile_provider.dart';     // ← v5.6.2
import '../theme/river_theme.dart';
import 'city_detail_screen.dart';
import '../providers/flood_providers.dart';
import '../widgets/map/bihar_district_heatmap.dart';

// ────────────────────────────────────────────────────────────────────────────────
// Severity system  (5 levels)
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

  // ── Marker size per risk level ─────────────────────────────────────────────
  // SAFE/noData get small footprints so they don't absorb taps intended for
  // nearby danger pins.
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
              // ── Base tile ─────────────────────────────────────────────
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
              // ── District heatmap ─────────────────────────────────────
              BiharDistrictHeatmap(
                stations:      mergedStations,
                mapController: _mapCtrl,
                visible:       _showHeatmap,
              ),
              // ── Station risk pins ─────────────────────────────────────
              // v5.8: SAFE/noData rendered first (bottom of stack) so
              // CRITICAL/SEVERE pins paint on top and are tapped first.
              if (_showStations)
                Opacity(
                  opacity: _stationOpacity,
                  child: MarkerLayer(
                    markers: [
                      // Pass 1 — SAFE + noData (background, small)
                      ...gauges
                          .where((g) {
                            final live  = _resolveMerged(g, liveIndex);
                            final lvl   = _parseRisk(live?.riskLabel,
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
                      // Pass 2 — MODERATE (middle)
                      ...gauges
                          .where((g) {
                            final live  = _resolveMerged(g, liveIndex);
                            final lvl   = _parseRisk(live?.riskLabel,
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
                            final live  = _resolveMerged(g, liveIndex);
                            final lvl   = _parseRisk(live?.riskLabel,
                                hasLiveData: live != null && live.isLive);
                            return lvl == RiskLevel.severe ||
                                lvl == RiskLevel.critical;
                          })
                          .map((gauge) {
            