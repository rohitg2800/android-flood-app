import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equinox_flood/providers/pre_monsoon_baseline_provider.dart';
import 'package:equinox_flood/models/flood_prediction.dart';
import '../domain/forecast_item.dart';

ForecastSeverity _toSeverity(String raw) {
  switch (raw.toUpperCase()) {
    case 'CRITICAL': return ForecastSeverity.critical;
    case 'SEVERE':   return ForecastSeverity.severe;
    case 'MODERATE': return ForecastSeverity.moderate;
    default:         return ForecastSeverity.normal;
  }
}

final forecastItemsProvider = Provider<List<ForecastItem>>((ref) {
  final preds = ref.watch(filteredBulkPredictionsProvider);
  return preds.map((p) => ForecastItem(
    station:      p.station,
    river:        p.river ?? '',
    predicted24h: p.predicted24h,
    predicted48h: p.predicted48h,
    predicted72h: p.predicted72h,
    riskScore:    p.riskScore,
    severity:     _toSeverity(p.severity),
  )).toList();
});

final topRiskForecastProvider = Provider<List<ForecastItem>>((ref) {
  return ref.watch(forecastItemsProvider)
      .where((f) => f.severity != ForecastSeverity.normal)
      .take(5)
      .toList();
});