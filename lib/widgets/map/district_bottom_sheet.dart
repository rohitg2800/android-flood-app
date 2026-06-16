// lib/widgets/map/district_bottom_sheet.dart
import 'package:flutter/material.dart';
import '../../services/alert_engine.dart';
import '../../models/river_station.dart';
import '../../theme/app_palette.dart';

class DistrictBottomSheet extends StatelessWidget {
  final String             district;
  final List<RiverStation> stations;
  const DistrictBottomSheet(
      {super.key, required this.district, required this.stations});

  AlertSeverity get _worst {
    AlertSeverity w = AlertSeverity.info;
    for (final s in stations) {
      final sev = _sev(s);
      if (sev.priority > w.priority) w = sev;
    }
    return w;
  }

  static AlertSeverity _sev(RiverStation s) {
    if (!s.hasData)                              return AlertSeverity.info;
    if (s.hfl > 0 && s.current >= s.hfl)        return AlertSeverity.emergency;
    if (s.danger > 0 && s.current >= s.danger)   return AlertSeverity.emergency;
    if (s.warning > 0 && s.current >= s.warning) return AlertSeverity.critical;
    if (s.progressPct >= 0.75)                   return AlertSeverity.warning;
    return AlertSeverity.info;
  }

  static Color _sevColor(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.emergency: return AppPalette.critical;
      case AlertSeverity.critical:  return AppPalette.danger;
      case AlertSeverity.warning:   return AppPalette.warning;
      case AlertSeverity.info:      return AppPalette.safe;
    }
  }

  static String _sevLabel(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.emergency: return 'EMERGENCY';
      case AlertSeverity.critical:  return 'CRITICAL';
      case AlertSeverity.warning:   return 'WARNING';
      case AlertSeverity.info:      return 'INFO';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use Theme.of() — no dependency on RiverColors.surface
    final cs    = Theme.of(context).colorScheme;
    final worst = _worst;
    final color = _sevColor(worst);

    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      maxChildSize:     0.9,
      minChildSize:     0.25,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(district,
                        style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:  color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_sevLabel(worst),
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: ctrl,
                itemCount: stations.length,
                itemBuilder: (_, i) {
                  final s   = stations[i];
                  final sev = _sev(s);
                  final c   = _sevColor(sev);
                  return ListTile(
                    leading: Icon(Icons.water, color: c),
                    title: Text(s.station,
                        style: TextStyle(color: cs.onSurface)),
                    subtitle: Text(
                        '${s.river} · ${s.current.toStringAsFixed(2)} m '
                        '/ DL ${s.danger.toStringAsFixed(2)} m',
                        style: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 12)),
                    trailing: Text(_sevLabel(sev),
                        style: TextStyle(
                            color: c,
                            fontWeight: FontWeight.bold,
                            fontSize: 11)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
