// lib/widgets/dashboard/alert_log.dart
// Fixed: d.city/state/district/riverName (String?) null guards
import 'package:flutter/material.dart';
import '../../models/flood_data.dart';
import '../../theme/river_theme.dart';
import 'risk_color_helper.dart';

class AlertLog extends StatelessWidget {
  final List<FloodData> data;
  final AnimationController entryCtrl;

  const AlertLog({super.key, required this.data, required this.entryCtrl});

  static const _staleHours = 3;

  String _timeAgo(DateTime? ts) {
    if (ts == null) return 'unknown';
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  bool _isStale(FloodData d) {
    final ts = d.lastUpdated;
    if (ts == null) return true;
    return DateTime.now().difference(ts).inHours >= _staleHours;
  }

  String _subtitle(FloodData d) {
    final parts = <String>[];
    if ((d.riverName ?? '').isNotEmpty) parts.add(d.riverName!);
    if ((d.district ?? '').isNotEmpty) parts.add(d.district!);
    if ((d.state ?? '').isNotEmpty) parts.add(d.state!);
    return parts.join('  ·  ');
  }

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);

    if (data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppPalette.safe.withValues(alpha: 0.20)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  color: AppPalette.safe, size: 18),
              const SizedBox(width: 10),
              Text('No critical alerts — all stations normal',
                  style: TextStyle(color: t.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.stroke),
        ),
        child: Column(
          children: data.asMap().entries.map((e) {
            final i = e.key;
            final d = e.value;
            final col = riskColor(d.riskLevel);
            final stale = _isStale(d);
            final hasWarning = d.warningLevel > 0;
            final hasDanger = d.dangerLevel > 0;
            final aboveWarning = hasWarning && d.currentLevel > d.warningLevel;

            return AnimatedBuilder(
              animation: entryCtrl,
              builder: (_, child) {
                final delay = (i * 0.07).clamp(0.0, 0.6);
                final p =
                    ((entryCtrl.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
                return Opacity(
                  opacity: p,
                  child: Transform.translate(
                      offset: Offset(-16 * (1 - p), 0), child: child),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 3,
                          height: 52,
                          decoration: BoxDecoration(
                              color: col,
                              borderRadius: BorderRadius.circular(2)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      d.city ?? d.stationName,
                                      style: TextStyle(
                                          color: t.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  if (stale)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 6),
                                      child: Icon(Icons.access_time_rounded,
                                          size: 12,
                                          color: const Color(0xFFFFA726)),
                                    ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _timeAgo(d.lastUpdated),
                                    style: TextStyle(
                                      color: stale
                                          ? const Color(0xFFFFA726)
                                          : t.textSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(_subtitle(d),
                                  style: TextStyle(
                                      color: t.textSecondary, fontSize: 11)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  AlertChip(
                                      label:
                                          '${d.currentLevel.toStringAsFixed(2)} m',
                                      color: col,
                                      icon: Icons.height),
                                  if (hasDanger) ...[
                                    const SizedBox(width: 5),
                                    AlertChip(
                                        label:
                                            '/${d.dangerLevel.toStringAsFixed(1)} m',
                                        color: t.textSecondary,
                                        icon: Icons.stream),
                                  ],
                                  if (d.effectiveRainfallMm > 0) ...[
                                    const SizedBox(width: 5),
                                    AlertChip(
                                        label:
                                            '${d.effectiveRainfallMm.toStringAsFixed(0)} mm',
                                        color: const Color(0xFF42A5F5),
                                        icon: Icons.water_drop_outlined),
                                  ],
                                  if (aboveWarning) ...[
                                    const SizedBox(width: 5),
                                    AlertChip(
                                        label: '▲ warning',
                                        color: const Color(0xFFFFA726),
                                        icon: Icons.warning_amber_rounded),
                                  ],
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: col.withValues(alpha: 0.10),
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    child: Text(d.riskLevel,
                                        style: TextStyle(
                                            color: col,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < data.length - 1)
                    Divider(height: 0.7, thickness: 0.7, color: t.stroke),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class AlertChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const AlertChip(
      {super.key,
      required this.label,
      required this.color,
      required this.icon});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      );
}
