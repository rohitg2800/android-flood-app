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
                    // FIX: OpsDepthCard takes only alert: and optional onTap:
                    // There is no elevation: / OpsDepthLevel enum on OpsDepthCard.
                    child: OpsDepthCard(alert: items[i]),
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
