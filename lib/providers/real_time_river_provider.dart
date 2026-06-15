// lib/providers/real_time_river_provider.dart
// RESTORED: full provider set that merged_stations_provider.dart re-exports.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/river_station.dart';
import '../providers/bihar_live_provider.dart';
import 'stubs.dart';

export 'stubs.dart' show dataFetchStationsProvider;

// ── wrd / CWC stations provider ──────────────────────────────────────────────
/// Raw WRD stations from the live Bihar provider.
final wrdRiverStationsProvider = Provider<List<RiverStation>>((ref) {
  final liveState = ref.watch(biharLiveProvider);
  return liveState.stations;
});

/// Alias kept for backward compat.
final wrdStationsProvider = wrdRiverStationsProvider;

// ── merged stations ───────────────────────────────────────────────────────────
/// Merged station list: WRD base + DataFetch overlay.
/// This is the canonical provider that all map/alert screens consume.
final mergedStationsProvider = Provider<List<RiverStation>>((ref) {
  final base      = ref.watch(wrdRiverStationsProvider);
  final dfStations = ref.watch(dataFetchStationsProvider);

  if (dfStations.isEmpty) return base;

  final dfMap = <String, RiverStation>{
    for (final s in dfStations) s.station: s,
  };

  return [
    for (final s in base) dfMap[s.station] ?? s,
    for (final s in dfStations)
      if (!base.any((b) => b.station == s.station)) s,
  ];
});

// ── merged river result (loading/error state wrapper) ────────────────────────
class RealTimeRiverState {
  final List<RiverStation> stations;
  final bool               isLoading;
  final String?            error;
  const RealTimeRiverState({
    this.stations  = const [],
    this.isLoading = false,
    this.error,
  });
}

final realTimeRiverProvider = Provider<RealTimeRiverState>((ref) {
  final liveState = ref.watch(biharLiveProvider);
  return RealTimeRiverState(
    stations:  liveState.stations,
    isLoading: liveState.isLoading,
    error:     liveState.error,
  );
});

// ── error / loading helpers ───────────────────────────────────────────────────
final wrdErrorProvider = Provider<String?>((ref) =>
    ref.watch(realTimeRiverProvider).error);

final wrdIsLoadingProvider = Provider<bool>((ref) =>
    ref.watch(realTimeRiverProvider).isLoading);

final mergedCriticalCountProvider = Provider<int>((ref) {
  final stations = ref.watch(mergedStationsProvider);
  return stations.where((s) =>
      s.danger > 0 && s.current >= s.danger).length;
});
