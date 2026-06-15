// lib/providers/map_live_index_provider.dart
// sourceStatusProvider stub imported from stubs.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/river_station.dart';
import 'merged_stations_provider.dart';
import 'stubs.dart';

// Re-export so existing imports of sourceStatusProvider from this file work.
export 'stubs.dart' show sourceStatusProvider;

/// Index of stations keyed by district, filtered by live source availability.
final mapLiveIndexProvider =
    Provider<Map<String, List<RiverStation>>>((ref) {
  final stations  = ref.watch(mergedStationsProvider);
  final dfSources = ref.watch(sourceStatusProvider); // Map<String,bool>

  final Map<String, List<RiverStation>> index = {};
  for (final s in stations) {
    // If dfSources is non-empty, skip stations whose source is marked offline.
    final sourceKey = s.station.toLowerCase();
    if (dfSources.isNotEmpty && dfSources[sourceKey] == false) continue;
    index.putIfAbsent(s.city, () => []).add(s);
  }
  return index;
});
