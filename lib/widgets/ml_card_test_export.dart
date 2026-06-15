import 'package:flutter/material.dart';

import '../models/flood_prediction.dart';

/// Minimal test/export widget used by golden tests.
///
/// This file intentionally keeps UI stable and deterministic.
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
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.35)),
        ),
        child: DefaultTextStyle(
          style: theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                pred.stationName,
                key: const ValueKey('ml_card_stationName'),
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
                      'Predicted: ${pred.predictedLevel.toStringAsFixed(1)} m',
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
                'Confidence: ${(pred.confidence * 100).toStringAsFixed(0)}%',
                key: const ValueKey('ml_card_confidence'),
              ),
              const SizedBox(height: 6),
              Text(
                'Updated: ${pred.updatedAt.toIso8601String().split("T").first}',
                key: const ValueKey('ml_card_updatedAt'),
              ),
              const SizedBox(height: 6),
              Text(
                pred.isOffline ? 'Mode: Offline' : 'Mode: Online',
                key: const ValueKey('ml_card_isOffline'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

