// lib/screens/city_detail_screen.dart  v6.3
// Fixed: d.city/district/state (String?) null guards throughout
//   — d.city?.toLowerCase()  →  used with ?. operator
//   — data.district ?? '' / data.state ?? '' passed to widgets expecting String
//   — _HeroBackground district param is now String? (rendered with null-guard)
//   — _MetaCard rows guard district/state with ?? ''
//   — WatchButton cityName uses data.city ?? data.stationName
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/flood_data.dart';
import '../providers/flood_providers.dart';
import '../providers/bihar_prediction_provider.dart';
import '../models/flood_prediction.dart';
import '../theme/river_theme.dart';

import '../app_router.dart';
import '../widgets/watch_button.dart';
import '../widgets/sync_status_banner.dart';
import '../widgets/sparkline_card.dart';

class CityDetailScreen extends ConsumerStatefulWidget {
  final String  cityName;
  final double? liveLevel;
  final String? liveRisk;
  const CityDetailScreen({
    super.key,
    required this.cityName,
    this.liveLevel,
    this.liveRisk,
  });
  static const String route = Routes.cityDetail;

  @override
  ConsumerState<CityDetailScreen> createState() => _CityDetailScreenState();
}

class _CityDetailScreenState extends ConsumerState<CityDetailScreen>
    with TickerProviderStateMixin {
  late final AnimationController _heroAnim;
  late final AnimationController _pulseAnim;
  late final Animation<double>   _heroScale;
  late final Animation<double>   _heroBg;
  late final Animation<double>   _pulse;

  @override
  void initState() {
    super.initState();
    _heroAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..forward();
    _pulseAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _heroScale = Tween<double>(begin: 0.88, end: 1.0)
        .animate(CurvedAnimation(parent: _heroAnim, curve: Curves.easeOutBack));
    _heroBg    = CurvedAnimation(parent: _heroAnim, curve: Curves.easeOut);
    _pulse     = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseAnim, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _heroAnim.dispose();
    _pulseAnim.dispose();
    super.dispose();
  }

  Color _riskColor(String risk, RiverColors t) {
    switch (risk.toUpperCase()) {
      case 'CRITICAL': return AppPalette.critical;
      case 'SEVERE':   return AppPalette.danger;
      case 'MODERATE': return AppPalette.warning;
      default:         return AppPalette.safe;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t    = RiverColors.of(context);
    final all  = ref.watch(liveLevelsProvider);
    final city = widget.cityName;

    FloodData? data;
    try {
      data = all.firstWhere(
          (d) => (d.city?.toLowerCase() ?? '') == city.toLowerCase());
    } catch (_) {
      try {
        data = all.firstWhere(
            (d) => (d.city?.toLowerCase() ?? '').contains(city.toLowerCase()));
      } catch (_) {
        data = null;
      }
    }

    if (data == null) {
      return _NotFoundScaffold(cityName: city, t: t);
    }

    final double currentLevel = widget.liveLevel ?? data.currentLevel;
    final String riskLevel    = widget.liveRisk  ?? data.riskLevel;
    final double fillPct      = data.dangerLevel > 0
        ? (currentLevel / data.dangerLevel * 100).clamp(0.0, 150.0)
        : data.fillPercent ?? 0.0;
    final double pctVal       = (fillPct / 100).clamp(0.0, 1.0);

    final rc = _riskColor(riskLevel, t);

    final predAsync = ref.watch(
        biharPredictionProvider((data.stationId, city)));

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: t.navBg,
            foregroundColor: t.textPrimary,
            flexibleSpace: FlexibleSpaceBar(
              background: AnimatedBuilder(
                animation: _heroAnim,
                builder: (_, __) => Opacity(
                  opacity: _heroBg.value,
                  child: _HeroBackground(
                    riskColor: rc,
                    fillPct:   fillPct,
                    cityName:  city,
                    river:     data!.riverName ?? '',
                    district:  data.district   ?? '',
                    riskLabel: riskLevel.toUpperCase(),
                    t:         t,
                    scaleAnim: _heroScale,
                    pulse:     _pulse,
                  ),
                ),
              ),
            ),
            actions: [
              WatchButton(
                stationId: data.stationId,
                cityName:  data.city ?? data.stationName,
                riverName: data.riverName ?? '',
              ),
              IconButton(
                icon: Icon(Icons.sos_rounded, color: AppPalette.critical),
                tooltip: 'SOS',
                onPressed: () => Navigator.of(context).pushNamed(Routes.sos),
              ),
              IconButton(
                icon: Icon(Icons.map_outlined, color: t.accent),
                tooltip: 'View on Map',
                onPressed: () =>
                    Navigator.of(context).pushNamed(Routes.biharRiverMap),
              ),
            ],
          ),

          const SliverToBoxAdapter(child: SyncStatusBanner()),

          if (riskLevel.toUpperCase() != 'SAFE' &&
              riskLevel.toUpperCase() != 'NORMAL')
            SliverToBoxAdapter(
              child: _ThresholdBanner(risk: riskLevel, rc: rc, t: t),
            ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _StatsGrid(
                  data: data, rc: rc, t: t,
                  fillPct: fillPct, currentLevel: currentLevel),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _GaugeCard(
                  fillPct: fillPct, pctVal: pctVal, rc: rc, t: t),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: SparklineCard(
                stationId:   data.stationId,
                dangerLevel: data.dangerLevel,
                accentColor: rc,
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: predAsync.when(
                loading: () => _MlLoadingCard(t: t),
                error:   (_, __) => const SizedBox.shrink(),
                data:    (pred)  => _MlCard(pred: pred, t: t),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _QuickActions(
                  cityName: city, riskLevel: riskLevel, t: t),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              child: _MetaCard(data: data, t: t),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'city_sos',
        backgroundColor: AppPalette.critical,
        foregroundColor: Colors.white,
        child: const Icon(Icons.sos_rounded),
        onPressed: () => Navigator.of(context).pushNamed(Routes.sos),
      ),
    );
  }
}

// ── ML loading placeholder ────────────────────────────────────────────────────

class _MlLoadingCard extends StatelessWidget {
  final RiverColors t;
  const _MlLoadingCard({required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppPalette.gold.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppPalette.gold),
            ),
          ),
          const SizedBox(width: 12),
          Text('Loading ML prediction…',
              style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── ML prediction card ─────────────────────────────────────────────────────────

class _MlCard extends StatelessWidget {
  final FloodPrediction pred;
  final RiverColors     t;
  const _MlCard({required this.pred, required this.t});

  Color _severityColor() {
    switch (pred.severity.toUpperCase()) {
      case 'CRITICAL': return AppPalette.critical;
      case 'SEVERE':   return AppPalette.danger;
      case 'MODERATE': return AppPalette.warning;
      default:         return AppPalette.safe;
    }
  }

  Color _trendColor() {
    switch (pred.trend.toLowerCase()) {
      case 'rising':  return AppPalette.danger;
      case 'falling': return AppPalette.safe;
      default:        return AppPalette.gold;
    }
  }

  IconData _trendIcon() {
    switch (pred.trend.toLowerCase()) {
      case 'rising':  return Icons.trending_up_rounded;
      case 'falling': return Icons.trending_down_rounded;
      default:        return Icons.trending_flat_rounded;
    }
  }

  Color _riskBarColor() {
    if (pred.riskScore >= 85) return AppPalette.critical;
    if (pred.riskScore >= 65) return AppPalette.danger;
    if (pred.riskScore >= 40) return AppPalette.warning;
    return AppPalette.safe;
  }

  @override
  Widget build(BuildContext context) {
    final sev   = _severityColor();
    final trend = _trendColor();
    final bar   = _riskBarColor();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: sev.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
              color: sev.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: AppPalette.gold, size: 16),
              const SizedBox(width: 8),
              Text('ML Flood Prediction',
                  style: TextStyle(
                      color: t.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: sev.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sev.withOpacity(0.5)),
                ),
                child: Text(pred.severity,
                    style: TextStyle(
                        color: sev,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: pred.fromBackend
                  ? AppPalette.safe.withOpacity(0.12)
                  : AppPalette.gold.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: pred.fromBackend
                    ? AppPalette.safe.withOpacity(0.3)
                    : AppPalette.gold.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  pred.fromBackend
                      ? Icons.cloud_done_outlined
                      : Icons.offline_bolt_outlined,
                  color: pred.fromBackend ? AppPalette.safe : AppPalette.gold,
                  size: 11,
                ),
                const SizedBox(width: 4),
                Text(
                  pred.fromBackend ? pred.modelVersion : 'Live Rule Engine',
                  style: TextStyle(
                      color: pred.fromBackend ? AppPalette.safe : AppPalette.gold,
                      fontSize: 10,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          if (pred.predicted24h >= pred.dangerLevel) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppPalette.critical.withOpacity(0.14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppPalette.critical.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_rounded, color: AppPalette.critical, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'BREACH RISK — Predicted level may reach or exceed danger level within 24 h',
                      style: TextStyle(
                          color: AppPalette.critical,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Risk',
                  style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (pred.riskScore / 100).clamp(0.0, 1.0),
                    backgroundColor: bar.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(bar),
                    minHeight: 7,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${pred.riskScore.toInt()}',
                  style: TextStyle(
                      color: bar, fontSize: 13, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MlChip(icon: Icons.verified_outlined,  label: 'Conf.',
                  value: '${pred.confidencePct.toStringAsFixed(0)}%',
                  color: t.accent, t: t),
              const SizedBox(width: 8),
              _MlChip(icon: Icons.show_chart_rounded, label: 'Peak 72h',
                  value: '${pred.predicted72h.toStringAsFixed(2)} m',
                  color: AppPalette.cyan, t: t),
              const SizedBox(width: 8),
              _MlChip(icon: _trendIcon(),             label: 'Trend',
                  value: pred.trend, color: trend, t: t),
            ],
          ),
          const SizedBox(height: 12),
          Text(pred.outlook,
              style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 12,
                  fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

class _MlChip extends StatelessWidget {
  final IconData icon; final String label, value; final Color color; final RiverColors t;
  const _MlChip({required this.icon, required this.label, required this.value, required this.color, required this.t});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(color: t.textSecondary, fontSize: 9, fontWeight: FontWeight.w600)),
            Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ── Hero background ──────────────────────────────────────────────────────────

class _HeroBackground extends StatelessWidget {
  final Color    riskColor;
  final double   fillPct;
  final String   cityName, river, district, riskLabel;
  final RiverColors t;
  final Animation<double> scaleAnim;
  final Animation<double> pulse;
  const _HeroBackground({
    required this.riskColor, required this.fillPct,
    required this.cityName,  required this.river,
    required this.district,  required this.riskLabel,
    required this.t,         required this.scaleAnim,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [riskColor.withOpacity(0.28), t.scaffoldBg],
          begin: Alignment.topCenter,
          end:   Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20, top: 30,
            child: AnimatedBuilder(
              animation: pulse,
              builder: (_, __) => CustomPaint(
                size: const Size(200, 200),
                painter: _ConcentricRingsPainter(
                    color: riskColor, pulse: pulse.value),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment:  MainAxisAlignment.end,
                children: [
                  AnimatedBuilder(
                    animation: scaleAnim,
                    builder: (_, __) => Transform.scale(
                      scale:     scaleAnim.value,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        cityName,
                        style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                          shadows: [
                            Shadow(color: riskColor.withOpacity(0.3), blurRadius: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (river.isNotEmpty)
                    Text('$river River',
                        style: TextStyle(color: t.textSecondary, fontSize: 14)),
                  if (district.isNotEmpty)
                    Text(district,
                        style: TextStyle(color: t.textSecondary, fontSize: 13)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: riskColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: riskColor.withOpacity(0.55), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: riskColor.withOpacity(0.25), blurRadius: 16, spreadRadius: 1),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: riskColor, size: 8),
                        const SizedBox(width: 6),
                        Text(riskLabel,
                            style: TextStyle(
                                color: riskColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 0.8)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('≈ ${fillPct.toStringAsFixed(1)}% fill',
                      style: TextStyle(
                          color: riskColor, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (fillPct / 100).clamp(0.0, 1.0),
                      backgroundColor: riskColor.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(riskColor),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConcentricRingsPainter extends CustomPainter {
  final Color  color;
  final double pulse;
  const _ConcentricRingsPainter({required this.color, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    for (int i = 0; i < 3; i++) {
      final r = [40.0, 65.0, 92.0][i] * pulse;
      canvas.drawCircle(
        Offset(cx, cy), r,
        Paint()
          ..color = color.withOpacity((0.22 - i * 0.06).clamp(0.02, 0.22))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
  }

  @override
  bool shouldRepaint(_ConcentricRingsPainter o) =>
      o.color != color || o.pulse != pulse;
}

// ── Threshold banner ──────────────────────────────────────────────────────────

class _ThresholdBanner extends StatelessWidget {
  final String risk; final Color rc; final RiverColors t;
  const _ThresholdBanner({required this.risk, required this.rc, required this.t});

  @override
  Widget build(BuildContext context) {
    final messages = {
      'CRITICAL': '🚨 CRITICAL — Above HFL. Immediate action required.',
      'SEVERE':   '🔴 SEVERE — Above danger level. Stay alert.',
      'MODERATE': '⚠️ MODERATE — Above warning level. Monitor closely.',
      'DANGER':   '🔴 DANGER — Approaching danger level. Be prepared.',
      'HIGH':     '⚠️ HIGH — Rising rapidly. Monitor closely.',
      'WARNING':  '⚠️ WARNING — Above warning level.',
    };
    final msg = messages[risk.toUpperCase()];
    if (msg == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: rc.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rc.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: rc, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg,
                style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Stats grid ────────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final FloodData data;
  final Color rc;
  final RiverColors t;
  final double fillPct;
  final double currentLevel;
  const _StatsGrid({
    required this.data,
    required this.rc,
    required this.t,
    required this.fillPct,
    required this.currentLevel,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      _S('Current Level', '${currentLevel.toStringAsFixed(2)} m',       Icons.water_drop_outlined,   rc),
      _S('Danger Level',  '${data.dangerLevel.toStringAsFixed(2)} m',   Icons.emergency_outlined,    AppPalette.danger),
      _S('Fill %',        '${fillPct.toStringAsFixed(1)}%',             Icons.show_chart_rounded,    t.accent),
      _S('State',          data.state ?? '—',                           Icons.location_on_outlined,  t.textSecondary),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.4,
      children: stats.map((s) => _StatCell(s: s, t: t)).toList(),
    );
  }
}

class _S { final String label, value; final IconData icon; final Color color; const _S(this.label, this.value, this.icon, this.color); }

class _StatCell extends StatelessWidget {
  final _S s; final RiverColors t;
  const _StatCell({required this.s, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: s.color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: s.color.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: s.color.withOpacity(0.07), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Icon(s.icon, color: s.color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment:  MainAxisAlignment.center,
              children: [
                Text(s.label, style: TextStyle(color: t.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
                Text(s.value, style: TextStyle(color: s.color, fontSize: 14, fontWeight: FontWeight.w800),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated fill gauge card ──────────────────────────────────────────────────

class _GaugeCard extends StatefulWidget {
  final double fillPct, pctVal; final Color rc; final RiverColors t;
  const _GaugeCard({required this.fillPct, required this.pctVal, required this.rc, required this.t});
  @override
  State<_GaugeCard> createState() => _GaugeCardState();
}

class _GaugeCardState extends State<_GaugeCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
    _anim = Tween<double>(begin: 0, end: widget.pctVal)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final t = widget.t; final rc = widget.rc;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: rc.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: rc.withOpacity(0.10), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.water_drop_outlined, color: rc, size: 18),
              const SizedBox(width: 8),
              Text('Fill Level', style: TextStyle(color: t.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
              const Spacer(),
              AnimatedBuilder(
                animation: _anim,
                builder: (_, __) => Text(
                  '${(_anim.value * 100).toStringAsFixed(1)}%',
                  style: TextStyle(color: rc, fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      Container(height: 20, color: rc.withOpacity(0.10)),
                      FractionallySizedBox(
                        widthFactor: _anim.value,
                        child: Container(
                          height: 20,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [rc, rc.withOpacity(0.7)]),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0%',   style: TextStyle(color: t.textSecondary, fontSize: 10)),
                    Text('50%',  style: TextStyle(color: t.textSecondary, fontSize: 10)),
                    Text('100%', style: TextStyle(color: t.textSecondary, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick actions ─────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  final String cityName, riskLevel; final RiverColors t;
  const _QuickActions({required this.cityName, required this.riskLevel, required this.t});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions',
            style: TextStyle(color: t.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(
          children: [
            _ActionBtn(icon: Icons.directions_run,          label: 'Evacuate', color: Colors.deepOrange,
                onTap: () => Navigator.of(context).pushNamed(Routes.evacuation)),
            const SizedBox(width: 10),
            _ActionBtn(icon: Icons.map_outlined,            label: 'View Map', color: Colors.blue,
                onTap: () => Navigator.of(context).pushNamed(Routes.biharRiverMap)),
            const SizedBox(width: 10),
            _ActionBtn(icon: Icons.auto_graph,              label: 'Predict',  color: const Color(0xFF7B2FF7),
                onTap: () => Navigator.of(context).pushNamed(Routes.predict)),
            const SizedBox(width: 10),
            _ActionBtn(icon: Icons.report_problem_outlined, label: 'Report',   color: Colors.red,
                onTap: () => Navigator.of(context).pushNamed(Routes.incidentReport)),
          ],
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 5),
              Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Metadata card ─────────────────────────────────────────────────────────────

class _MetaCard extends StatelessWidget {
  final FloodData data; final RiverColors t;
  const _MetaCard({required this.data, required this.t});

  @override
  Widget build(BuildContext context) {
    final rows = [
      if ((data.riverName ?? '').isNotEmpty)
        _MR('River',         data.riverName!,              Icons.water_outlined),
      if ((data.district ?? '').isNotEmpty)
        _MR('District',      data.district!,               Icons.location_city_outlined),
      if ((data.state ?? '').isNotEmpty)
        _MR('State',         data.state!,                  Icons.map_outlined),
      _MR('Station ID',    data.stationId,                 Icons.badge_outlined),
      if (data.lastUpdated != null)
        _MR('Last Updated', _fmt(data.lastUpdated!),       Icons.access_time_rounded),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.divider.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: t.accent, size: 18),
              const SizedBox(width: 8),
              Text('Station Details',
                  style: TextStyle(color: t.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 14),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(r.icon, color: t.accent, size: 15),
                    const SizedBox(width: 10),
                    Text(r.label, style: TextStyle(color: t.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Flexible(
                      child: Text(r.value,
                          textAlign: TextAlign.end,
                          style: TextStyle(color: t.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year}  $h:$m';
  }
}

class _MR { final String label, value; final IconData icon; const _MR(this.label, this.value, this.icon); }

// ── Not-found scaffold ────────────────────────────────────────────────────────

class _NotFoundScaffold extends StatelessWidget {
  final String cityName; final RiverColors t;
  const _NotFoundScaffold({required this.cityName, required this.t});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        title: Text(cityName),
        backgroundColor: t.navBg,
        foregroundColor: t.textPrimary,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 64, color: t.textSecondary),
              const SizedBox(height: 16),
              Text('No data found for "$cityName"',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: t.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Data may not be available for this location yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: t.textSecondary, fontSize: 13)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Go Back'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
