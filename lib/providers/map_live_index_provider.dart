// lib/providers/map_live_index_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/river_station.dart';
import 'merged_stations_provider.dart';
import 'stubs.dart';

export 'stubs.dart' show sourceStatusProvider;

/// Index of stations keyed by district, optionally filtered by source status.
final mapLiveIndexProvider =
    Provider<Map<String, List<RiverStation>>>((ref) {
  final stations  = ref.watch(mergedStationsProvider);
  final dfSources = ref.watch(sourceStatusProvider); // Map<String, bool>

  final Map<String, List<RiverStation>> index = {};
  for (final s in stations) {
    final sourceKey = s.station.toLowerCase();
    if (dfSources.isNotEmpty && dfSources[sourceKey] == false) continue;
    index.putIfAbsent(s.city, () => []).add(s);
  }
  return index;
});
