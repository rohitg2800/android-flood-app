// lib/providers/map_live_index_provider.dart
// Builds Map<String, MapStationData> keyed by normalised station name.
// Used by BiharRiverMapScreen for O(1) live-data resolution per gauge pin.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/bihar_live_provider.dart';
import '../models/map_station_data.dart';

export '../models/map_station_data.dart';

String _normKey(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[()_\-]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

final mapLiveIndexProvider = Provider<Map<String, MapStationData>>((ref) {
  final asyncState = ref.watch(biharLiveProvider);
  final liveState  = asyncState.valueOrNull;
  if (liveState == null) return const {};
  return {
    for (final s in liveState.stations)
      _normKey(s.city): MapStationData.fromBiharStation(s),
  };
});

/// Separate provider for screens that only need the live-count (avoids
/// rebuilding the full map on every gauge update).
final liveStationCountProvider = Provider<int>((ref) {
  final index = ref.watch(mapLiveIndexProvider);
  return index.values.where((s) => s.isLive).length;
});

/// sourceStatusProvider stub — imported by stubs.dart / alert screens.
final sourceStatusProvider = Provider<Map<String, bool>>((_) => const {});
