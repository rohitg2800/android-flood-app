// lib/screens/live_stations_screen.dart  (v4.0 — 15 Jun 2026)
//
// CHANGE: Auto-refresh wired via stream subscription.
//
// v4.0 (15 Jun 2026) — Replace static ListView with
//   ref.watch(mergedStationsProvider) so the list rebuilds automatically
//   every time BiharLiveEngine emits.  AutoRefreshMixin adds pull-to-refresh.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mixins/auto_refresh_mixin.dart';
import '../providers/real_time_river_provider.dart';
import '../models/river_station.dart';

class LiveStationsScreen extends ConsumerStatefulWidget {
  const LiveStationsScreen({super.key});

  @override
  ConsumerState<LiveStationsScreen> createState() => _LiveStationsScreenState();
}

class _LiveStationsScreenState extends ConsumerState<LiveStationsScreen>
    with AutoRefreshMixin {
  @override
  Widget build(BuildContext context) {
    final stations = ref.watch(mergedStationsProvider);
    final isLoading = ref.watch(wrdIsLoadingProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Live Stations (${stations.length})'),
            if (lastFetchedLabel.isNotEmpty)
              Text(
                lastFetchedLabel,
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            IconButton(
              icon:     const Icon(Icons.refresh),
              tooltip:  'Refresh now',
              onPressed: onManualRefresh,
            ),
        ],
      ),
      body: stations.isEmpty && isLoading
          ? const Center(child: CircularProgressIndicator())
          : refreshIndicator(
              child: ListView.builder(
                physics:   const AlwaysScrollableScrollPhysics(),
                padding:   const EdgeInsets.all(8),
                itemCount: stations.length,
                itemBuilder: (ctx, i) => _StationRow(station: stations[i]),
              ),
            ),
    );
  }
}

class _StationRow extends StatelessWidget {
  final RiverStation station;
  const _StationRow({required this.station});

  @override
  Widget build(BuildContext context) {
    final pct = station.danger > 0
        ? (station.current / station.danger * 100).clamp(0, 150)
        : 0.0;
    final Color color = pct >= 100
        ? Colors.red
        : pct >= 85
            ? Colors.orange
            : pct >= 70
                ? Colors.amber
                : Colors.green;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.15),
        child: Icon(Icons.water, color: color),
      ),
      title: Text(station.city),
      subtitle: Text('${station.river}  •  ${station.state}'),
      trailing: Text(
        '${station.current.toStringAsFixed(2)} m',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      dense: true,
    );
  }
}
