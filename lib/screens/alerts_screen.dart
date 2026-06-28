// lib/screens/alerts_screen.dart  (v5.3 — 28 Jun 2026)
//
// v5.3 — AppBar fix: themed navBg, elevation:0, gradient divider, themed leading icon.
// v5.2 — Fix two compile errors introduced in v5.1.
// v5.1 — Add optional `stationFilter` param for deep-link routing.
// v5.0 — AutoRefreshMixin + ref.watch(biharLiveProvider).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mixins/auto_refresh_mixin.dart';
import '../providers/bihar_live_provider.dart';
import '../providers/alerts_badge_provider.dart';
import '../providers/alerts_parent_bridge_provider.dart';
import '../theme/river_colors.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  /// Optional station name to pre-filter the alert list (deep-link routing).
  final String? stationFilter;

  const AlertsScreen({super.key, this.stationFilter});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen>
    with AutoRefreshMixin {
  @override
  Widget build(BuildContext context) {
    final t          = RiverColors.of(context);
    final liveAsync  = ref.watch(biharLiveProvider);
    final badgeCount = ref.watch(alertsBadgeProvider);
    final bridge     = ref.watch(alertsParentBridgeProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: t.navBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: t.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            ShaderMask(
              shaderCallback: (r) => LinearGradient(
                colors: [t.textPrimary, Colors.red.shade400],
                stops: const [0.4, 1.0],
              ).createShader(r),
              child: const Text(
                'Alerts',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            if (badgeCount > 0) ...[
              const SizedBox(width: 8),
              Chip(
                label:           Text('$badgeCount new'),
                backgroundColor: Colors.red.shade700,
                labelStyle:      const TextStyle(color: Colors.white, fontSize: 11),
                padding:         EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon:    Icon(Icons.refresh, color: t.textSecondary),
            tooltip: 'Refresh now',
            onPressed: onManualRefresh,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.red.withValues(alpha: 0.0),
                Colors.red.withValues(alpha: 0.5),
                Colors.red.withValues(alpha: 0.0),
              ]),
            ),
          ),
        ),
      ),
      body: refreshIndicator(
        child: liveAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:   (e, _) => Center(child: Text('Error: $e')),
          data:    (live) => _buildAlertList(context, live, bridge),
        ),
      ),
    );
  }

  Widget _buildAlertList(
    BuildContext context,
    BiharLiveState live,
    AlertsParentBridgeState bridge,
  ) {
    var alerts = live.stations
        .where((s) => s.isCritical || s.isSevere || s.isWarning)
        .toList();

    final filter = widget.stationFilter ?? bridge.pendingStationFilter;
    if (filter != null && filter.isNotEmpty) {
      String norm(String v) => v
          .toLowerCase()
          .replaceAll(RegExp(r'\s*\(.*?\)'), '')
          .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
          .replaceAll(RegExp(r' +'), ' ')
          .trim();

      final fNorm = norm(filter);
      alerts = alerts
          .where((s) => norm(s.city) == fNorm)
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
              '${s.river}  •  '
              '${s.currentLevel?.toStringAsFixed(2) ?? '--'} m  '
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
