// lib/widgets/ml_card_test_export.dart  v2
// Fixed:
//   pred.stationName    → pred.station
//   pred.predictedLevel → pred.predicted24h
//   pred.confidence     → pred.confidencePct (already 0–100, no *100 needed)
//   pred.isOffline      → !pred.fromBackend
import 'package:flutter/material.dart';
import '../models/flood_prediction.dart';

class MlCardTestExport extends StatelessWidget {
  final FloodPrediction pred;
  const MlCardTestExport({super.key, required this.pred});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.35)),
        ),
        child: DefaultTextStyle(
          style: theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                pred.station,
                key: const ValueKey('ml_card_stationName'),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Severity: ${pred.severity}',
                key: const ValueKey('ml_card_severity'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Predicted: ${pred.predicted24h.toStringAsFixed(1)} m',
                      key: const ValueKey('ml_card_predictedLevel'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Danger: ${pred.dangerLevel.toStringAsFixed(1)} m',
                key: const ValueKey('ml_card_dangerLevel'),
              ),
              const Spacer(),
              Text(
                'Trend: ${pred.trend}',
                key: const ValueKey('ml_card_trend'),
              ),
              const SizedBox(height: 6),
              Text(
                // confidencePct is already 0–100, no need to multiply
                'Confidence: ${pred.confidencePct.toStringAsFixed(0)}%',
                key: const ValueKey('ml_card_confidence'),
              ),
              const SizedBox(height: 6),
              Text(
                'Updated: ${pred.updatedAt.toIso8601String().split("T").first}',
                key: const ValueKey('ml_card_updatedAt'),
              ),
              const SizedBox(height: 6),
              Text(
                // isOffline not a field — derive from fromBackend
                !pred.fromBackend ? 'Mode: Offline' : 'Mode: Online',
                key: const ValueKey('ml_card_isOffline'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
