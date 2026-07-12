// lib/providers/map_live_index_provider.dart
//
// MapStationData — thin view-model consumed by bihar_river_map_screen.dart.
// mapLiveIndexProvider — Map<normalisedStationName, MapStationData>
//
// Fix (15 Jun 2026): RiverStation has no previousReading or rainfall24h fields.
//   - trend derivation via previousReading removed; trend = s.trend (already on model)
//   - rainfall24h → s.rainfallLastHour (the actual field name on RiverStation)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/river_station.dart';
import 'merged_stations_provider.dart';
import 'stubs.dart';

export 'stubs.dart' show sourceStatusProvider;

// ─────────────────────────────────────────────────────────────────────────────
// MapStationData
// ─────────────────────────────────────────────────────────────────────────────
/// View-model for a single gauge on the Bihar map.
class MapStationData {
  final String station;
  final String river;
  final String city;

  /// CWC / WRD risk label: "CRITICAL" | "DANGER" | "WARNING" | "SAFE" | "LOW"
  final String? riskLabel;
  final bool isLive;
  final double? currentLevel;
  final double? rainfall24h;
  final String? trend; // "rising" | "falling" | "steady"

  const MapStationData({
    required this.station,
    required this.river,
    required this.city,
    this.riskLabel,
    this.isLive = false,
    this.currentLevel,
    this.rainfall24h,
    this.trend,
  });

  factory MapStationData.fromStation(RiverStation s) {
    // Derive risk label from thresholds
    final cl = s.current;
    final dl = s.danger;
    final wl = s.warning;
    final hfl = s.hfl;

    String? riskLabel;
    if (hfl > 0 && cl >= hfl * 0.98) {
      riskLabel = 'CRITICAL';
    } else if (dl > 0 && cl >= dl) {
      riskLabel = 'DANGER';
    } else if (dl > 0 && cl >= dl * 0.85) {
      riskLabel = 'WARNING';
    } else if (wl > 0 && cl >= wl) {
      riskLabel = 'WARNING';
    } else if (cl > 0) {
      riskLabel = 'SAFE';
    }

    // Fix: RiverStation has no previousReading field.
    // Use s.trend (String?) which is already set by DataFetchEngine.
    // Normalise to the values bihar_river_map_screen.dart expects.
    String? trend;
    if (s.trend != null) {
      final t = s.trend!.toLowerCase();
      if (t.contains('↑') || t.contains('ris') || t.contains('up')) {
        trend = 'rising';
      } else if (t.contains('↓') || t.contains('fall') || t.contains('down')) {
        trend = 'falling';
      } else {
        trend = 'steady';
      }
    }

    return MapStationData(
      station: s.station,
      river: s.river,
      city: s.city,
      riskLabel: riskLabel,
      isLive: s.isLive,
      currentLevel: cl > 0 ? cl : null,
      // Fix: RiverStation has rainfallLastHour, not rainfall24h.
      rainfall24h: s.rainfallLastHour,
      trend: trend,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// mapLiveIndexProvider
// ─────────────────────────────────────────────────────────────────────────────
/// Keyed by normalised station name (lower-case, spaces trimmed).
/// bihar_river_map_screen.dart resolves stations via fuzzy matching on this map.
final mapLiveIndexProvider = Provider<Map<String, MapStationData>>((ref) {
  final stations = ref.watch(mergedStationsProvider);
  final dfSources = ref.watch(sourceStatusProvider);

  final Map<String, MapStationData> index = {};
  for (final s in stations) {
    final sourceKey = s.station.toLowerCase();
    if (dfSources.isNotEmpty && dfSources[sourceKey] == false) continue;
    final normKey = sourceKey
        .replaceAll(RegExp(r'[()_\-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    index[normKey] = MapStationData.fromStation(s);
  }
  return index;
});
