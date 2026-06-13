// lib/screens/river_monitor_screen.dart  (v4.0 — 3D theme)
// Bihar Flood Ops — River Monitor Screen
//
// v3.x → v4.0:
//   • Migrated to Td3 3D theme system
//   • AppBar → Td3AppBar (SliverAppBar via CustomScrollView)
//   • River cards → Td3Card
//   • Summary chips → Td3Chip
//   • Level progress bars → Td3ProgressBar
//   • Risk labels → Td3Badge
//   • Section headers → Td3SectionHeader
//   • All colours via RiverColors

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/flood_data.dart';
import '../providers/flood_providers.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';

class RiverMonitorScreen extends ConsumerStatefulWidget {
  const RiverMonitorScreen({super.key});
  static const String route = '/river_monitor';

  @override
  ConsumerState<RiverMonitorScreen> createState() =>
      _RiverMonitorScreenState();
}

class _RiverMonitorScreenState extends ConsumerState<RiverMonitorScreen> {
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<FloodData> _filtered(List<FloodData> levels) {
    if (_query.isEmpty) return levels;
    final q = _query.toLowerCase();
    return levels
        .where((fd) =>
            fd.city.toLowerCase().contains(q) ||
            fd.state.toLowerCase().contains(q) ||
            fd.district.toLowerCase().contains(q) ||
            (fd.riverName?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final allLevels = ref.watch(liveLevelsProvider);
    final isLoading = ref.watch(isLoadingProvider);
    final isOffline = ref.watch(isOfflineProvider);
    final lastFetch = ref.watch(lastFetchTimeProvider);
    final t         = RiverColors.of(context);

    final levels    = _filtered(allLevels);

    final critCount = allLevels
        .where((d) => d.riskLevel.toUpperCase() == 'CRITICAL').length;
    final sevCount  = allLevels
        .where((d) => d.riskLevel.toUpperCase() == 'SEVERE').length;
    final normCount = allLevels.length - critCount - sevCount;

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          // ── 3D AppBar ─────────────────────────────────────────────────
          Td3AppBar(
            title: 'River Monitor',
            subtitle: allLevels.isNotEmpty
                ? _subtitleText(
                    allLevels.length, critCount, sevCount, normCount,
                    isOffline, lastFetch)
                : null,
            actions: [
              if (isOffline)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(Icons.wifi_off_rounded,
                      color: AppPalette.warning, size: 18),
                ),
            ],
          ),

          // ── Search bar ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Td3Card(
                elevation: Td3.elevLow,
                padding: EdgeInsets.zero,
                borderRadius: BorderRadius.circular(30),
                child: TextField(
                  controller: _searchCtrl,
                  style: TextStyle(color: t.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText:
                        'Search city, district, state or river…',
                    hintStyle:
                        TextStyle(color: t.textSecondary, fontSize: 13),
                    prefixIcon:
                        Icon(Icons.search, color: t.accent, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear,
                                color: t.textSecondary, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            ),
          ),

          // ── Summary chips ────────────────────────────────────────────
          if (allLevels.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Td3Chip(
                        label: '${allLevels.length} Stations',
                        color: t.accent,
                        icon: Icons.water),
                    if (critCount > 0)
                      Td3Chip(
                          label: '$critCount Critical',
                          color: AppPalette.critical,
                          icon: Icons.warning_amber_rounded),
                    if (sevCount > 0)
                      Td3Chip(
                          label: '$sevCount Severe',
                          color: AppPalette.danger,
                          icon: Icons.warning_rounded),
                    if (normCount > 0)
                      Td3Chip(
                          label: '$normCount Normal',
                          color: AppPalette.safe,
                          icon: Icons.check_circle_outline),
                  ],
                ),
              ),
            ),

          // ── Offline / stale banner ───────────────────────────────────
          if (isOffline)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                child: Td3Card(
                  accentColor: AppPalette.warning,
                  elevation: Td3.elevLow,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.wifi_off_rounded,
                          color: AppPalette.warning, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'No internet — showing cached data',
                        style: TextStyle(
                            color: AppPalette.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (lastFetch != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                child: Td3Card(
                  accentColor: t.accent,
                  elevation: Td3.elevLow,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: t.accent, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Last updated ${DateFormat('HH:mm').format(lastFetch)}',
                        style: TextStyle(
                            color: t.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Content ──────────────────────────────────────────────────
          if (isLoading && allLevels.isEmpty)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (levels.isEmpty)
            SliverFillRemaining(
              child: _EmptyState(t: t, query: _query),
            )
          else
            SliverPadding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _RiverCard(data: levels[i], t: t),
                  childCount: levels.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _subtitleText(int total, int crit, int sev, int norm,
      bool offline, DateTime? lastFetch) {
    final parts = <String>['$total stations'];
    if (crit > 0) parts.add('$crit critical');
    if (sev  > 0) parts.add('$sev severe');
    parts.add('$norm normal');
    if (offline) parts.add('● offline');
    return parts.join(' · ');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// River Card (3D)
// ─────────────────────────────────────────────────────────────────────────────

class _RiverCard extends StatelessWidget {
  final FloodData    data;
  final RiverColors  t;
  const _RiverCard({required this.data, required this.t});

  @override
  Widget build(BuildContext context) {
    final riskColor = _riskToColor(data.riskLevel, t);
    final fillPct   = data.fillPercent ?? 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Td3Card(
        accentColor: riskColor,
        elevation: Td3.elevHigh,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.city,
                        style: TextStyle(
                          color: t.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      if ((data.riverName ?? '').isNotEmpty)
                        Text(
                          data.riverName!,
                          style: TextStyle(
                              color: t.textSecondary, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                Td3Badge(
                  label: data.riskLevel.toUpperCase(),
                  color: riskColor,
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Fill progress
            Row(
              children: [
                Text('Fill', style: TextStyle(color: t.textSecondary, fontSize: 11)),
                const Spacer(),
                Text(
                  '${fillPct.toStringAsFixed(1)}%',
                  style: TextStyle(
                      color: riskColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Td3ProgressBar(
              value: (fillPct / 100).clamp(0.0, 1.0),
              fillColor: riskColor,
              height: 8,
            ),

            const SizedBox(height: 10),

            // Stat row
            Row(
              children: [
                if (data.currentLevel != null)
                  _statLabel('Level', '${data.currentLevel!.toStringAsFixed(2)} m', t),
                if (data.dangerLevel != null) ...[
                  const SizedBox(width: 16),
                  _statLabel('Danger', '${data.dangerLevel!.toStringAsFixed(2)} m', t),
                ],
                if (data.district.isNotEmpty) ...[
                  const Spacer(),
                  Text(
                    data.district,
                    style:
                        TextStyle(color: t.textSecondary, fontSize: 11),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statLabel(String label, String value, RiverColors t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                TextStyle(color: t.textSecondary, fontSize: 10)),
        Text(value,
            style: TextStyle(
                color: t.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  Color _riskToColor(String risk, RiverColors t) {
    switch (risk.toUpperCase()) {
      case 'CRITICAL': return AppPalette.critical;
      case 'SEVERE':   return AppPalette.danger;
      case 'WARNING':  return AppPalette.warning;
      case 'SAFE':     return AppPalette.safe;
      default:         return t.accent;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final RiverColors t;
  final String      query;
  const _EmptyState({required this.t, required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.water_outlined, size: 56, color: t.accent),
            const SizedBox(height: 16),
            Text(
              query.isNotEmpty
                  ? 'No results for "$query"'
                  : 'No river data available',
              style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              query.isNotEmpty
                  ? 'Try a different search term'
                  : 'Pull down to refresh',
              style:
                  TextStyle(color: t.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
