// lib/screens/river_monitor_screen.dart  (v6.0 — 15 Jun 2026)
//
// CHANGE: Auto-refresh wired via stream subscription.
//
// v6.0 (15 Jun 2026) — Remove private Timer.periodic(5 min) that was
//   calling setState() directly.  Replace with ref.watch(mergedStationsProvider)
//   so the widget tree rebuilds automatically from the BiharLiveEngine stream.
//   AutoRefreshMixin adds pull-to-refresh + last-updated chip in the header.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mixins/auto_refresh_mixin.dart';
import '../providers/real_time_river_provider.dart';
import '../models/river_station.dart';
import '../widgets/river_level_chip.dart';

class RiverMonitorScreen extends ConsumerStatefulWidget {
  const RiverMonitorScreen({super.key});

  @override
  ConsumerState<RiverMonitorScreen> createState() =>
      _RiverMonitorScreenState();
}

class _RiverMonitorScreenState extends ConsumerState<RiverMonitorScreen>
    with AutoRefreshMixin {
  // ── No private Timer — engine handles scheduling. ─────────────────────────

  String _filter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final riverState = ref.watch(realTimeRiverProvider);
    final stations   = riverState.stations;

    final filtered = _filter == 'ALL'
        ? stations
        : stations.where((s) => s.river == _filter).toList();

    final rivers = {'ALL', ...stations.map((s) => s.river)}.toList()
      ..sort();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('River Monitor'),
            if (lastFetchedLabel.isNotEmpty)
              Text(
                lastFetchedLabel,
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon:     const Icon(Icons.refresh),
            tooltip:  'Refresh now',
            onPressed: onManualRefresh,
          ),
        ],
      ),
      body: Column(
        children: [
          // River filter chips
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding:         const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount:       rivers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final r = rivers[i];
                return FilterChip(
                  label:    Text(r),
                  selected: _filter == r,
                  onSelected: (_) => setState(() => _filter = r),
                );
              },
            ),
          ),
          Expanded(
            child: riverState.isLoading && stations.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : refreshIndicator(
                    child: ListView.builder(
                      physics:   const AlwaysScrollableScrollPhysics(),
                      padding:   const EdgeInsets.all(8),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) =>
                          _StationTile(station: filtered[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StationTile extends StatelessWidget {
  final RiverStation station;
  const _StationTile({required this.station});

  @override
  Widget build(BuildContext context) {
    final pct = station.danger > 0
        ? (station.current / station.danger * 100).clamp(0, 150)
        : 0.0;
    final color = pct >= 100
        ? Colors.red
        : pct >= 85
            ? Colors.orange
            : Colors.green;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    station.city,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                RiverLevelChip(
                  current: station.current,
                  danger:  station.danger,
                  warning: station.warning,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${station.river}  •  ${station.state}'
              '${station.isLive ? "  •  LIVE" : ""}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value:            (pct / 100).clamp(0, 1).toDouble(),
              backgroundColor:  Colors.grey.shade200,
              color:            color,
            ),
            const SizedBox(height: 4),
            Text(
              '${station.current.toStringAsFixed(2)} m  /  '
              'Danger: ${station.danger.toStringAsFixed(2)} m  '
              '(${pct.toStringAsFixed(0)}%)',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
