// lib/widgets/data_quality_widgets.dart
// Drop-in UI components for Data Stale / Source Error states.
// Import and use in StationCard, DashboardWidgets, and any screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/source_policy_provider.dart';
import '../services/data_validator.dart';
import '../theme/river_theme.dart';

// ─── 1. DataQualityBadge ─────────────────────────────────────────────────────
//
// Tiny chip for StationCard header row.
// Renders nothing when quality == fresh — zero cost.
//
// Usage:
//   Row(children: [
//     Text(station.site),
//     const SizedBox(width: 6),
//     DataQualityBadge(quality: q, failure: f),
//   ])

class DataQualityBadge extends StatelessWidget {
  final DataQualityState quality;
  final ValidationFailure? failure;

  const DataQualityBadge({
    super.key,
    required this.quality,
    this.failure,
  });

  @override
  Widget build(BuildContext context) {
    if (quality == DataQualityState.fresh) return const SizedBox.shrink();

    final isStale = quality == DataQualityState.stale;
    final color = isStale ? AppPalette.warning : AppPalette.danger;

    return Tooltip(
      message: failure?.detail ?? quality.name,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          border: Border.all(color: color.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isStale ? Icons.access_time_outlined : Icons.error_outline,
              color: color,
              size: 10,
            ),
            const SizedBox(width: 3),
            Text(
              failure?.label ?? (isStale ? 'STALE' : 'ERR'),
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 2. DataQualityOverlay ────────────────────────────────────────────────────
//
// Wraps any card widget. Adds a thin top-strip indicator when not fresh.
// Does NOT hide the underlying data — the overlay is purely additive.
//
// Usage:
//   DataQualityOverlay(
//     quality: quality,
//     failure: failure,
//     child: YourExistingStationCard(),
//   )

class DataQualityOverlay extends StatelessWidget {
  final DataQualityState quality;
  final ValidationFailure? failure;
  final Widget child;

  const DataQualityOverlay({
    super.key,
    required this.quality,
    required this.failure,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (quality == DataQualityState.fresh) return child;

    final isStale = quality == DataQualityState.stale;
    final color = isStale ? AppPalette.warning : AppPalette.danger;
    final message = failure?.detail ??
        (isStale ? 'Data may be outdated' : 'Source error — data unreliable');

    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              border: Border(
                bottom: BorderSide(color: color.withValues(alpha: 0.4)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isStale ? Icons.history : Icons.cloud_off_outlined,
                  color: color,
                  size: 11,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 3. FallbackSourceBanner ─────────────────────────────────────────────────
//
// App-level subtle banner. Subscribe to fallbackBannerProvider — shows only
// when a fallback source was used. Dismissible.
//
// Usage (top of Scaffold body):
//   Column(children: [
//     const FallbackSourceBanner(),
//     Expanded(child: YourMainContent()),
//   ])

class FallbackSourceBanner extends ConsumerWidget {
  const FallbackSourceBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(fallbackBannerProvider);
    if (message == null) return const SizedBox.shrink();

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: Material(
        color: AppPalette.warning.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.swap_horiz_rounded,
                  color: AppPalette.warning, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppPalette.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () =>
                    ref.read(sourcePolicyProvider.notifier).dismissBanner(),
                child: const Icon(Icons.close,
                    color: AppPalette.warning, size: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 4. Inline quality helper (no provider needed) ───────────────────────────
//
// Use inside StationCard.build() to get quality state from raw field values
// without subscribing to any provider. This keeps StationCard stateless.

DataQualityState stationQualityInline({
  required double currentLevel,
  required DateTime fetchedAt,
}) {
  final age = DateTime.now().difference(fetchedAt);
  if (age > const Duration(minutes: 30)) return DataQualityState.stale;
  if (currentLevel < 0.5 || currentLevel > 250)
    return DataQualityState.sourceError;
  return DataQualityState.fresh;
}
