// lib/widgets/city_card.dart
//
// CityCard — compact dashboard card showing live river-level data
// for a monitored city in Bihar.

import 'package:flutter/material.dart';

import '../providers/bihar_live_provider.dart';

class CityCard extends StatelessWidget {
  final Map<String, dynamic> cityMeta;
  final BiharStationData?    stationData;

  const CityCard({
    super.key,
    required this.cityMeta,
    required this.stationData,
  });

  @override
  Widget build(BuildContext context) {
    final name   = cityMeta['city'] as String? ?? 'Unknown';
    final river  = cityMeta['river'] as String? ?? '';
    final data   = stationData;

    final Color color;
    final String risk;
    if (data == null) {
      color = Colors.grey;
      risk  = 'NO DATA';
    } else if (data.isCritical) {
      color = Colors.red;
      risk  = data.riskLabel;
    } else if (data.isSevere) {
      color = Colors.deepOrange;
      risk  = data.riskLabel;
    } else if (data.isWarning) {
      color = Colors.orange;
      risk  = data.riskLabel;
    } else {
      color = Colors.green;
      risk  = data.riskLabel;
    }

    final level = data?.currentLevel;
    final dan   = data?.dangerLevel;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // City name + risk badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: color.withOpacity(0.5)),
                  ),
                  child: Text(
                    risk,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // River name
            if (river.isNotEmpty)
              Text(
                river,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const Spacer(),
            // Level bar
            if (level != null && dan != null && dan > 0) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: (level / dan).clamp(0.0, 1.0),
                  backgroundColor: color.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 6),
            ],
            // Numeric levels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  level != null ? '${level.toStringAsFixed(2)} m' : '—',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (dan != null)
                  Text(
                    'DL ${dan.toStringAsFixed(2)} m',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
