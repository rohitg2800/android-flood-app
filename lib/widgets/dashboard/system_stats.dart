// lib/widgets/dashboard/system_stats.dart
// SystemStats v2 — live source health from DataFetchEngine.
// Fixes: "0/4 online" shown in screenshot.
// Each tile reads DataFetchEngine.instance.stream for real SourceStatus:
//   healthy=true  → green dot (pulsing)
//   healthy=false + latency!=null → red dot
//   healthy=false + latency==null → amber dot (never tried)
import 'package:flutter/material.dart';
import '../../services/data_fetch_engine.dart';
import '../../services/real_time_service.dart';
import '../../theme/river_theme.dart';

// ─── Public: SystemStats ──────────────────────────────────────────────────────
class SystemStats extends StatelessWidget {
  final RealTimeService service;
  final AnimationController pulseCtrl;
  final Animation<double> gaugeAnim;
  final bool reduceMotion;

  const SystemStats({
    super.key,
    required this.service,
    required this.pulseCtrl,
    required this.gaugeAnim,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DataFetchSnapshot>(
      stream: DataFetchEngine.instance.stream,
      initialData: DataFetchEngine.instance.last,
      builder: (context, snap) {
        final sources = snap.data?.sources ?? [];
        return _SystemStatsBody(
          rawSources: sources,
          pulseCtrl: pulseCtrl,
          reduceMotion: reduceMotion,
        );
      },
    );
  }
}

// ─── Internal body ─────────────────────────────────────────────────────────────
class _SystemStatsBody extends StatelessWidget {
  final List<SourceStatus> rawSources;
  final AnimationController pulseCtrl;
  final bool reduceMotion;

  const _SystemStatsBody({
    required this.rawSources,
    required this.pulseCtrl,
    required this.reduceMotion,
  });

  // Canonical display order — matches the 4 tiles in the screenshot.
  static const _kDisplaySources = [
    _SourceMeta(
        key: 'GloFAS',
        label: 'GloFAS',
        detail: 'Flood Forecast',
        icon: Icons.waves_rounded),
    _SourceMeta(
        key: 'WRD_BIHAR',
        label: 'WRD Bihar',
        detail: 'River Gauge',
        icon: Icons.sensors_rounded),
    _SourceMeta(
        key: 'IMD', label: 'IMD', detail: 'Rainfall Data', icon: Icons.grain),
    _SourceMeta(
        key: 'CWC_FFS',
        label: 'CWC',
        detail: 'Central Water',
        icon: Icons.water_drop_rounded),
  ];

  SourceStatus? _find(String key) {
    final k = key.toLowerCase();
    for (final s in rawSources) {
      if (s.name.toLowerCase().contains(k) ||
          k.contains(s.name.toLowerCase())) {
        return s;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);

    // Build resolved list
    final resolved = _kDisplaySources.map((meta) {
      final found = _find(meta.key);
      return _ResolvedSource(
        meta: meta,
        status: found,
      );
    }).toList();

    final healthyCount =
        resolved.where((r) => r.status?.healthy == true).length;
    final total = resolved.length;
    final allOnline = healthyCount == total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────────────────────
            Row(
              children: [
                Icon(Icons.hub_rounded, size: 13, color: t.accent),
                const SizedBox(width: 6),
                Text(
                  'Data Sources',
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                // Live online count badge
                AnimatedBuilder(
                  animation: pulseCtrl,
                  builder: (_, __) {
                    final badgeColor =
                        allOnline ? AppPalette.safe : AppPalette.warning;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(
                          alpha: reduceMotion
                              ? 0.12
                              : 0.08 + pulseCtrl.value * 0.10,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: badgeColor.withValues(alpha: 0.30)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: badgeColor.withValues(
                                alpha: reduceMotion
                                    ? 0.9
                                    : 0.5 + pulseCtrl.value * 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$healthyCount/$total online',
                            style: TextStyle(
                              color: badgeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ── 2×2 grid of source tiles ─────────────────────────────────
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.6,
              children: resolved
                  .map((r) => _SourceTile(
                        resolved: r,
                        pulseCtrl: pulseCtrl,
                        reduceMotion: reduceMotion,
                        t: t,
                      ))
                  .toList(),
            ),
            // ── Last-fetched time row ───────────────────────────────────
            const SizedBox(height: 10),
            StreamBuilder<DataFetchSnapshot>(
              stream: DataFetchEngine.instance.stream,
              initialData: DataFetchEngine.instance.last,
              builder: (_, snap) {
                final fetchedAt = snap.data?.fetchedAt;
                final label = fetchedAt == null
                    ? 'Last sync: Never'
                    : _relativeTime(fetchedAt);
                final dotColor =
                    fetchedAt == null ? AppPalette.warning : AppPalette.safe;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sync_rounded,
                        size: 11, color: dotColor.withValues(alpha: 0.7)),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'Last sync: ${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return 'Last sync: ${diff.inMinutes}m ago';
    return 'Last sync: ${diff.inHours}h ago';
  }
}

// ─── Source metadata (static display info) ────────────────────────────────────
class _SourceMeta {
  final String key;
  final String label;
  final String detail;
  final IconData icon;
  const _SourceMeta({
    required this.key,
    required this.label,
    required this.detail,
    required this.icon,
  });
}

class _ResolvedSource {
  final _SourceMeta meta;
  final SourceStatus? status;
  const _ResolvedSource({required this.meta, required this.status});

  bool get healthy => status?.healthy ?? false;
  int? get latencyMs => status?.latencyMs;
  int get stationCnt => status?.stationCount ?? 0;
  String? get errorMsg => status?.errorMessage;

  Color get dotColor {
    if (status == null) return const Color(0xFFE6A817); // amber — never tried
    if (healthy) return AppPalette.safe;
    if (latencyMs != null) return AppPalette.critical;
    return const Color(0xFFE6A817); // amber — timeout / no response
  }

  String get statusText {
    if (status == null) return 'Initialising…';
    if (healthy) return stationCnt > 0 ? '$stationCnt stations' : 'Online';
    return errorMsg != null ? 'Error' : 'Offline';
  }
}

// ─── Private: _SourceTile ─────────────────────────────────────────────────────
class _SourceTile extends StatelessWidget {
  final _ResolvedSource resolved;
  final AnimationController pulseCtrl;
  final bool reduceMotion;
  final RiverColors t;

  const _SourceTile({
    required this.resolved,
    required this.pulseCtrl,
    required this.reduceMotion,
    required this.t,
  });

  String? get _latencyLabel {
    final ms = resolved.latencyMs;
    if (ms == null) return null;
    return ms < 1000 ? '$ms ms' : '${(ms / 1000).toStringAsFixed(1)} s';
  }

  @override
  Widget build(BuildContext context) {
    final col = resolved.dotColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: col.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          // ── Pulsing status dot ─────────────────────────────────────
          AnimatedBuilder(
            animation: pulseCtrl,
            builder: (_, __) {
              final pulse = resolved.healthy && !reduceMotion
                  ? 0.5 + pulseCtrl.value * 0.5
                  : 0.9;
              return Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: col.withValues(alpha: pulse),
                  boxShadow: resolved.healthy
                      ? [
                          BoxShadow(
                            color:
                                col.withValues(alpha: pulseCtrl.value * 0.50),
                            blurRadius: 7,
                          ),
                        ]
                      : null,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          // ── Label + detail ─────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        resolved.meta.label,
                        style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_latencyLabel != null) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: col.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          _latencyLabel!,
                          style: TextStyle(
                            color: col,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  resolved.statusText,
                  style: TextStyle(color: t.textSecondary, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // ── Source icon ───────────────────────────────────────────
          Icon(resolved.meta.icon,
              size: 13, color: col.withValues(alpha: 0.60)),
        ],
      ),
    );
  }
}
