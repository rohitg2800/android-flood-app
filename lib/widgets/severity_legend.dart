// ─────────────────────────────────────────────────────────────────────────────
//  SeverityLegend  —  Reusable flood severity color legend
//  Use on Map screen, Dashboard, District view, etc.
//
//  Usage:
//    SeverityLegend()                    // horizontal, all 5 levels
//    SeverityLegend.compact()            // icon-only row
//    SeverityLegend(showHindi: true)     // with Hindi labels
//    SeverityLegend(vertical: true)      // vertical list layout
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../theme/river_theme.dart';
import '../utils/flood_severity_helper.dart';

class SeverityLegend extends StatelessWidget {
  const SeverityLegend({
    super.key,
    this.showHindi = false,
    this.vertical = false,
    this.compact = false,
    this.levels,
  });

  /// Show only specific severity levels (null = all 5)
  final List<FloodSeverity>? levels;
  final bool showHindi;
  final bool vertical;
  final bool compact;

  factory SeverityLegend.compact() => const SeverityLegend(compact: true);

  @override
  Widget build(BuildContext context) {
    final rc = RiverColors.of(context);
    final visibleLevels = levels ?? FloodSeverity.values;

    final items = visibleLevels
        .map((s) => _LegendItem(
              severity: s,
              showHindi: showHindi,
              compact: compact,
            ))
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppPalette.abyssGlass,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.abyssStroke, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'SEVERITY LEVELS',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: rc.textSecondary,
                ),
              ),
            ),
          vertical
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: items
                      .map((w) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: w,
                          ))
                      .toList(),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: items
                      .map((w) => Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: w,
                          ))
                      .toList(),
                ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.severity,
    required this.showHindi,
    required this.compact,
  });

  final FloodSeverity severity;
  final bool showHindi;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = FloodSeverityHelper.color(severity);
    final lbl = showHindi
        ? FloodSeverityHelper.labelHindi(severity)
        : FloodSeverityHelper.label(severity);

    if (compact) {
      return Tooltip(
        message: lbl,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 4)
            ],
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 5)
            ],
          ),
        ),
        const SizedBox(width: 5),
        Text(
          lbl,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: c,
          ),
        ),
      ],
    );
  }
}
