// lib/screens/alerts_screen.dart
// OpsFlood — AlertsScreen v1
// Shows FloodData entries grouped by severity (CRITICAL → SEVERE → MODERATE → LOW).
// All severity colours come from data.priorityColor — no inline switch blocks.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/flood_data.dart';
import '../services/real_time_service.dart';
import '../theme/river_theme.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final RealTimeService _svc = RealTimeService();
  final Set<String> _collapsed = {};
  bool _refreshing = false;

  static const _order = ['CRITICAL', 'SEVERE', 'MODERATE', 'LOW'];

  @override
  void initState() {
    super.initState();
    _svc.addListener(_onData);
  }

  void _onData() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _svc.removeListener(_onData);
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await _svc.refreshData();
    if (mounted) setState(() => _refreshing = false);
  }

  // Group and sort entries by severity tier.
  Map<String, List<FloodData>> get _grouped {
    final map = <String, List<FloodData>>{
      for (final k in _order) k: [],
    };
    for (final d in _svc.liveLevels) {
      final key = _order.contains(d.riskLevel) ? d.riskLevel : 'LOW';
      map[key]!.add(d);
    }
    // Within each group sort by capacityPercent desc.
    for (final list in map.values) {
      list.sort((a, b) => b.capacityPercent.compareTo(a.capacityPercent));
    }
    return map;
  }

  int get _activeCount =>
      _svc.liveLevels
          .where((d) => d.riskLevel == 'CRITICAL' || d.riskLevel == 'SEVERE')
          .length;

  @override
  Widget build(BuildContext context) {
    final groups = _grouped;
    final total  = _svc.liveLevels.length;

    return Scaffold(
      backgroundColor: AppPalette.abyss0,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            Expanded(
              child: total == 0
                  ? _emptyState()
                  : RefreshIndicator(
                      color: AppPalette.cyan,
                      backgroundColor: AppPalette.abyss2,
                      onRefresh: _refresh,
                      child: CustomScrollView(
                        physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics()),
                        slivers: [
                          for (final level in _order)
                            if (groups[level]!.isNotEmpty)
                              ..._section(level, groups[level]!),
                          const SliverToBoxAdapter(
                              child: SizedBox(height: 32)),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _header() => Container(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: AppPalette.critical.withValues(alpha: 0.10),
          width: 1,
        ),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: AppPalette.critical.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppPalette.critical.withValues(alpha: 0.30)),
          ),
          child: const Icon(Icons.notifications_active_rounded,
              color: AppPalette.critical, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Flood Alerts',
                  style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900,
                    color: AppPalette.textWhite, letterSpacing: -0.4,
                  )),
              Text(
                '$_activeCount active  •  ${_svc.liveLevels.length} monitored',
                style: TextStyle(
                  fontSize: 10,
                  color: AppPalette.textGrey.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _refresh();
          },
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppPalette.abyss2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppPalette.abyssStroke),
            ),
            child: _refreshing
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppPalette.cyan))
                : const Icon(Icons.refresh_rounded,
                    color: AppPalette.textGrey, size: 18),
          ),
        ),
      ],
    ),
  );

  // ── Section (collapsible group) ──────────────────────────────────────────
  List<Widget> _section(String level, List<FloodData> items) {
    // Use the first item's priorityColor as the group accent.
    final accent = items.first.priorityColor;
    final isCollapsed = _collapsed.contains(level);

    return [
      SliverToBoxAdapter(
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              if (isCollapsed) _collapsed.remove(level);
              else _collapsed.add(level);
            });
          },
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: accent.withValues(alpha: 0.20)),
            ),
            child: Row(children: [
              Container(
                width: 3, height: 18,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                        color: accent.withValues(alpha: 0.5),
                        blurRadius: 6)
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                level,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: accent,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${items.length}',
                  style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                isCollapsed
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.keyboard_arrow_up_rounded,
                color: accent.withValues(alpha: 0.7),
                size: 18,
              ),
            ]),
          ),
        ),
      ),
      if (!isCollapsed)
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => _alertCard(items[i]),
            childCount: items.length,
          ),
        ),
    ];
  }

  // ── Alert card ───────────────────────────────────────────────────────────────
  Widget _alertCard(FloodData d) {
    final color = d.priorityColor;  // single source of truth
    final pct   = d.capacityPercent.clamp(0.0, 100.0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: AppPalette.glassMorph(
        radius: 18,
        borderColor: color.withValues(alpha: 0.18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: city + state + status chip
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.city,
                      style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800,
                        color: AppPalette.textWhite,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${d.state}${d.riverName != null ? '  •  ${d.riverName}' : ''}',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppPalette.textGrey.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _chip(d.riskLevel, color),
                  if (d.imdSeverity != null) ...[
                    const SizedBox(height: 4),
                    _chip('IMD ● ${d.imdSeverity}',
                        _imdColor(d.imdSeverity!)),
                  ],
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Row 2: gauge levels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _levelPair('Current',
                  '${d.currentLevel.toStringAsFixed(2)} m', color),
              _levelPair('Warning',
                  '${d.warningLevel.toStringAsFixed(1)} m',
                  AppPalette.warning),
              _levelPair('Danger',
                  '${d.dangerLevel.toStringAsFixed(1)} m',
                  AppPalette.critical),
              _levelPair('Rainfall',
                  '${d.effectiveRainfallMm.toStringAsFixed(0)} mm',
                  AppPalette.cyan),
            ],
          ),

          const SizedBox(height: 10),

          // Capacity bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Capacity',
                      style: TextStyle(
                          fontSize: 9,
                          color: AppPalette.textGrey
                              .withValues(alpha: 0.7))),
                  Text(
                    '${pct.toStringAsFixed(0)}%',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: color),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct / 100,
                  minHeight: 5,
                  backgroundColor:
                      AppPalette.abyss4.withValues(alpha: 0.6),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Footer: status + last updated
          Row(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: (d.status == 'LIVE'
                        ? AppPalette.safe
                        : AppPalette.textGrey)
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                d.status,
                style: TextStyle(
                  fontSize: 8, fontWeight: FontWeight.w700,
                  color: d.status == 'LIVE'
                      ? AppPalette.safe
                      : AppPalette.textGrey,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const Spacer(),
            Text(
              _fmtTime(d.lastUpdated),
              style: TextStyle(
                fontSize: 9,
                color: AppPalette.textGrey.withValues(alpha: 0.6),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _emptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppPalette.safe.withValues(alpha: 0.08),
            border:
                Border.all(color: AppPalette.safe.withValues(alpha: 0.18)),
          ),
          child: const Icon(Icons.check_circle_outline_rounded,
              color: AppPalette.safe, size: 34),
        ),
        const SizedBox(height: 16),
        const Text('No active alerts',
            style: TextStyle(
              color: AppPalette.textGrey,
              fontSize: 14, fontWeight: FontWeight.w600,
            )),
        const SizedBox(height: 6),
        const Text('All monitored stations within safe levels',
            style: TextStyle(
              color: AppPalette.textDim,
              fontSize: 11,
            )),
      ],
    ),
  );

  // ── Atoms ─────────────────────────────────────────────────────────────────────
  Widget _chip(String label, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: c.withValues(alpha: 0.35)),
    ),
    child: Text(label,
        style: TextStyle(
            color: c, fontSize: 8, fontWeight: FontWeight.w800,
            letterSpacing: 0.4)),
  );

  Widget _levelPair(String label, String val, Color c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(val,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800, color: c)),
      Text(label,
          style: const TextStyle(
              fontSize: 9, color: AppPalette.textGrey)),
    ],
  );

  Color _imdColor(String sev) {
    switch (sev.toUpperCase()) {
      case 'RED':    return AppPalette.critical;
      case 'ORANGE': return AppPalette.warning;
      case 'YELLOW': return AppPalette.amber;
      default:       return AppPalette.textGrey;
    }
  }

  String _fmtTime(DateTime dt) {
    try {
      return DateFormat('dd MMM HH:mm').format(dt.toLocal());
    } catch (_) {
      return '';
    }
  }
}
