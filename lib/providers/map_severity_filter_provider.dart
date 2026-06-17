// lib/providers/map_severity_filter_provider.dart
//
// Severity filter state for BiharRiverMapScreen.
//
// activeFiltersProvider  — Set<DangerClass> of classes to SHOW.
//   Empty set = show ALL (no filter active).
//   Non-empty = show only those classes.
//
// hideNormalProvider     — bool; when true, DangerClass.normal is always
//   excluded from the visible set regardless of activeFilters.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/river_station.dart';

// ── Active filter set ─────────────────────────────────────────────────────────
class ActiveFiltersNotifier extends StateNotifier<Set<DangerClass>> {
  ActiveFiltersNotifier() : super(const {});

  /// Toggle a class on/off. If result would be all-4, treat as "show all".
  void toggle(DangerClass dc) {
    final next = Set<DangerClass>.from(state);
    if (next.contains(dc)) {
      next.remove(dc);
    } else {
      next.add(dc);
    }
    // All 4 selected == same as no filter
    if (next.length == DangerClass.values.length) {
      state = const {};
    } else {
      state = next;
    }
  }

  void clear() => state = const {};
}

final activeFiltersProvider =
    StateNotifierProvider<ActiveFiltersNotifier, Set<DangerClass>>(
  (ref) => ActiveFiltersNotifier(),
);

// ── Hide-NORMAL toggle ────────────────────────────────────────────────────────
class HideNormalNotifier extends StateNotifier<bool> {
  HideNormalNotifier() : super(false);
  void toggle() => state = !state;
  void clear()  => state = false;
}

final hideNormalProvider =
    StateNotifierProvider<HideNormalNotifier, bool>(
  (ref) => HideNormalNotifier(),
);

// ── Computed: effective visible set ──────────────────────────────────────────
/// Returns the Set<DangerClass> that should be SHOWN on the map.
/// - If activeFilters is empty and hideNormal is false → null (= show all)
/// - Otherwise returns the restricted set.
final effectiveVisibleClassesProvider = Provider<Set<DangerClass>?>((ref) {
  final active     = ref.watch(activeFiltersProvider);
  final hideNormal = ref.watch(hideNormalProvider);

  if (active.isEmpty && !hideNormal) return null; // no filter

  final base = active.isEmpty
      ? Set<DangerClass>.from(DangerClass.values)
      : Set<DangerClass>.from(active);

  if (hideNormal) base.remove(DangerClass.normal);
  return base;
});
