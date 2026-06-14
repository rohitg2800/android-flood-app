// lib/widgets/map/district_bottom_sheet.dart
// PHASE 4B — Bottom sheet shown when user taps a district tile on the heatmap
//
// Shows:
//   • District name + worst severity badge
//   • Station count summary line
//   • Scrollable list of StationMiniCards for each station in that district
library;

import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/river_station.dart';
import '../../theme/app_palette.dart';
import '../../services/alert_engine.dart';

class DistrictBottomSheet extends StatelessWidget {
  final String            districtName;
  final List<RiverStation> stations;

  const DistrictBottomSheet({
    super.key,
    required this.districtName,
    required this.stations,
  });

  AlertSeverity get _worst {
    AlertSeverity w = AlertSeverity.info;
    for (final s in stations) {
      final sev = _sev(s);
      if (sev.priority > w.priority) w = sev;
    }
    return w;
  }

  static AlertSeverity _sev(RiverStation s) {
    if (s.hfl > 0 && s.current >= s.hfl)       return AlertSeverity.emergency;
    if (s.danger > 0 && s.current >= s.danger)  return AlertSeverity.emergency;
    if (s.warning > 0 && s.current >= s.warning) return AlertSeverity.critical;
    if (s.progressPct >= 0.75)                  return AlertSeverity.warning;
    return AlertSeverity.info;
  }

  static Color _sevColor(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.emergency: return AppPalette.critical;
      case AlertSeverity.critical:  return AppPalette.danger;
      case AlertSeverity.warning:   return AppPalette.warning;
      default:                      return AppPalette.safe;
    }
  }

  static String _sevLabel(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.emergency: return 'EMERGENCY';
      case AlertSeverity.critical:  return 'CRITICAL';
      case AlertSeverity.warning:   return 'WARNING';
      default:                      return 'NORMAL';
    }
  }

  @override
  Widget build(BuildContext context) {
    final worst      = _worst;
    final worstColor = _sevColor(worst);
    final aboveDanger = stations.where(
        (s) => s.danger > 0 && s.current >= s.danger).length;
    final aboveWarn  = stations.where(
        (s) => s.warning > 0 && s.current >= s.warning).length;

    return DraggableScrollableSheet(
      initialChildSize: 0.52,
      minChildSize:     0.3,
      maxChildSize:     0.92,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color:        AppPalette.abyss1,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(
              color: worstColor.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
        ),
        child: Column(
          children: [
            // ── Handle ──────────────────────────────────────────────────────
            const SizedBox(height: 10),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppPalette.abyssStroke,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),

            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          districtName,
                          style: const TextStyle(
                            color:      Colors.white,
                            fontSize:   20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          stations.isEmpty
                              ? 'No stations'
                              : '${stations.length} station${stations.length == 1 ? "" : "s"}'  
                                '${aboveDanger > 0 ? "  •  $aboveDanger above danger" : ""}'  
                                '${aboveWarn > 0 && aboveDanger == 0 ? "  •  $aboveWarn above warning" : ""}',
                          style: const TextStyle(
                              color: AppPalette.textGrey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  // Severity badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color:        worstColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border:       Border.all(
                          color: worstColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      _sevLabel(worst),
                      style: TextStyle(
                        color:      worstColor,
                        fontSize:   11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Divider(
                height: 1,
                color: AppPalette.abyssStroke.withValues(alpha: 0.5)),
            const SizedBox(height: 8),

            // ── Station list ───────────────────────────────────────────────
            Expanded(
              child: stations.isEmpty
                  ? const Center(
                      child: Text('No stations in this district',
                          style: TextStyle(
                              color: AppPalette.textGrey, fontSize: 13)),
                    )
                  : ListView.builder(
                      controller:  ctrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      itemCount:   stations.length,
                      itemBuilder: (_, i) =>
                          _StationMiniCard(station: stations[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────────
// Single station row inside the sheet
// ───────────────────────────────────────────────────────────────────────────────
class _StationMiniCard extends StatelessWidget {
  final RiverStation station;
  const _StationMiniCard({required this.station});

  @override
  Widget build(BuildContext context) {
    final sev   = DistrictBottomSheet._sev(station);
    final color = DistrictBottomSheet._sevColor(sev);
    final pct   = (station.progressPct * 100).clamp(0, 100).toStringAsFixed(0);
    final updatedStr = station.lastUpdated != null
        ? timeago.format(station.lastUpdated!)
        : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        AppPalette.abyss2,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(
          color: color.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          // Level bar
          Container(
            width: 4, height: 44,
            decoration: BoxDecoration(
              color:        color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),

          // Name + river
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  station.station,
                  style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   13,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  station.river,
                  style: const TextStyle(
                      color: AppPalette.textGrey, fontSize: 11),
                ),
              ],
            ),
          ),

          // Level + pct
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${station.current.toStringAsFixed(2)} m',
                style: TextStyle(
                  color:      color,
                  fontSize:   15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '$pct% • $updatedStr',
                style: const TextStyle(
                    color: AppPalette.textGrey, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
