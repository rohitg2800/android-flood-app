// lib/widgets/station_status_strip.dart
// Dashboard Live Status Strip — counts by FloodSeverity bucket.
// Chips now support an "active" selected state so the screen can
// highlight whichever severity is currently being filtered.
//
// API:
//   StationStatusStrip(
//     counts:         Map<FloodSeverity, int>,
//     lastSynced:     DateTime?,
//     isLoading:      bool,
//     activeFilter:   FloodSeverity?,   // null = show all (no chip highlighted)
//     onTap:          void Function(FloodSeverity)?,
//   )
import 'package:flutter/material.dart';
import '../theme/river_theme.dart';
import '../utils/flood_severity.dart';

class StationStatusStrip extends StatelessWidget {
  final Map<FloodSeverity, int> counts;
  final DateTime? lastSynced;
  final bool isLoading;
  final FloodSeverity? activeFilter; // NEW: which chip is selected
  final void Function(FloodSeverity)? onTap;

  const StationStatusStrip({
    super.key,
    required this.counts,
    this.lastSynced,
    this.isLoading = false,
    this.activeFilter,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppPalette.abyss2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.abyssStroke, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Chip(
            severity: FloodSeverity.normal,
            count: counts[FloodSeverity.normal] ?? 0,
            label: 'Normal',
            color: AppPalette.safe,
            isLoading: isLoading,
            isActive: activeFilter == FloodSeverity.normal,
            onTap: onTap,
          ),
          _Vr(),
          _Chip(
            severity: FloodSeverity.watch,
            count: counts[FloodSeverity.watch] ?? 0,
            label: 'Watch',
            color: AppPalette.cyan,
            isLoading: isLoading,
            isActive: activeFilter == FloodSeverity.watch,
            onTap: onTap,
          ),
          _Vr(),
          _Chip(
            severity: FloodSeverity.warning,
            count: counts[FloodSeverity.warning] ?? 0,
            label: 'Warning',
            color: AppPalette.warning,
            isLoading: isLoading,
            isActive: activeFilter == FloodSeverity.warning,
            onTap: onTap,
          ),
          _Vr(),
          _Chip(
            severity: FloodSeverity.danger,
            count: counts[FloodSeverity.danger] ?? 0,
            label: 'Danger',
            color: AppPalette.danger,
            isLoading: isLoading,
            isActive: activeFilter == FloodSeverity.danger,
            onTap: onTap,
          ),
          _Vr(),
          _Chip(
            severity: FloodSeverity.extreme,
            count: counts[FloodSeverity.extreme] ?? 0,
            label: 'Extreme',
            color: AppPalette.critical,
            isLoading: isLoading,
            isActive: activeFilter == FloodSeverity.extreme,
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final FloodSeverity severity;
  final int count;
  final String label;
  final Color color;
  final bool isLoading;
  final bool isActive; // true = this chip is the active filter
  final void Function(FloodSeverity)? onTap;

  const _Chip({
    required this.severity,
    required this.count,
    required this.label,
    required this.color,
    required this.isLoading,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap != null ? () => onTap!(severity) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          // Highlight background when active
          color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isActive
              ? Border.all(color: color.withValues(alpha: 0.55), width: 1.2)
              : Border.all(color: Colors.transparent, width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            isLoading
                ? Container(
                    width: 28,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppPalette.abyss3,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )
                : Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: color,
                      height: 1.1,
                    ),
                  ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isActive)
                  Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child:
                        Icon(Icons.filter_list_rounded, size: 9, color: color),
                  ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isActive ? color : AppPalette.textGrey,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Vr extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 30,
        color: AppPalette.abyssStroke,
      );
}
