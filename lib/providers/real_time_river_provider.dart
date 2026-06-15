// lib/providers/real_time_river_provider.dart
// RESTORED: full provider set that merged_stations_provider.dart re-exports.
//
// Fix (15 Jun 2026): biharLiveProvider is AsyncNotifierProvider<..., BiharLiveState>
// so ref.watch() returns AsyncValue<BiharLiveState>, NOT BiharLiveState directly.
// Use .valueOrNull to safely unwrap without throwing on loading/error states.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/river_station.dart';
import '../providers/bihar_live_provider.dart';
import 'stubs.dart';

export 'stubs.dart' show dataFetchStationsProvider;

// ── wrd / CWC stations provider ──────────────────────────────────────────────────────────────────
/// Raw WRD stations from the live Bihar provider.
final wrdRiverStationsProvider = Provider<List<RiverStation>>((ref) {
  // biharLiveProvider is AsyncNotifierProvider → AsyncValue<BiharLiveState>
  // .valueOrNull returns null while loading/error, empty list is safe fallback.
  final liveState = ref.watch(biharLiveProvider);
  return liveState.valueOrNull?.stations
      .map((s) => RiverStation(
            city:       s.city,
            state:      s.state,
            river:      s.river,
            station:    s.city, // BiharStationData.city == station name
            current:    s.currentLevel  ?? 0,
            warning:    s.warningLevel  ?? 0,
            danger:     s.dangerLevel   ?? 0,
            hfl:        0,
            isLive:     s.source == 'LIVE',
            dataSource: s.source,
          ))
      .toList() ?? const [];
});

/// Alias kept for backward compat.
final wrdStationsProvider = wrdRiverStationsProvider;

// ── merged stations ───────────────────────────────────────────────────────────────────────────────────
/// Merged station list: WRD base + DataFetch overlay.
/// This is the canonical provider that all map/alert screens consume.
final mergedStationsProvider = Provider<List<RiverStation>>((ref) {
  final base       = ref.watch(wrdRiverStationsProvider);
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

// ── merged river result (loading/error state wrapper) ─────────────────────────────────────────
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
    // .valueOrNull’s .stations are BiharStationData; for this wrapper we only
    // need the count so expose the already-mapped wrdRiverStationsProvider list.
    stations:  ref.watch(wrdRiverStationsProvider),
    // AsyncValue exposes .isLoading and .error natively.
    isLoading: liveState.isLoading,
    error:     liveState.error?.toString(),
  );
});

// ── error / loading helpers ───────────────────────────────────────────────────────────────────────────────
final wrdErrorProvider = Provider<String?>((ref) =>
    ref.watch(realTimeRiverProvider).error);

final wrdIsLoadingProvider = Provider<bool>((ref) =>
    ref.watch(realTimeRiverProvider).isLoading);

final mergedCriticalCountProvider = Provider<int>((ref) {
  final stations = ref.watch(mergedStationsProvider);
  return stations.where((s) =>
      s.danger > 0 && s.current >= s.danger).length;
});
