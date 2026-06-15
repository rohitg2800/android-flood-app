// lib/widgets/city_card.dart
// CityCard — displays a city's live flood data as a compact grid card.
// Used by DashboardScreen.
library;

import 'package:flutter/material.dart';
import '../providers/bihar_live_provider.dart';
import '../theme/river_theme.dart';

class CityCard extends StatelessWidget {
  final Map<String, dynamic> cityMeta;
  final List<BiharStationData>? stationData;

  const CityCard({
    super.key,
    required this.cityMeta,
    required this.stationData,
  });

  @override
  Widget build(BuildContext context) {
    final t    = RiverColors.of(context);
    final name = cityMeta['city'] as String? ?? 'Unknown';
    final data = stationData ?? [];

    Color cardColor = t.cardBg;
    String label    = 'SAFE';

    if (data.any((s) => s.isCritical)) {
      cardColor = AppPalette.critical.withOpacity(0.12);
      label     = 'CRITICAL';
    } else if (data.any((s) => s.isSevere)) {
      cardColor = AppPalette.danger.withOpacity(0.12);
      label     = 'SEVERE';
    } else if (data.any((s) => s.isWarning)) {
      cardColor = AppPalette.warning.withOpacity(0.12);
      label     = 'WARNING';
    }

    final labelColor = AppPalette.statusColor(label);

    return Card(
      color:  cardColor,
      margin: EdgeInsets.zero,
      shape:  RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: t.stroke, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment:  MainAxisAlignment.spaceBetween,
          children: [
            Text(
              name,
              style: TextStyle(
                color:      t.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize:   14,
              ),
              maxLines:  1,
              overflow:  TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${data.length} station${data.length == 1 ? '' : 's'}',
                  style: TextStyle(color: t.textSecondary, fontSize: 11),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color:        labelColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border:       Border.all(color: labelColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color:      labelColor,
                      fontSize:   10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
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
