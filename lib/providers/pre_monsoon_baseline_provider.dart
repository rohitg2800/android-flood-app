// lib/providers/pre_monsoon_baseline_provider.dart  v1.0  (18 Jun 2026)
//
// Single source of truth for the pre-monsoon baseline feature:
//
//   kPreMonsoonBaselineRiskThreshold — double constant (22.0)
//     The minimum riskScore (0–100 ML scale) OR fill-% proxy value a station
//     must reach before it is shown during the pre-monsoon / low-water period.
//     22.0 ≈ level is at least 22 % of danger level — filters pure noise while
//     keeping genuinely elevated stations visible.
//
//   preMonsoonBaselineProvider — StateProvider<bool>
//     Toggle switch that enables / disables the baseline filter globally.
//     Persisted via SharedPreferences in settings_screen.dart (opt-in).
//     Default: false  (filter OFF — safe default, no surprise blank screens).
//
//   filteredBulkPredictionsProvider — Provider<List<FloodPrediction>>
//     Derives from biharBulkPredictionsProvider.  When the toggle is ON,
//     drops predictions whose riskScore < kPreMonsoonBaselineRiskThreshold.
//     Consumers (dashboard Risk Forecast Strip, future screens) watch this
//     instead of the raw biharBulkPredictionsProvider.

library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bihar_prediction_provider.dart';
import '../models/flood_prediction.dart';

// ── Threshold ─────────────────────────────────────────────────────────────────
/// Minimum riskScore (or fill-% proxy) required for a station to be visible
/// when the pre-monsoon baseline filter is active.
/// 22.0 = station water level is at least 22 % of its danger level.
const double kPreMonsoonBaselineRiskThreshold = 22.0;

// ── Toggle ────────────────────────────────────────────────────────────────────
/// Global on/off switch for the pre-monsoon baseline filter.
/// false = filter disabled (all stations / predictions shown).
/// true  = stations below [kPreMonsoonBaselineRiskThreshold] are suppressed.
final preMonsoonBaselineProvider = StateProvider<bool>((ref) => false);

// ── Filtered bulk predictions ─────────────────────────────────────────────────
/// Drop-in replacement for [biharBulkPredictionsProvider] that respects the
/// baseline toggle.  When the toggle is OFF it returns the full list unchanged
/// so existing behaviour is 100 % preserved.
final filteredBulkPredictionsProvider = Provider<List<FloodPrediction>>((ref) {
  final all       = ref.watch(biharBulkPredictionsProvider);
  final filterOn  = ref.watch(preMonsoonBaselineProvider);
  if (!filterOn) return all;
  return all
      .where((p) => p.riskScore >= kPreMonsoonBaselineRiskThreshold)
      .toList();
});
