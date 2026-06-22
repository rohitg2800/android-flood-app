import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equinox_flood/core/theme/river_theme.dart' as core_theme;
import 'package:equinox_flood/core/widgets/ops_badge.dart';
import 'package:equinox_flood/features/alerts_safety/presentation/widgets/alert_banner.dart';
import 'package:equinox_flood/features/alerts_safety/presentation/widgets/alert_tile.dart';
import '../mixins/auto_refresh_mixin.dart';
import '../models/river_station.dart';
import '../providers/live_engine_bridge_provider.dart';
import '../providers/alerts_badge_provider.dart';
import '../providers/alerts_parent_bridge_provider.dart';
import '../l10n/context_l10n.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  static const route = '/alerts';
  final String? stationFilter;
  const AlertsScreen({super.key, this.stationFilter});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen>
    with AutoRefreshMixin {

  @override
  Widget build(BuildContext context) {
    final c        = core_theme.RiverTheme.of(context).colors;
    final stations = ref.watch(liveEngineStationsProvider);
    final bridge   = ref.watch(alertsParentBridgeProvider);

    // Elevated stations only
    final elevated = stations
        .where((s) => s.danger > 0 && s.current > 0 && s.current >= s.warning)
        .toList();

    // Badge = unique elevated stations
    final seen0 = <String>{};
    final badgeCount = elevated
        .where((s) => seen0.add(s.city.toLowerCase().trim()))
        .length;

    return Scaffold(
      backgroundColor: c.scaffoldBg,
      appBar: AppBar(
        backgroundColor: c.scaffoldBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.notifications_active_rounded, color: c.danger, size: 20),
            const SizedBox(width: 8),
            Text(context.l10n.alerts,
              style: TextStyle(
                color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
            if (badgeCount > 0) ...[
              const SizedBox(width: 8),
              OpsBadge(label: '$badgeCount', variant: OpsBadgeVariant.danger),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: c.textSecondary),
            onPressed: onManualRefresh,
          ),
        ],
      ),
      body: refreshIndicator(
        child: _buildList(context, elevated, bridge, c),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<RiverStation> elevated,
    AlertsParentBridgeState bridge,
    dynamic c,
  ) {
    // Apply station filter
    var list = elevated;
    final filter = widget.stationFilter ?? bridge.pendingStationFilter;
    if (filter != null && filter.isNotEmpty) {
      String norm(String v) => v
          .toLowerCase()
          .replaceAll(RegExp(r'\s*\(.*?\)'), '')
          .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
          .replaceAll(RegExp(r' +'), ' ')
          .trim();
      final fNorm = norm(filter);
      list = list.where((s) => norm(s.city) == fNorm).toList();
    }

    // Deduplicate by city
    final seen = <String>{};
    list = list.where((s) => seen.add(s.city.toLowerCase().trim())).toList();

    // Sort: critical first
    list.sort((a, b) {
      int rank(RiverStation s) {
        if (s.current >= s.danger)        return 0;
        if (s.current >= s.warning * 1.1) return 1;
        return 2;
      }
      return rank(a).compareTo(rank(b));
    });

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded, color: c.success, size: 48),
            const SizedBox(height: 12),
            Text(context.l10n.noAlerts,
              style: TextStyle(color: c.textSecondary, fontSize: 16)),
            const SizedBox(height: 4),
            Text(context.l10n.allStationsSafe,
              style: TextStyle(color: c.textMuted, fontSize: 13)),
          ],
        ),
      );
    }

    final critical = list.where((s) => s.current >= s.danger).toList();
    final warning  = list.where((s) => s.current < s.danger).toList();

    final items = <Widget>[
      if (critical.isNotEmpty) ...[
        _GroupHeader(label: context.l10n.critical.toUpperCase(), color: c.danger),
        ...critical.map((s) => _AlertTile(station: s)),
        const SizedBox(height: 8),
      ],
      if (warning.isNotEmpty) ...[
        _GroupHeader(label: context.l10n.warning.toUpperCase(), color: c.warning),
        ...warning.map((s) => _AlertTile(station: s)),
      ],
    ];

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => items[i],
    );
  }
}

// ── Group header ───────────────────────────────────────────────────────────
class _GroupHeader extends StatelessWidget {
  final String label;
  final Color  color;
  const _GroupHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 0, 6),
      child: Row(
        children: [
          Container(width: 3, height: 14,
            decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(label,
            style: TextStyle(
              color: color, fontSize: 11,
              fontWeight: FontWeight.w800, letterSpacing: 1.1)),
        ],
      ),
    );
  }
}

// ── Alert tile ─────────────────────────────────────────────────────────────
class _AlertTile extends StatelessWidget {
  final RiverStation station;
  const _AlertTile({required this.station});

  bool get _isCritical => station.current >= station.danger;
  bool get _isSevere   => !_isCritical && station.current >= station.warning * 1.1;

  Color _color(dynamic c) {
    if (_isCritical) return c.danger;
    if (_isSevere)   return const Color(0xFFFF8C42);
    return c.warning;
  }

  OpsBadgeVariant _variant() {
    if (_isCritical) return OpsBadgeVariant.danger;
    if (_isSevere)   return OpsBadgeVariant.danger;
    return OpsBadgeVariant.warning;
  }

  IconData _icon() {
    if (_isCritical) return Icons.crisis_alert_rounded;
    if (_isSevere)   return Icons.warning_rounded;
    return Icons.warning_amber_rounded;
  }

  String _riskLabel(BuildContext context) {
    if (_isCritical) return context.l10n.critical.toUpperCase();
    if (_isSevere)   return context.l10n.danger.toUpperCase();
    return context.l10n.warning.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final t     = core_theme.RiverTheme.of(context);
    final c     = t.colors;
    final color = _color(c);
    final level  = station.current.toStringAsFixed(2);
    final danger = station.danger > 0 ? station.danger.toStringAsFixed(2) : '--';

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/city', arguments: station.city),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.28)),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon(), color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(station.city,
                          style: TextStyle(color: c.textPrimary,
                            fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                      OpsBadge(label: _riskLabel(context), variant: _variant()),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(station.river,
                    style: TextStyle(color: c.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _LevelChip(label: 'Current', value: '$level m', color: color),
                      const SizedBox(width: 8),
                      _LevelChip(label: 'Danger',  value: '$danger m', color: c.textMuted),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: c.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  const _LevelChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = core_theme.RiverTheme.of(context).colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: RichText(
        text: TextSpan(children: [
          TextSpan(text: '$label  ',
            style: TextStyle(color: c.textMuted, fontSize: 10)),
          TextSpan(text: value,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}