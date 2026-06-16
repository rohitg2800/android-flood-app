// lib/widgets/map/map_telemetry_sheet.dart
// MapTelemetrySheet — bottom sheet listing all live stations.
// Tapping a row flies the map to that station's coordinates.
import 'package:flutter/material.dart';
import '../../models/river_station.dart';
import '../../theme/rx.dart';
import 'map_risk_helpers.dart';

class MapTelemetrySheet extends StatelessWidget {
  final List<RiverStation>          stations;
  final VoidCallback                onClose;
  final void Function(RiverStation) onTap;

  const MapTelemetrySheet({
    super.key,
    required this.stations,
    required this.onClose,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.45,
          ),
          decoration: BoxDecoration(
            color: rc.cardBg,
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset:     const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top border line — replaces Border(top:) to avoid borderRadius conflict
              Container(height: 1, color: rc.stroke),
              // Drag handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color:        rc.stroke,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: [
                    Icon(Icons.sensors_rounded,
                        color: rc.accent, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'LIVE TELEMETRY  (${stations.length} stations)',
                      style: TextStyle(
                        color:         rc.textPrimary,
                        fontSize:      12,
                        fontWeight:    FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onClose,
                      child: Icon(Icons.close_rounded,
                          color: rc.textSecondary, size: 18),
                    ),
                  ],
                ),
              ),
              // Station list
              Flexible(
                child: stations.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No station data available.',
                          style: TextStyle(
                              color: rc.textSecondary, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        itemCount: stations.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: rc.stroke),
                        itemBuilder: (_, i) {
                          final s  = stations[i];
                          final dc = s.dangerClass;
                          return InkWell(
                            onTap: () => onTap(s),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10, height: 10,
                                    decoration: BoxDecoration(
                                      color: riskColorSolid(dc),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s.station,
                                          style: TextStyle(
                                            color:      rc.textPrimary,
                                            fontSize:   13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${s.river}  •  ${s.city}',
                                          style: TextStyle(
                                            color:    rc.textSecondary,
                                            fontSize: 11,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        s.levelText,
                                        style: TextStyle(
                                          color:       riskColorSolid(dc),
                                          fontSize:    13,
                                          fontWeight:  FontWeight.w700,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        riskLabel(dc),
                                        style: TextStyle(
                                          color: riskColorSolid(dc)
                                              .withValues(alpha: 0.8),
                                          fontSize:      11,
                                          fontWeight:    FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.chevron_right_rounded,
                                      color: rc.textSecondary, size: 18),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
