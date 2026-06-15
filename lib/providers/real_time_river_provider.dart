// lib/providers/real_time_river_provider.dart
// Fix: biharLiveProvider is AsyncNotifierProvider → returns AsyncValue<BiharLiveState>.
// All .stations / .isLoading / .error must unwrap via .whenData / .valueOrNull.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/river_station.dart';
import '../providers/bihar_live_provider.dart';
import 'stubs.dart';

export 'stubs.dart' show dataFetchStationsProvider;

// ── helpers ──────────────────────────────────────────────────────────────────
/// Map a BiharStationData → RiverStation for consumers that expect RiverStation.
RiverStation _toRiverStation(BiharStationData s) => RiverStation(
  station:      s.city,
  river:        s.river,
  district:     s.district,
  state:        s.state,
  current:      s.currentLevel ?? 0,
  danger:       s.dangerLevel  ?? 0,
  warning:      s.warningLevel ?? 0,
  riskLevel:    s.riskLabel,
  source:       s.source,
);

// ── wrd / CWC stations provider ──────────────────────────────────────────────
/// Raw WRD stations from the live Bihar provider.
final wrdRiverStationsProvider = Provider<List<RiverStation>>((ref) {
  final asyncState = ref.watch(biharLiveProvider);          // AsyncValue<BiharLiveState>
  final liveState  = asyncState.valueOrNull;                // BiharLiveState?
  if (liveState == null) return const [];
  return liveState.stations.map(_toRiverStation).toList();
});

/// Alias kept for backward compat.
final wrdStationsProvider = wrdRiverStationsProvider;

// ── merged stations ───────────────────────────────────────────────────────────
/// Merged station list: WRD base + DataFetch overlay.
final mergedStationsProvider = Provider<List<RiverStation>>((ref) {
  final base      = ref.watch(wrdRiverStationsProvider);
  final dfStations = ref.watch(dataFetchStationsProvider);

  if (dfStations.isEmpty) return base;

  final dfMap = <String, RiverStation>{
    for (final s in dfStations) s.station: s,
  };

  return [
    for (final s in base)       dfMap[s.station] ?? s,
    for (final s in dfStations)
      if (!base.any((b) => b.station == s.station)) s,
  ];
});

// ── merged river result (loading / error state wrapper) ──────────────────────
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
  final asyncState = ref.watch(biharLiveProvider);
  return asyncState.when(
    data:    (state) => RealTimeRiverState(
      stations:  state.stations.map(_toRiverStation).toList(),
      isLoading: false,
    ),
    loading: ()         => const RealTimeRiverState(isLoading: true),
    error:   (e, _)     => RealTimeRiverState(error: e.toString()),
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
