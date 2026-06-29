import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:equinox_flood/core/theme/river_theme.dart" as core_theme;
import "package:equinox_flood/providers/pre_monsoon_baseline_provider.dart";
import "package:equinox_flood/models/flood_prediction.dart";
import "package:equinox_flood/screens/rainfall_forecast_screen.dart";
import "package:equinox_flood/screens/city_detail_screen.dart";

class RiskForecastStrip extends ConsumerWidget {
  const RiskForecastStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c     = core_theme.RiverTheme.of(context).colors;
    final preds = ref.watch(filteredBulkPredictionsProvider).take(5).toList();

    if (preds.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF818CF8).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF818CF8).withValues(alpha: 0.30)),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF818CF8), size: 15),
              ),
              const SizedBox(width: 8),
              Text(
                "RISK FORECAST",
                style: TextStyle(
                  color: c.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const RainfallForecastScreen())),
                child: Text(
                  "See all",
                  style: TextStyle(color: c.accent, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            itemCount: preds.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _RiskCard(
              pred: preds[i],
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => CityDetailScreen(
                  cityName: preds[i].station.split(" (").first,
                ),
              )),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _RiskCard extends StatelessWidget {
  final FloodPrediction pred;
  final VoidCallback onTap;
  const _RiskCard({required this.pred, required this.onTap});

  Color _sevColor() {
    switch (pred.severity.toUpperCase()) {
      case "CRITICAL": return const Color(0xFFFF4D5A);
      case "SEVERE":   return const Color(0xFFFF8C42);
      case "MODERATE": return const Color(0xFFFFC857);
      default:         return const Color(0xFF3ACC8A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c   = core_theme.RiverTheme.of(context).colors;
    final col = _sevColor();
    final bar = (pred.riskScore / 100).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 155,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: col.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: col.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: col.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: col.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    pred.severity,
                    style: TextStyle(color: col, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.4),
                  ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right_rounded, color: c.textMuted, size: 14),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              pred.station.split(" (").first,
              style: TextStyle(color: c.textPrimary, fontSize: 11, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              "24h: \${pred.predicted24h.toStringAsFixed(2)} m",
              style: TextStyle(color: c.textSecondary, fontSize: 10),
            ),
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: bar,
                minHeight: 4,
                backgroundColor: col.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(col),
              ),
            ),
          ],
        ),
      ),
    );
  }
}