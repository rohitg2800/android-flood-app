// lib/widgets/dashboard/animated_area_chart.dart  v3
// Fixed:
//   • StreamBuilder type: DataFetchSnapshot (not DataFetchSnapshot<StationReading>)
//   • .last → DataFetchEngine.instance.last (nullable DataFetchSnapshot?)
//   • StationReading not used as type arg
//   • progressPct / river / stationName / riskLabel accessed via null-safe snapshot
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../services/data_fetch_engine.dart';
import '../../theme/river_theme.dart';

class AnimatedAreaChart extends StatefulWidget {
  final AnimationController animCtrl;
  final Animation<double>   areaAnim;
  final bool                reduceMotion;

  const AnimatedAreaChart({
    super.key,
    required this.animCtrl,
    required this.areaAnim,
    required this.reduceMotion,
  });

  @override
  State<AnimatedAreaChart> createState() => _AnimatedAreaChartState();
}

class _AnimatedAreaChartState extends State<AnimatedAreaChart> {
  int _hoveredIndex = -1;

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);

    return StreamBuilder<DataFetchSnapshot>(
      stream:      DataFetchEngine.instance.stream,
      initialData: DataFetchEngine.instance.last,
      builder: (context, snap) {
        final snapshot = snap.data;
        final stations  = snapshot?.stations ?? [];
        final top5 = stations
            .where((d) => d.warningLevel > 0)
            .toList()
          ..sort((a, b) => b.progressPct.compareTo(a.progressPct));
        final display = top5.take(5).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Row(
                children: [
                  Text('Risk Levels',
                      style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (snapshot?.isLoading == true)
                    SizedBox(
                      width: 10, height: 10,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: t.accent)),
                ],
              ),
            ),
            if (display.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No live data yet',
                    style: TextStyle(color: t.textSecondary, fontSize: 12)),
              )
            else
              AnimatedBuilder(
                animation: widget.areaAnim,
                builder: (_, __) => Column(
                  children: List.generate(display.length, (i) {
                    final d    = display[i];
                    final pct  = (d.progressPct * widget.areaAnim.value).clamp(0.0, 1.0);
                    final col  = _riskColor(d.progressPct);

                    return GestureDetector(
                      onTap: () => setState(() =>
                          _hoveredIndex = _hoveredIndex == i ? -1 : i),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    d.river,
                                    style: TextStyle(
                                        color: t.textPrimary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${(d.progressPct * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                      color: col,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 5,
                                backgroundColor:
                                    col.withValues(alpha: 0.12),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(col),
                              ),
                            ),
                            if (_hoveredIndex == i)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  '${d.stationName} — ${d.riskLabel}  '
                                  '${d.currentLevel.toStringAsFixed(2)} m',
                                  style: TextStyle(
                                      color: t.textSecondary, fontSize: 10),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
          ],
        );
      },
    );
  }

  Color _riskColor(double pct) {
    if (pct >= 1.0)  return AppPalette.critical;
    if (pct >= 0.85) return AppPalette.danger;
    if (pct >= 0.70) return AppPalette.warning;
    return AppPalette.safe;
  }
}
