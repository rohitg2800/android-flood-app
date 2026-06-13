// lib/screens/state_matrix_screen.dart
// EQUINOX-BH — StateMatrixScreen v3
// ─────────────────────────────────────────────────────────────────────────────
// Phase 7 upgrades over v2:
//  1. Hero summary bar  — critical / danger / warning / normal counts with
//                         animated number cross-fade
//  2. Staggered card entry — each card FadeTransition + SlideTransition driven
//                            by a single AnimationController, offset per index
//  3. Risk ring (CustomPainter) — small donut showing station severity split
//                                  on each card
//  4. Sheet CTAs — «View City» + «Predict» buttons inside detail bottom-sheet
//  5. Haptic feedback on card tap + sort change
//  6. Animated sort transition — AnimatedSwitcher on the list
//  7. Empty-state illustration when search yields 0 results
// ─────────────────────────────────────────────────────────────────────────────
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ml/flood_engine.dart';
import '../models/flood_data.dart';
import '../providers/flood_providers.dart';
import '../theme/river_theme.dart';
import '../utils/flood_severity_helper.dart';

enum _Sort { alpha, risk, count }

// ─── screen ────────────────────────────────────────────────────────────────────

class StateMatrixScreen extends ConsumerStatefulWidget {
  const StateMatrixScreen({super.key});
  static const String route = '/state_matrix';

  @override
  ConsumerState<StateMatrixScreen> createState() =>
      _StateMatrixScreenState();
}

class _StateMatrixScreenState extends ConsumerState<StateMatrixScreen>
    with SingleTickerProviderStateMixin {
  String _regionFilter = 'ALL';
  String _searchQuery  = '';
  _Sort  _sort         = _Sort.risk;

  // stagger controller — re-fired on filter / sort change
  late final AnimationController _staggerCtrl;

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..forward();
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  void _resetStagger() {
    _staggerCtrl
      ..reset()
      ..forward();
  }

  static const _regionColors = {
    'PLAINS':    Color(0xFF2ECC71),
    'COASTAL':   Color(0xFF00B4D8),
    'HIMALAYAN': Color(0xFF9B59B6),
    'NORTHEAST': Color(0xFFF39C12),
    'ARID':      Color(0xFFE67E22),
    'ISLAND':    Color(0xFF1ABC9C),
    'URBAN_UT':  Color(0xFFE74C3C),
  };

  Color _regionColor(String r) =>
      _regionColors[r.toUpperCase()] ?? AppPalette.textGrey;

  List<FloodData> _liveForState(String k, List<FloodData> live) {
    final lk = k.toLowerCase();
    return live
        .where((fd) => fd.state.toLowerCase().contains(lk))
        .toList();
  }

  FloodSeverity _worstSeverity(List<FloodData> stations) {
    if (stations.isEmpty) return FloodSeverity.normal;
    return stations
        .map((fd) => FloodSeverityHelper.fromString(fd.status))
        .reduce((a, b) => a.index > b.index ? a : b);
  }

  List<MapEntry<String, StateEntry>> _filtered(List<FloodData> live) {
    var list = stateSeverityMatrix.entries.where((e) {
      final matchRegion = _regionFilter == 'ALL' ||
          e.value.region.toUpperCase() == _regionFilter;
      final matchSearch = _searchQuery.isEmpty ||
          e.key.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchRegion && matchSearch;
    }).toList();

    switch (_sort) {
      case _Sort.alpha:
        list.sort((a, b) => a.key.compareTo(b.key));
      case _Sort.risk:
        list.sort((a, b) {
          final sa = _worstSeverity(_liveForState(a.key, live));
          final sb = _worstSeverity(_liveForState(b.key, live));
          return sb.index - sa.index;
        });
      case _Sort.count:
        list.sort((a, b) {
          final ca = _liveForState(a.key, live).length;
          final cb = _liveForState(b.key, live).length;
          return cb - ca;
        });
    }
    return list;
  }

  // ---- severity buckets across all live data --------------------------------
  Map<String, int> _severityCounts(List<FloodData> live) {
    int critical = 0, danger = 0, warning = 0, normal = 0;
    for (final fd in live) {
      final s = FloodSeverityHelper.fromString(fd.status);
      if (s.index >= FloodSeverity.critical.index) {
        critical++;
      } else if (s.index >= FloodSeverity.danger.index)  danger++;
      else if (s.index >= FloodSeverity.warning.index) warning++;
      else                                             normal++;
    }
    return {
      'CRITICAL': critical,
      'DANGER':   danger,
      'WARNING':  warning,
      'NORMAL':   normal,
    };
  }

  @override
  Widget build(BuildContext context) {
    final live     = ref.watch(liveLevelsProvider);
    final filtered = _filtered(live);
    final counts   = _severityCounts(live);

    return Scaffold(
      backgroundColor: AppPalette.abyss0,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [

          // ── App Bar ─────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: AppPalette.abyss0,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppPalette.safe, Color(0xFF27AE60)]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.map_outlined,
                      color: Colors.white, size: 17),
                ),
                const SizedBox(width: 10),
                const Text(
                  'State Matrix',
                  style: TextStyle(
                      color: AppPalette.textWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),

          // ── Hero summary bar ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: _HeroSummaryBar(counts: counts, total: live.length),
            ),
          ),

          // ── Search + filters ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: AppPalette.abyss0,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: Column(
                children: [
                  TextField(
                    onChanged: (v) {
                      setState(() => _searchQuery = v);
                      _resetStagger();
                    },
                    style: const TextStyle(
                        color: AppPalette.textWhite, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search state…',
                      hintStyle: const TextStyle(
                          color: AppPalette.textGrey, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppPalette.gold, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: AppPalette.textGrey,
                                  size: 16),
                              onPressed: () {
                                setState(() => _searchQuery = '');
                                _resetStagger();
                              },
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip('ALL', AppPalette.cyan),
                        ..._regionColors.entries
                            .map((e) => _chip(e.key, e.value)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text('Sort:',
                          style: TextStyle(
                              color: AppPalette.textGrey,
                              fontSize: 11)),
                      const SizedBox(width: 8),
                      _sortChip('A-Z', _Sort.alpha),
                      const SizedBox(width: 6),
                      _sortChip('⚡ Risk', _Sort.risk),
                      const SizedBox(width: 6),
                      _sortChip('📍 Stations', _Sort.count),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Stats row ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
              child: Row(
                children: [
                  _statBadge(
                      '${filtered.length} States', AppPalette.cyan),
                  const SizedBox(width: 8),
                  _statBadge(
                      '${live.length} Live', AppPalette.gold),
                  const SizedBox(width: 8),
                  if ((counts['CRITICAL'] ?? 0) > 0)
                    _statBadge(
                        '${counts['CRITICAL']} Critical',
                        AppPalette.critical),
                ],
              ),
            ),
          ),

          // ── Empty state ──────────────────────────────────────────────────────
          if (filtered.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_off_rounded,
                        color: AppPalette.textGrey.withValues(alpha: 0.4),
                        size: 52),
                    const SizedBox(height: 12),
                    Text(
                      'No states match “$_searchQuery”',
                      style: const TextStyle(
                          color: AppPalette.textGrey, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => setState(() {
                        _searchQuery  = '';
                        _regionFilter = 'ALL';
                        _resetStagger();
                      }),
                      child: const Text(
                        'Clear filters',
                        style: TextStyle(
                            color: AppPalette.cyan,
                            fontSize: 12,
                            decoration: TextDecoration.underline,
                            decorationColor: AppPalette.cyan),
                      ),
                    ),
                  ],
                ),
              ),
            )

          // ── State cards (staggered) ───────────────────────────────────────────
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final entry        = filtered[i];
                    final liveStations = _liveForState(entry.key, live);
                    // per-card stagger: each card starts 50 ms after previous
                    final delay  = (i * 0.05).clamp(0.0, 0.85);
                    final end    = (delay + 0.22).clamp(0.0, 1.0);
                    final fade   = Tween<double>(begin: 0, end: 1).animate(
                        CurvedAnimation(
                            parent: _staggerCtrl,
                            curve: Interval(delay, end,
                                curve: Curves.easeOut)));
                    final slide  = Tween<Offset>(
                            begin: const Offset(0, 0.05),
                            end: Offset.zero)
                        .animate(CurvedAnimation(
                            parent: _staggerCtrl,
                            curve: Interval(delay, end,
                                curve: Curves.easeOutCubic)));

                    return FadeTransition(
                      opacity: fade,
                      child: SlideTransition(
                        position: slide,
                        child: _StateCard(
                          entry:       entry,
                          liveStations: liveStations,
                          regionColor:  _regionColor(entry.value.region),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _showDetail(
                                ctx, entry.key,
                                entry.value, liveStations);
                          },
                        ),
                      ),
                    );
                  },
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── chip helpers ──────────────────────────────────────────────────────────────

  Widget _chip(String label, Color color) {
    final sel = _regionFilter == label;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _regionFilter = label);
        _resetStagger();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 7),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: sel
              ? color.withValues(alpha: 0.20)
              : AppPalette.abyss2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: sel ? color : AppPalette.abyssStroke),
        ),
        child: Text(label,
            style: TextStyle(
                color: sel ? color : AppPalette.textGrey,
                fontSize: 11,
                fontWeight:
                    sel ? FontWeight.w700 : FontWeight.normal)),
      ),
    );
  }

  Widget _sortChip(String label, _Sort mode) {
    final sel = _sort == mode;
    return GestureDetector(
      onTap: () {
        if (_sort == mode) return;
        HapticFeedback.selectionClick();
        setState(() => _sort = mode);
        _resetStagger();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: sel
              ? AppPalette.gold.withValues(alpha: 0.15)
              : AppPalette.abyss2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: sel ? AppPalette.gold : AppPalette.abyssStroke),
        ),
        child: Text(label,
            style: TextStyle(
                color: sel ? AppPalette.gold : AppPalette.textGrey,
                fontSize: 10,
                fontWeight:
                    sel ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }

  Widget _statBadge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      );

  // ── detail sheet ─────────────────────────────────────────────────────────────

  void _showDetail(
    BuildContext context,
    String name,
    StateEntry e,
    List<FloodData> liveStations,
  ) {
    final color = _regionColor(e.region);
    final displayName = name
        .split(' ')
        .map((w) =>
            w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w)
        .join(' ');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.58,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        builder: (ctx2, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF060F1C),
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
                top: BorderSide(
                    color: Color(0x2200C6FF), width: 1.5)),
          ),
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(20),
            children: [
              // handle
              Center(
                child: Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: AppPalette.abyssStroke,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // header: name + region + risk ring
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                              color: AppPalette.textWhite,
                              fontSize: 18,
                              fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: color.withValues(alpha: 0.4)),
                          ),
                          child: Text(e.region,
                              style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  if (liveStations.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: SizedBox(
                        width: 64, height: 64,
                        child: CustomPaint(
                          painter: _RiskRingPainter(
                              stations: liveStations),
                          child: Center(
                            child: Text(
                              '${liveStations.length}\nstns',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppPalette.textWhite,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // thresholds
              Row(
                children: [
                  _thresholdCell(
                      'Warning', '${e.warningLevelM} m',
                      AppPalette.warning),
                  const SizedBox(width: 6),
                  _thresholdCell(
                      'Danger', '${e.dangerLevelM} m',
                      AppPalette.danger),
                  const SizedBox(width: 6),
                  _thresholdCell(
                      'HFL', '${e.hflM} m',
                      AppPalette.critical),
                ],
              ),
              const SizedBox(height: 14),

              // rivers
              if (e.primaryRivers.isNotEmpty) ...[
                const Text('Primary Rivers',
                    style: TextStyle(
                        color: AppPalette.textGrey, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: e.primaryRivers
                      .map((r) => Container(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppPalette.cyan
                                  .withValues(alpha: 0.10),
                              borderRadius:
                                  BorderRadius.circular(6),
                              border: Border.all(
                                  color: AppPalette.cyan
                                      .withValues(alpha: 0.30)),
                            ),
                            child: Text(r,
                                style: const TextStyle(
                                    color: AppPalette.cyan,
                                    fontSize: 12)),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
              ],

              // vulnerable districts
              if (e.vulnerableDistricts.isNotEmpty) ...[
                const Text('Vulnerable Districts',
                    style: TextStyle(
                        color: AppPalette.textGrey, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  e.vulnerableDistricts.join(', '),
                  style: const TextStyle(
                      color: AppPalette.textDim,
                      fontSize: 12,
                      height: 1.4),
                ),
                const SizedBox(height: 14),
              ],

              // live stations list
              if (liveStations.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.sensors_rounded,
                        color: AppPalette.gold, size: 13),
                    const SizedBox(width: 5),
                    Text(
                      '${liveStations.length} Live Station'
                      '${liveStations.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: AppPalette.textGrey,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...liveStations
                    .take(6)
                    .map((fd) => _LiveStationRow(
                          data: fd,
                          onCityTap: () {
                            Navigator.pop(ctx2);
                            Navigator.pushNamed(
                              ctx2,
                              '/city_detail',
                              arguments: fd.city,
                            );
                          },
                        )),
              ],

              const SizedBox(height: 18),

              // ── CTAs ──────────────────────────────────────────────────
              if (liveStations.isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(
                      child: _CtaButton(
                        label: 'View City Detail',
                        icon:  Icons.location_city_rounded,
                        color: AppPalette.cyan,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(ctx2);
                          Navigator.pushNamed(
                            ctx2,
                            '/city_detail',
                            arguments:
                                liveStations.first.city,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CtaButton(
                        label: 'Run Prediction',
                        icon:  Icons.psychology_rounded,
                        color: AppPalette.gold,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(ctx2);
                          Navigator.pushNamed(
                            ctx2,
                            '/predict',
                            arguments: {
                              'city':        liveStations.first.city,
                              'river_level':
                                  liveStations.first.currentLevel,
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _thresholdCell(
          String label, String value, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              Text(label,
                  style: const TextStyle(
                      color: AppPalette.textGrey,
                      fontSize: 10)),
            ],
          ),
        ),
      );
}

// ─── Hero Summary Bar ──────────────────────────────────────────────────────────────

class _HeroSummaryBar extends StatelessWidget {
  final Map<String, int> counts;
  final int              total;
  const _HeroSummaryBar(
      {required this.counts, required this.total});

  static const _items = [
    ('CRITICAL', AppPalette.critical, Icons.crisis_alert_rounded),
    ('DANGER',   AppPalette.danger,   Icons.warning_rounded),
    ('WARNING',  AppPalette.amber,    Icons.warning_amber_rounded),
    ('NORMAL',   AppPalette.safe,     Icons.check_circle_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.abyss1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.abyssStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // title row
          Row(
            children: [
              const Icon(Icons.sensors_rounded,
                  color: AppPalette.gold, size: 13),
              const SizedBox(width: 6),
              Text(
                '$total live stations across India',
                style: const TextStyle(
                    color: AppPalette.textGrey,
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // four severity tiles
          Row(
            children: _items.map((item) {
              final n = counts[item.$1] ?? 0;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(
                      vertical: 10),
                  decoration: BoxDecoration(
                    color: item.$2.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: item.$2.withValues(alpha: 0.22)),
                  ),
                  child: Column(
                    children: [
                      Icon(item.$3, color: item.$2, size: 14),
                      const SizedBox(height: 5),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: Text(
                          '$n',
                          key: ValueKey(n),
                          style: TextStyle(
                              color: item.$2,
                              fontSize: 18,
                              fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text(
                        item.$1,
                        style: TextStyle(
                            color: item.$2.withValues(alpha: 0.7),
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          // severity bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: _items.map((item) {
                final n = counts[item.$1] ?? 0;
                final frac = total == 0 ? 0.0 : n / total;
                return frac == 0
                    ? const SizedBox.shrink()
                    : Expanded(
                        flex: n,
                        child: Container(
                          height: 5,
                          color: item.$2,
                        ),
                      );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── State Card ───────────────────────────────────────────────────────────────────

class _StateCard extends StatelessWidget {
  final MapEntry<String, StateEntry> entry;
  final List<FloodData> liveStations;
  final Color regionColor;
  final VoidCallback onTap;

  const _StateCard({
    required this.entry,
    required this.liveStations,
    required this.regionColor,
    required this.onTap,
  });

  FloodSeverity get _worst {
    if (liveStations.isEmpty) return FloodSeverity.normal;
    return liveStations
        .map((fd) => FloodSeverityHelper.fromString(fd.status))
        .reduce((a, b) => a.index > b.index ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final e         = entry.value;
    final name      = entry.key
        .split(' ')
        .map((w) =>
            w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w)
        .join(' ');
    final worst     = _worst;
    final liveColor = liveStations.isEmpty
        ? AppPalette.textGrey
        : FloodSeverityHelper.color(worst);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppPalette.abyss1,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: liveStations.isEmpty
                ? AppPalette.abyssStroke
                : FloodSeverityHelper.cardBorder(worst),
            width: liveStations.isEmpty ? 0.8 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          color: AppPalette.textWhite,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ),
                // mini risk ring
                if (liveStations.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: SizedBox(
                      width: 28, height: 28,
                      child: CustomPaint(
                        painter: _RiskRingPainter(
                            stations: liveStations,
                            strokeWidth: 3.5),
                      ),
                    ),
                  ),
                // region badge
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: regionColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: regionColor.withValues(alpha: 0.38)),
                  ),
                  child: Text(e.region,
                      style: TextStyle(
                          color: regionColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ),
                // live severity badge
                if (liveStations.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: liveColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: liveColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '${liveStations.length} ● '
                      '${FloodSeverityHelper.label(worst)}',
                      style: TextStyle(
                          color: liveColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                _cell('Warning', '${e.warningLevelM} m',
                    AppPalette.warning),
                const SizedBox(width: 5),
                _cell('Danger', '${e.dangerLevelM} m',
                    AppPalette.danger),
                const SizedBox(width: 5),
                _cell('HFL', '${e.hflM} m',
                    AppPalette.critical),
              ],
            ),
            if (e.primaryRivers.isNotEmpty) ...[
              const SizedBox(height: 7),
              Row(
                children: [
                  const Icon(Icons.water_rounded,
                      color: AppPalette.cyan, size: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      e.primaryRivers.take(3).join(', '),
                      style: const TextStyle(
                          color: AppPalette.textGrey,
                          fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cell(String label, String value, Color color) =>
      Expanded(
        child: Container(
          padding:
              const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
                color: color.withValues(alpha: 0.20)),
          ),
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              Text(label,
                  style: const TextStyle(
                      color: AppPalette.textGrey, fontSize: 9)),
            ],
          ),
        ),
      );
}

// ─── Risk Ring Painter (donut showing severity split) ────────────────────────────

class _RiskRingPainter extends CustomPainter {
  final List<FloodData> stations;
  final double strokeWidth;
  const _RiskRingPainter({
    required this.stations,
    this.strokeWidth = 5.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx   = size.width  / 2;
    final cy   = size.height / 2;
    final r    = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    final total = stations.length.toDouble();

    // bucket by severity
    final buckets = <FloodSeverity, int>{};
    for (final fd in stations) {
      final s = FloodSeverityHelper.fromString(fd.status);
      buckets[s] = (buckets[s] ?? 0) + 1;
    }

    // sort descending so critical is painted first
    final sorted = buckets.entries.toList()
      ..sort((a, b) => b.key.index - a.key.index);

    double startAngle = -math.pi / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // track
    canvas.drawCircle(
      Offset(cx, cy), r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = AppPalette.abyssStroke,
    );

    for (final entry in sorted) {
      final sweep = math.pi * 2 * entry.value / total;
      paint.color =
          FloodSeverityHelper.color(entry.key);
      canvas.drawArc(
          rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(_RiskRingPainter old) =>
      old.stations.length != stations.length;
}

// ─── Live Station Row ─────────────────────────────────────────────────────────────

class _LiveStationRow extends StatelessWidget {
  final FloodData    data;
  final VoidCallback onCityTap;
  const _LiveStationRow(
      {required this.data, required this.onCityTap});

  @override
  Widget build(BuildContext context) {
    final sev   = FloodSeverityHelper.fromString(data.status);
    final color = FloodSeverityHelper.color(sev);

    return GestureDetector(
      onTap: onCityTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppPalette.abyss2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: FloodSeverityHelper.cardBorder(sev),
              width: 0.8),
        ),
        child: Row(
          children: [
            Icon(FloodSeverityHelper.icon(sev),
                color: color, size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Text(data.city,
                  style: const TextStyle(
                      color: AppPalette.textWhite,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ),
            Text(
                '${data.currentLevel.toStringAsFixed(2)} m',
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                color: AppPalette.textDim, size: 14),
          ],
        ),
      ),
    );
  }
}

// ─── CTA Button ───────────────────────────────────────────────────────────────────

class _CtaButton extends StatelessWidget {
  final String   label;
  final IconData icon;
  final Color    color;
  final VoidCallback onTap;
  const _CtaButton({
    required this.label, required this.icon,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: color.withValues(alpha: 0.40)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
              ),
            ],
          ),
        ),
      );
}
