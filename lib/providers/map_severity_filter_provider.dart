// lib/providers/map_severity_filter_provider.dart  v2.1
//
// Severity + baseline filter state for BiharRiverMapScreen and Dashboard.
//
// activeFiltersProvider        — Set<DangerClass> of classes to SHOW.
//   Empty set = show ALL (no filter active).
//   Non-empty = show only those classes.
//
// hideNormalProvider           — bool; when true, DangerClass.normal is always
//   excluded from the visible set regardless of activeFilters.
//
// preMonsoonBaselineProvider   — bool; when true, stations whose riskScore is
//   below kPreMonsoonBaselineRiskThreshold are hidden.  Designed for the
//   Jun 1–14 pre-monsoon swell window where rivers naturally rise to ~20-22%
//   of their danger level without any flood risk.
//
// filteredBulkPredictionsProvider — derived List<FloodPrediction> with ALL
//   three filters applied; consume this instead of biharBulkPredictionsProvider
//   in any UI that supports filtering.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/river_station.dart';
import '../models/flood_prediction.dart';
import 'bihar_prediction_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Pre-monsoon baseline constants
// ─────────────────────────────────────────────────────────────────────────────

/// Stations with riskScore below this value are suppressed when the
/// pre-monsoon baseline filter is active.
const double kPreMonsoonBaselineRiskThreshold = 22.0;

/// Returns true when today falls in the Jun 1–14 pre-monsoon window.
bool isPreMonsoonPeriod([DateTime? now]) {
  final d = now ?? DateTime.now();
  return d.month == 6 && d.day >= 1 && d.day <= 14;
}

// ─────────────────────────────────────────────────────────────────────────────
// Active filter set
// ─────────────────────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
// Hide-NORMAL toggle
// ─────────────────────────────────────────────────────────────────────────────
class HideNormalNotifier extends StateNotifier<bool> {
  HideNormalNotifier() : super(false);
  void toggle() => state = !state;
  void clear() => state = false;
}

final hideNormalProvider = StateNotifierProvider<HideNormalNotifier, bool>(
  (ref) => HideNormalNotifier(),
);

// ─────────────────────────────────────────────────────────────────────────────
// Pre-monsoon baseline filter toggle
// ─────────────────────────────────────────────────────────────────────────────

/// When true, stations below [kPreMonsoonBaselineRiskThreshold] are hidden.
/// The UI should auto-suggest enabling this (not auto-enable) when
/// [isPreMonsoonPeriod()] returns true.
class PreMonsoonBaselineNotifier extends StateNotifier<bool> {
  PreMonsoonBaselineNotifier() : super(false);
  void toggle() => state = !state;
  void enable() => state = true;
  void disable() => state = false;
}

final preMonsoonBaselineProvider =
    StateNotifierProvider<PreMonsoonBaselineNotifier, bool>(
  (ref) => PreMonsoonBaselineNotifier(),
);

// ─────────────────────────────────────────────────────────────────────────────
// Computed: effective visible DangerClass set (map layer filter)
// ─────────────────────────────────────────────────────────────────────────────
/// Returns the Set<DangerClass> that should be SHOWN on the map.
/// - null  → show all (no filter active)
/// - non-null → restricted set
///
/// Note: the pre-monsoon baseline filter operates on riskScore, not DangerClass,
/// so it is NOT reflected here — apply it via [filteredBulkPredictionsProvider].
final effectiveVisibleClassesProvider = Provider<Set<DangerClass>?>((ref) {
  final active = ref.watch(activeFiltersProvider);
  final hideNormal = ref.watch(hideNormalProvider);

  if (active.isEmpty && !hideNormal) return null; // no filter

  final base = active.isEmpty
      ? Set<DangerClass>.from(DangerClass.values)
      : Set<DangerClass>.from(active);

  if (hideNormal) base.remove(DangerClass.normal);
  return base;
});

// ─────────────────────────────────────────────────────────────────────────────
// filteredBulkPredictionsProvider
//
// Single source of truth for filtered FloodPrediction list.
// Applies all three active filters:
//   1. activeFilters  (DangerClass)
//   2. hideNormal
//   3. preMonsoonBaseline (riskScore < threshold)
//
// Consumers: DashboardScreen Risk Forecast Strip, BiharRiverMapScreen
// ─────────────────────────────────────────────────────────────────────────────
final filteredBulkPredictionsProvider = Provider<List<FloodPrediction>>((ref) {
  final all = ref.watch(biharBulkPredictionsProvider);
  final active = ref.watch(activeFiltersProvider);
  final hideNormal = ref.watch(hideNormalProvider);
  final baselineFilter = ref.watch(preMonsoonBaselineProvider);

  return all.where((pred) {
    // ── 1. Severity class filter ────────────────────────────────────────────
    if (active.isNotEmpty) {
      final dc = _severityToDangerClass(pred.severity);
      if (!active.contains(dc)) return false;
    }

    // ── 2. Hide NORMAL ─────────────────────────────────────────────────────
    if (hideNormal && pred.severity == 'LOW') return false;

    // ── 3. Pre-monsoon baseline: suppress sub-threshold noise ───────────────
    if (baselineFilter && pred.riskScore < kPreMonsoonBaselineRiskThreshold) {
      return false;
    }

    return true;
  }).toList();
});

// ── Severity string → DangerClass mapping ────────────────────────────────────
// Matches the DangerClass enum: { normal, aboveNormal, severe, extreme }
DangerClass _severityToDangerClass(String severity) {
  return switch (severity.toUpperCase()) {
    'CRITICAL' => DangerClass.extreme,
    'SEVERE' => DangerClass.severe,
    'MODERATE' => DangerClass.aboveNormal,
    _ => DangerClass.normal,
  };
}
