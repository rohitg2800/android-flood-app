// lib/providers/real_time_river_provider.dart
// NOTE: dataFetchStationsProvider is now defined in stubs.dart
// and re-exported here for backward-compat.
export 'stubs.dart' show dataFetchStationsProvider;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/river_station.dart';
import 'merged_stations_provider.dart';
import 'stubs.dart';

// ---------------------------------------------------------------------------
// Merged stations with DataFetch overlay
// ---------------------------------------------------------------------------
final mergedRiverStationsProvider = Provider<List<RiverStation>>((ref) {
  final base      = ref.watch(mergedStationsProvider);
  final dfStations = ref.watch(dataFetchStationsProvider);

  if (dfStations.isEmpty) return base;

  // Merge: df data wins for matching station names
  final dfMap = <String, RiverStation>{
    for (final s in dfStations) s.station: s,
  };

  final List<RiverStation> merged = [
    for (final s in base) dfMap[s.station] ?? s,
    // append df stations not present in base
    for (final s in dfStations)
      if (!base.any((b) => b.station == s.station)) s,
  ];

  return merged;
});
