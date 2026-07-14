import 'package:flutter/material.dart';

import '../../models/db/water_level_reading.dart';
import 'water_level_status_badge.dart';

class WaterLevelCard extends StatelessWidget {
  const WaterLevelCard({
    super.key,
    required this.reading,
    this.onTap,
  });

  final WaterLevelReading reading;
  final VoidCallback? onTap;

  String _statusLabel() {
    if (reading.waterLevel >= 4.0) return 'danger';
    if (reading.waterLevel >= 3.0) return 'warning';
    return reading.isVerified ? 'normal' : 'live';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text('Station ${reading.stationId}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Level: ${reading.waterLevel.toStringAsFixed(2)} m'),
            Text('Updated: ${reading.recordedAt.toLocal()}'),
            if (reading.dataSource != null)
              Text('Source: ${reading.dataSource}'),
          ],
        ),
        trailing: WaterLevelStatusBadge(
          label: _statusLabel(),
        ),
      ),
    );
  }
}
