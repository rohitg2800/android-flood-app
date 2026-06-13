// lib/screens/alerts_screen.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';
import '../providers/alert_provider.dart';
import '../models/flood_alert.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  static const String route = '/alerts';

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() => setState(() => _tabIndex = _tab.index));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t  = RiverColors.of(context);
    final ap = ref.watch(alertProvider);

    final items = _tabIndex == 0
        ? ap.all
        : _tabIndex == 1
            ? ap.danger
            : ap.warnings;

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          Td3AppBar(
            title: 'Flood Alerts',
            subtitle: '${ap.totalCount} active alerts',
            actions: [
              _tab3D(context, 0, 'ALL',    ap.totalCount,  t.accent),
              _tab3D(context, 1, 'DANGER', ap.dangerCount, t.riverDanger),
              _tab3D(context, 2, 'WARN',   ap.warningCount, t.riverWarning),
              const SizedBox(width: 8),
            ],
          ),
          if (items.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 56, color: t.riverNormal),
                    const SizedBox(height: 12),
                    Text('No alerts',
                        style: TextStyle(color: t.textSecondary)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AlertCard(alert: items[i]),
                  ),
                  childCount: items.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tab3D(
      BuildContext ctx, int idx, String label, int count, Color color) {
    final active = _tabIndex == idx;
    return GestureDetector(
      onTap: () => _tab.animateTo(idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active ? color : Colors.transparent, width: 1),
        ),
        child: Text('$label $count',
            style: TextStyle(
                color: active ? color : RiverColors.of(ctx).textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ── Alert card ───────────────────────────────────────────────────────────────

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});
  final FloodAlert alert;

  @override
  Widget build(BuildContext context) {
    final t     = RiverColors.of(context);
    final color = alert.level == AlertLevel.danger ||
            alert.level == AlertLevel.extreme
        ? t.riverDanger
        : t.riverWarning;

    return Td3Card(
      elevation: Td3.elevMid,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_city_rounded,
                    color: color, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(alert.cityName,
                      style: TextStyle(
                          color: t.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(alert.level.label,
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: alert.fillPercent.clamp(0.0, 1.0),
              backgroundColor:
                  t.cardBgElevated,
              valueColor: AlwaysStoppedAnimation(color),
              borderRadius: BorderRadius.circular(4),
              minHeight: 6,
            ),
            const SizedBox(height: 6),
            Text(
              '${alert.currentValue.toStringAsFixed(2)} m  /  danger at ${alert.dangerLevel.toStringAsFixed(2)} m',
              style: TextStyle(
                  color: t.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
