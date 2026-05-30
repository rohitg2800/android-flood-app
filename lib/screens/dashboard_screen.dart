// lib/screens/dashboard_screen.dart
// OpsFlood — DashboardScreen v16
// Phase 3 fix: _riskColor 'HIGH' → 'SEVERE', severity sort uses priorityOrder,
// KPI counts use riskLevel string (not raw capacity thresholds).
library;

import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import '../screens/india_river_explorer_screen.dart';
import '../services/real_time_service.dart';
import '../theme/river_theme.dart';
import '../widgets/animated_alert_badge.dart';
import '../widgets/ops_area_chart.dart';
import '../widgets/ops_bar_chart.dart';
import '../widgets/premium_stat_card.dart';
import '../widgets/risk_heatmap.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final RealTimeService _service = RealTimeService();
  String? _selectedCity;

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _service.addListener(_onData);
  }

  void _onData() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service.removeListener(_onData);
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Data helpers ───────────────────────────────────────────────────────────

  // Sort: highest severity first, then highest capacity within same tier.
  List<FloodData> get _sorted {
    final list = List<FloodData>.from(_service.liveLevels);
    list.sort((a, b) {
      final cmp = b.priorityOrder.compareTo(a.priorityOrder);
      if (cmp != 0) return cmp;
      return b.capacityPercent.compareTo(a.capacityPercent);
    });
    return list;
  }

  // Use riskLevel string so these counts agree with backend severity labels.
  int get _criticalCount =>
      _sorted.where((d) => d.riskLevel == 'CRITICAL').length;

  int get _alertCount =>
      _sorted.where((d) =>
          d.riskLevel == 'CRITICAL' || d.riskLevel == 'SEVERE').length;

  FloodData? get _selectedData {
    if (_selectedCity == null) return null;
    try {
      return _sorted.firstWhere((d) => d.city == _selectedCity);
    } catch (_) {
      return null;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final data = _sorted;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppPalette.abyss0,
        body: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _header()),
              SliverToBoxAdapter(child: _kpiRow(data)),
              if (data.isNotEmpty) ...[
                SliverToBoxAdapter(child: _sectionTitle(
                  'National Risk Overview',
                  sub: 'Top cities by flood capacity',
                  icon: Icons.bar_chart_rounded,
                  color: AppPalette.amber,
                )),
                SliverToBoxAdapter(child: _nationalBarChart(data)),
                SliverToBoxAdapter(child: _sectionTitle(
                  'River Level Trend',
                  sub: _selectedCity ??
                      (data.isNotEmpty ? data.first.city : 'Select city'),
                  icon: Icons.show_chart_rounded,
                  color: AppPalette.cyan,
                )),
                SliverToBoxAdapter(child: _riverTrendChart(data)),
                SliverToBoxAdapter(child: _citySelector(data)),
                SliverToBoxAdapter(child: _sectionTitle(
                  'State Risk Heatmap',
                  sub: 'Real-time state-level flood risk',
                  icon: Icons.grid_view_rounded,
                  color: AppPalette.safe,
                )),
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: RiskHeatmap(entries: _buildHeatmapEntries(data)),
                )),
              ] else
                SliverToBoxAdapter(child: _emptyState()),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Heatmap entry builder ──────────────────────────────────────────────────
  List<RiskHeatmapEntry> _buildHeatmapEntries(List<FloodData> data) {
    final stateMap = <String, Map<String, int>>{};
    for (final d in data) {
      stateMap.putIfAbsent(d.state, () => {});
      final level = _capacityToLevel(d.capacityPercent);
      stateMap[d.state]![level] = (stateMap[d.state]![level] ?? 0) + 1;
    }
    final entries = <RiskHeatmapEntry>[];
    stateMap.forEach((state, levelMap) {
      final dominant = levelMap.entries
          .reduce((a, b) => a.value >= b.value ? a : b);
      entries.add(RiskHeatmapEntry(
        state: state,
        level: dominant.key,
        count: levelMap.values.fold(0, (s, v) => s + v),
      ));
    });
    entries.sort((a, b) {
      const order = ['CRITICAL', 'DANGER', 'WARNING', 'SAFE'];
      return order.indexOf(a.level).compareTo(order.indexOf(b.level));
    });
    return entries;
  }

  String _capacityToLevel(double pct) {
    if (pct >= 85) return 'CRITICAL';
    if (pct >= 60) return 'DANGER';
    if (pct >= 35) return 'WARNING';
    return 'SAFE';
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _header() => Container(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppPalette.cyan.withValues(alpha: 0.06),
          AppPalette.abyss0,
        ],
      ),
      border: Border(
        bottom: BorderSide(
          color: AppPalette.cyan.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppPalette.cyan.withValues(alpha: 0.20),
                AppPalette.abyss2,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppPalette.cyan.withValues(alpha: 0.35),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppPalette.cyan.withValues(alpha: 0.18),
                blurRadius: 14,
              ),
            ],
          ),
          child: const Icon(Icons.water_drop_rounded,
              color: AppPalette.cyan, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [AppPalette.cyan, AppPalette.cyanDark],
                ).createShader(b),
                child: const Text(
                  'OpsFlood',
                  style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900,
                    color: Colors.white, letterSpacing: -0.6,
                  ),
                ),
              ),
              Text(
                'Live Flood Intelligence',
                style: TextStyle(
                  fontSize: 10,
                  color: AppPalette.textGrey.withValues(alpha: 0.7),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppPalette.safe.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppPalette.safe
                    .withValues(alpha: 0.30 * _pulseAnim.value),
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppPalette.safe
                      .withValues(alpha: _pulseAnim.value),
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.safe
                          .withValues(alpha: 0.7 * _pulseAnim.value),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              const Text('LIVE',
                  style: TextStyle(
                    color: AppPalette.safe, fontSize: 10,
                    fontWeight: FontWeight.w800,
                  )),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _service.refreshData();
          },
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppPalette.abyss2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppPalette.abyssStroke),
            ),
            child: const Icon(Icons.refresh_rounded,
                color: AppPalette.textGrey, size: 18),
          ),
        ),
      ],
    ),
  );

  // ── KPI Row ────────────────────────────────────────────────────────────────
  Widget _kpiRow(List<FloodData> data) {
    final critical  = _criticalCount;
    final alerting  = _alertCount;
    final monitored = data.length;
    final avgCap    = monitored > 0
        ? data.map((d) => d.capacityPercent).reduce((a, b) => a + b) /
            monitored
        : 0.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: PremiumStatCard(
              icon:    Icons.crisis_alert_rounded,
              value:   '$critical',
              label:   'CRITICAL',
              color:   critical > 0 ? AppPalette.critical : AppPalette.safe,
              isAlert: critical > 0,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 130,
            child: PremiumStatCard(
              icon:  Icons.warning_amber_rounded,
              value: '$alerting',
              label: 'ALERTING',
              color: alerting > 0 ? AppPalette.warning : AppPalette.textGrey,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 130,
            child: PremiumStatCard(
              icon:    Icons.sensors_rounded,
              value:   '$monitored',
              label:   'MONITORED',
              color:   AppPalette.cyan,
              isAlert: true,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 130,
            child: PremiumStatCard(
              icon:  Icons.analytics_rounded,
              value: avgCap.toStringAsFixed(0),
              label: 'AVG CAPACITY',
              color: AppPalette.amber,
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Title ──────────────────────────────────────────────────────────
  Widget _sectionTitle(String title, {
    String? sub,
    required IconData icon,
    required Color color,
  }) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Row(
          children: [
            Container(
              width: 3, height: 20,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 7),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800,
                    color: AppPalette.textWhite, letterSpacing: -0.2,
                  ),
                ),
                if (sub != null)
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppPalette.textGrey.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );

  // ── National bar chart ─────────────────────────────────────────────────────
  Widget _nationalBarChart(List<FloodData> data) {
    final top = data.take(8).toList();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: AppPalette.glassMorph(radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OpsBarChart(
            values:   top
                .map((d) => d.capacityPercent.clamp(0.0, 100.0))
                .toList(),
            labels:   top.map((d) => d.city).toList(),
            maxY:     100,
            yUnit:    '%',
            barWidth: 18,
            height:   160,
          ),
          const SizedBox(height: 4),
          Row(children: [
            _legendDot(AppPalette.safe,     'Safe (<35)'),
            const SizedBox(width: 12),
            _legendDot(AppPalette.warning,  'Alert (35-60)'),
            const SizedBox(width: 12),
            _legendDot(AppPalette.danger,   'High (60-85)'),
            const SizedBox(width: 12),
            _legendDot(AppPalette.critical, 'Critical (≥85)'),
          ]),
        ],
      ),
    );
  }

  // ── River trend area chart ─────────────────────────────────────────────────
  Widget _riverTrendChart(List<FloodData> data) {
    final selected =
        _selectedData ?? (data.isNotEmpty ? data.first : null);
    if (selected == null) return const SizedBox.shrink();

    final snapshots = _service.trendForCity(selected.city);
    final history   = snapshots.map((s) => s.level).toList();

    if (history.isEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        padding: const EdgeInsets.all(20),
        decoration: AppPalette.glassMorph(radius: 22),
        child: Center(
          child: Text(
            'No level history for ${selected.city}',
            style: const TextStyle(
              color: AppPalette.textGrey, fontSize: 12,
            ),
          ),
        ),
      );
    }

    // Use model getter — single source of truth.
    final statusColor = selected.priorityColor;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: AppPalette.glassMorph(
        radius: 22,
        borderColor: statusColor.withValues(alpha: 0.18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(
              selected.city,
              style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800,
                color: AppPalette.textWhite,
              ),
            ),
            const SizedBox(width: 8),
            _statusChip(
              '${selected.capacityPercent.toStringAsFixed(0)}%',
              statusColor,
            ),
            const Spacer(),
            Text(
              '${selected.currentLevel.toStringAsFixed(2)} m',
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w900,
                color: statusColor, letterSpacing: -0.5,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          OpsAreaChart(
            values:   history,
            labels:   snapshots.asMap().entries
                .map((e) => e.key % 4 == 0
                    ? _shortTime(snapshots[e.key].timestamp)
                    : '')
                .toList(),
            lineColor: statusColor,
            warningY:  selected.warningLevel,
            dangerY:   selected.dangerLevel,
            yUnit:     ' m',
            height:    130,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _mini('Warning',
                  '${selected.warningLevel.toStringAsFixed(1)} m',
                  AppPalette.amber),
              _mini('Danger',
                  '${selected.dangerLevel.toStringAsFixed(1)} m',
                  AppPalette.critical),
              _mini('Safe',
                  '${selected.safeLevel.toStringAsFixed(1)} m',
                  AppPalette.textGrey),
            ],
          ),
        ],
      ),
    );
  }

  // ── City selector chips ────────────────────────────────────────────────────
  Widget _citySelector(List<FloodData> data) {
    if (data.isEmpty) return const SizedBox.shrink();
    final top = data.take(10).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: top.map((d) {
          final active = (_selectedCity ?? top.first.city) == d.city;
          // Use model getter — no inline switch.
          final color  = d.priorityColor;
          return GestureDetector(
            onTap: () => setState(() => _selectedCity = d.city),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: active
                    ? color.withValues(alpha: 0.14)
                    : AppPalette.abyss2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active
                      ? color.withValues(alpha: 0.45)
                      : AppPalette.abyssStroke,
                  width: active ? 1.5 : 1,
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.18),
                          blurRadius: 10,
                        )
                      ]
                    : null,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: [
                      BoxShadow(
                          color: color.withValues(alpha: 0.6),
                          blurRadius: 4),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  d.city,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        active ? FontWeight.w800 : FontWeight.w500,
                    color: active ? color : AppPalette.textGrey,
                  ),
                ),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _emptyState() => SizedBox(
    height: 300,
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppPalette.cyan.withValues(alpha: 0.08),
              border: Border.all(
                  color: AppPalette.cyan.withValues(alpha: 0.18)),
            ),
            child: const Icon(Icons.water_drop_outlined,
                color: AppPalette.cyan, size: 34),
          ),
          const SizedBox(height: 16),
          const Text('Fetching live flood data…',
              style: TextStyle(
                color: AppPalette.textGrey,
                fontSize: 14, fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 6),
          const Text('CWC  •  GloFAS  •  IMD',
              style: TextStyle(
                color: AppPalette.textDim,
                fontSize: 10, letterSpacing: 1.5,
              )),
        ],
      ),
    ),
  );

  // ── Atoms ──────────────────────────────────────────────────────────────────
  Widget _mini(String label, String val, Color c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(val, style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w800, color: c)),
      Text(label, style: const TextStyle(
        fontSize: 9, color: AppPalette.textGrey)),
    ],
  );

  Widget _statusChip(String label, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: c.withValues(alpha: 0.35)),
    ),
    child: Text(label,
        style: TextStyle(
          color: c, fontSize: 9, fontWeight: FontWeight.w800)),
  );

  Widget _legendDot(Color c, String label) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 7, height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle, color: c,
            boxShadow: [
              BoxShadow(
                  color: c.withValues(alpha: 0.5), blurRadius: 4)
            ],
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
              fontSize: 9, color: AppPalette.textGrey)),
      ]);

  // _riskColor removed — use data.priorityColor instead.

  String _shortTime(DateTime ts) {
    try {
      return DateFormat('HH:mm').format(ts.toLocal());
    } catch (_) {
      return '';
    }
  }
}
