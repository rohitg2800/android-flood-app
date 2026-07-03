// lib/widgets/map/map_legend.dart
// MapSourceLegend — collapsible overlay showing data sources + risk scale.
// v2.0: 5-colour risk scale, EXTREME tier added, colours synced with map_risk_helpers v2.0.
import 'package:flutter/material.dart';
import '../../models/river_station.dart';
import '../../providers/map_command_provider.dart';
import '../../theme/rx.dart';
import 'map_risk_helpers.dart';

class MapSourceLegend extends StatelessWidget {
  final SyncMeta syncMeta;
  final VoidCallback onClose;

  const MapSourceLegend({
    super.key,
    required this.syncMeta,
    required this.onClose,
  });

  static const _sources = [
    ('WRD_BIHAR', '🏛', 'Bihar Water Resources Dept'),
    ('CWC_FFEM', '🌊', 'Central Water Commission'),
    ('GLOFAS', '🛰', 'GloFAS Global Forecast'),
  ];

  // 5-tier risk scale — worst to best.
  // Labels match gaugeRiskFromLevels() output and riskLabel() in map_risk_helpers.
  static final _legend = [
    (DangerClass.extreme, 'EXTREME', '≥ HFL — Highest Flood Level'),
    (DangerClass.severe, 'CRITICAL', '≥ Danger Level'),
    (DangerClass.aboveNormal, 'WARNING', '≥ Warning Level'),
    (DangerClass.normal, 'NORMAL', 'Below Warning Level'),
  ];

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    return Container(
      width: 210,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: rc.cardBg.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rc.stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'DATA SOURCES',
                style: TextStyle(
                  color: rc.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onClose,
                child: Icon(Icons.close, size: 14, color: rc.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final (src, emoji, label) in _sources) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        src,
                        style: TextStyle(
                          color: rc.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(label,
                          style:
                              TextStyle(color: rc.textSecondary, fontSize: 10)),
                      Text(
                        'Updated: ${syncMeta.labelFor(src)}',
                        style: TextStyle(
                          color: rc.textSecondary.withValues(alpha: 0.6),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Divider(height: 12, color: rc.stroke),
          Text(
            'RISK SCALE',
            style: TextStyle(
              color: rc.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          for (final (dc, lbl, sublbl) in _legend)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: riskColor(dc, opacity: 0.85),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                          color: riskColorSolid(dc).withValues(alpha: 0.6)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lbl,
                          style: TextStyle(
                            color: riskColorSolid(dc),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          sublbl,
                          style: TextStyle(
                            color: rc.textSecondary,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
