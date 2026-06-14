// lib/screens/alerts_screen.dart
// Phase 2 — OpsDepthCard wired on alert cards with severity glow
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';
import '../providers/alert_provider.dart';
// FloodAlert + AlertSeverity come from alert_engine via alerts_provider.
// Do NOT import models/flood_alert.dart here — it defines a second
// incompatible FloodAlert class that causes type-mismatch build errors.
import '../providers/alerts_provider.dart';
import '../widgets/ops_depth_card.dart'; // Phase 2

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

  Color _severityColor(RiverColors t) {
    switch (alert.severity) {
      case AlertSeverity.emergency:
      case AlertSeverity.critical:
        return t.riverDanger;
      case AlertSeverity.warning:
        return t.riverWarning;
      case AlertSeverity.info:
        return t.riverNormal;
    }
  }

  OpsDepthLevel _elevFromSeverity(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.emergency:
      case AlertSeverity.critical:
        return OpsDepthLevel.critical;
      case AlertSeverity.warning:
        return OpsDepthLevel.high;
      case AlertSeverity.info:
        return OpsDepthLevel.mid;
    }
  }

  double get _progress {
    if (alert.thresholdLevel <= 0) return 0;
    return (alert.exceedancePct / 100).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final t     = RiverColors.of(context);
    final color = _severityColor(t);

    return OpsDepthCard(
      elevation: _elevFromSeverity(alert.severity),
      borderColor: color,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(alert.type.icon,
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  alert.title,
                  style: TextStyle(
                      color: t.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  alert.severity.label,
                  style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            alert.body,
            style: TextStyle(color: t.textSecondary, fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: t.cardBgElevated,
            valueColor: AlwaysStoppedAnimation(color),
            borderRadius: BorderRadius.circular(4),
            minHeight: 6,
          ),
          const SizedBox(height: 6),
          Text(
            '${alert.currentLevel.toStringAsFixed(2)} m  /  threshold at ${alert.thresholdLevel.toStringAsFixed(2)} m',
            style: TextStyle(color: t.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
