// lib/providers/bihar_city_provider.dart  (v1.1)
//
// v1.1 (12 Jun 2026) — Fix 2 + Fix 3 from city-card load-time perf pass:
//
//   Fix 2 (consumer side):
//     biharCityProvider now calls s.byCity(city) — the O(1) index on
//     BiharLiveState — instead of the previous O(n) firstWhere scan.
//     The try/catch around firstWhere is also gone (no exception possible).
//
//   Fix 3 — biharCityLoadingProvider correctness:
//     Old: ref.watch(biharLiveProvider).isLoading
//     Problem: with Fix 1 in bihar_live_provider.dart, the provider is
//     AsyncLoading during the cold-start Completer suspend — correct.
//     But an additional edge-case existed: after the first data arrives,
//     if the station list is empty (partial engine result), the card
//     showed blank with isLoading=false.
//     New: loading = isLoading OR (hasValue && stations.isEmpty)
//     This keeps the shimmer visible until at least one station is ready.
//
//   biharCityLoadingProvider kept for backwards compat (same impl).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bihar_live_provider.dart';

/// Returns the [BiharStationData] for [city], or null if not in the list yet.
/// O(1) — uses the index built in BiharLiveState (v3.3).
final biharCityProvider =
    Provider.family<BiharStationData?, String>((ref, city) {
  return ref.watch(biharLiveProvider).maybeWhen(
        data: (s) => s.byCity(city),
        orElse: () => null,
      );
});

/// True while the live provider has no usable data yet.
/// Shows shimmer/spinner on city detail cards during cold-start AND
/// when data has arrived but the station list is still empty.
final biharCityLoadingProvider = Provider<bool>((ref) {
  return ref.watch(biharLiveProvider).when(
        loading: () => true,
        error: (_, __) => false,
        data: (s) => s.stations.isEmpty,
      );
});
