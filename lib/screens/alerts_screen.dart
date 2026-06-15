// lib/screens/alerts_screen.dart  (v5.2 — 15 Jun 2026)
//
// FIX: Added optional stationFilter String? constructor parameter.
//   main.dart calls AlertsScreen(stationFilter: stationFilter) in the
//   Routes.alerts case. Without this parameter the build fails with:
//   'No named parameter with the name 'stationFilter'.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mixins/auto_refresh_mixin.dart';
import '../providers/bihar_live_provider.dart';
import '../providers/alerts_badge_provider.dart';
import '../providers/alerts_parent_bridge_provider.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  /// Optional: when non-null, filters the alert list to this station name.
  final String? stationFilter;

  const AlertsScreen({super.key, this.stationFilter});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen>
    with AutoRefreshMixin {
  @override
  Widget build(BuildContext context) {
    final liveAsync  = ref.watch(biharLiveProvider);
    final badgeCount = ref.watch(alertsBadgeProvider);
    // Side-effect only — keep bridge alive while screen is mounted.
    ref.watch(alertsParentBridgeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              widget.stationFilter != null
                  ? 'Alerts — ${widget.stationFilter}'
                  : 'Alerts',
            ),
            if (badgeCount > 0) ...[
              const SizedBox(width: 8),
              Chip(
                label:           Text('$badgeCount new'),
                backgroundColor: Colors.red.shade700,
                labelStyle:      const TextStyle(color: Colors.white),
                padding:         EdgeInsets.zero,
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon:    const Icon(Icons.refresh),
            tooltip: 'Refresh now',
            onPressed: onManualRefresh,
          ),
        ],
      ),
      body: refreshIndicator(
        child: liveAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:   (e, _) => Center(child: Text('Error: $e')),
          data:    (live) => _buildAlertList(context, live),
        ),
      ),
    );
  }

  Widget _buildAlertList(BuildContext context, BiharLiveState live) {
    var alerts = live.stations
        .where((s) => s.isCritical || s.isSevere || s.isWarning)
        .toList();

    // Apply station filter if provided
    final filter = widget.stationFilter;
    if (filter != null && filter.isNotEmpty) {
      alerts = alerts
          .where((s) =>
              s.city.toLowerCase().contains(filter.toLowerCase()))
          .toList();
    }

    if (alerts.isEmpty) {
      return const Center(
        child: Text(
          'No active alerts',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      physics:    const AlwaysScrollableScrollPhysics(),
      padding:    const EdgeInsets.all(12),
      itemCount:  alerts.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final s = alerts[i];
        final color = s.isCritical
            ? Colors.red
            : s.isSevere
                ? Colors.deepOrange
                : Colors.orange;
        return ListTile(
          leading:  Icon(Icons.warning_amber_rounded, color: color),
          title:    Text(s.city),
          subtitle: Text(
              '${s.river}  •  ${s.currentLevel?.toStringAsFixed(2) ?? '--'} m  '
              '(danger: ${s.dangerLevel?.toStringAsFixed(2) ?? '--'} m)'),
          trailing: Chip(
            label:           Text(s.riskLabel),
            backgroundColor: color.withOpacity(0.15),
          ),
        );
      },
    );
  }
}
