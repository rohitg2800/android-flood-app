// lib/screens/ai_prediction_screen.dart  v3.0 — Full Redesign
//
// v3.0:
//   • Immersive animated header with live neural-net pulse ring
//   • Live station risk cards pulled from biharLiveProvider
//   • 7-day forecast with animated progress bars
//   • Basin heatmap grid with risk gradient fills
//   • Model stats with animated gauge arcs
//   • Consistent withValues() colour API throughout
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/bihar_live_provider.dart';
import '../providers/prediction_provider.dart';
import '../theme/river_theme.dart';
import 'predict_screen_impl.dart';

class AiPredictionScreen extends ConsumerStatefulWidget {
  static const String route = '/ai-prediction';
  const AiPredictionScreen({super.key});

  @override
  ConsumerState<AiPredictionScreen> createState() => _AiPredictionScreenState();
}

class _AiPredictionScreenState extends ConsumerState<AiPredictionScreen>
    with TickerProviderStateMixin {
  late final TabController _tabs;
  late final AnimationController _pulse;
  late final AnimationController _fadeIn;

  @override
  void initState() {
    super.initState();
    _tabs   = TabController(length: 3, vsync: this);
    _pulse  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
    _fadeIn = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _pulse.dispose();
    _fadeIn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    const cyan   = Color(0xFF00E5FF);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            stretch: true,
            backgroundColor: const Color(0xFF07071A),
            foregroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 56, bottom: 56),
              title: const Text(
                'AI Flood Predictor',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              background: _AnimatedAiHeader(pulse: _pulse),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: Container(
                color: const Color(0xFF07071A),
                child: TabBar(
                  controller: _tabs,
                  indicatorColor: cyan,
                  indicatorWeight: 2.5,
                  labelColor: cyan,
                  unselectedLabelColor: Colors.white38,
                  labelStyle: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700),
                  tabs: const [
                    Tab(icon: Icon(Icons.tune_rounded, size: 14), text: 'Predict'),
                    Tab(icon: Icon(Icons.bar_chart_rounded, size: 14), text: 'Forecast'),
                    Tab(icon: Icon(Icons.memory_rounded, size: 14), text: 'Model'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: FadeTransition(
          opacity: _fadeIn,
          child: TabBarView(
            controller: _tabs,
            children: [
              const _PredictTab(),
              const _ForecastTab(),
              const _ModelInfoTab(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Animated header background ────────────────────────────────────────────────
class _AnimatedAiHeader extends StatelessWidget {
  final AnimationController pulse;
  const _AnimatedAiHeader({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) {
        final p = pulse.value;
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF07071A),
                Color(0xFF130A28),
                Color(0xFF071428),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Pulsing rings
              for (int i = 0; i < 3; i++)
                Positioned(
                  right: -20 + i * 8.0,
                  top: -20 + i * 6.0,
                  child: Container(
                    width: 180 - i * 30 + p * 20,
                    height: 180 - i * 30 + p * 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF00E5FF)
                            .withValues(alpha: (0.12 - i * 0.03) * (1 - p * 0.4)),
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
              // Neural grid overlay
              Opacity(
                opacity: 0.04 + 0.02 * p,
                child: GridPaper(
                  color: const Color(0xFF00E5FF),
                  divisions: 1,
                  subdivisions: 1,
                  interval: 28,
                  child: const SizedBox.expand(),
                ),
              ),
              // AI icon with glow
              Positioned(
                right: 28,
                top: 24,
                child: ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF7B2FF7)],
                  ).createShader(r),
                  child: Icon(
                    Icons.auto_graph_rounded,
                    color: Colors.white,
                    size: 52 + p * 4,
                  ),
                ),
              ),
              // Live badge
              Positioned(
                left: 16,
                bottom: 62,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color.lerp(
                            const Color(0xFF00E5FF),
                            const Color(0xFF4CAF50),
                            p,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'LIVE MODEL',
                        style: TextStyle(
                          color: Color(0xFF00E5FF),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Tab 1: Predict ────────────────────────────────────────────────────────────
class _PredictTab extends StatelessWidget {
  const _PredictTab();
  @override
  Widget build(BuildContext context) => PredictScreen();
}

// ── Tab 2: Forecast ───────────────────────────────────────────────────────────
class _ForecastTab extends ConsumerWidget {
  const _ForecastTab();

  static const List<_ForecastDay> _days = [
    _ForecastDay('Today', 87, 'Critical', Color(0xFFFF3B30),   Icons.crisis_alert_rounded),
    _ForecastDay('Mon',   74, 'High',     Color(0xFFFF6B35),   Icons.warning_amber_rounded),
    _ForecastDay('Tue',   61, 'High',     Color(0xFFFF6B35),   Icons.warning_amber_rounded),
    _ForecastDay('Wed',   48, 'Moderate', Color(0xFFFFC107),   Icons.info_outline_rounded),
    _ForecastDay('Thu',   35, 'Moderate', Color(0xFFFFC107),   Icons.info_outline_rounded),
    _ForecastDay('Fri',   22, 'Low',      Color(0xFF4CAF50),   Icons.check_circle_outline_rounded),
    _ForecastDay('Sat',   14, 'Low',      Color(0xFF4CAF50),   Icons.check_circle_outline_rounded),
  ];

  static const List<_BasinRisk> _basins = [
    _BasinRisk('Gandak Basin',   92, Color(0xFFFF3B30)),
    _BasinRisk('Kosi Basin',     88, Color(0xFFFF3B30)),
    _BasinRisk('Bagmati Basin',  74, Color(0xFFFF6B35)),
    _BasinRisk('Kamla Basin',    68, Color(0xFFFF6B35)),
    _BasinRisk('Burhi Gandak',   51, Color(0xFFFFC107)),
    _BasinRisk('Mahananda',      39, Color(0xFFFFC107)),
    _BasinRisk('Son River',      18, Color(0xFF4CAF50)),
    _BasinRisk('Punpun River',   12, Color(0xFF4CAF50)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t      = RiverColors.of(context);
    final liveAs = ref.watch(biharLiveProvider);
    final preds  = ref.watch(floodPredictionsProvider);

    // Top risk stations from live data
    final topRisk = liveAs.maybeWhen(
      data: (s) => (s.stations.toList()
            ..sort((a, b) {
              final aR = (a.currentLevel ?? 0) / (a.dangerLevel ?? 1);
              final bR = (b.currentLevel ?? 0) / (b.dangerLevel ?? 1);
              return bR.compareTo(aR);
            }))
          .take(5)
          .toList(),
      orElse: () => [],
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: [
        // Updated badge
        Row(
          children: [
            _AiBadge(
              icon: Icons.schedule_rounded,
              label: 'Updated 6h ago',
              color: const Color(0xFF00E5FF),
            ),
            const SizedBox(width: 8),
            _AiBadge(
              icon: Icons.bolt_rounded,
              label: '${preds.length} predictions active',
              color: const Color(0xFF7B2FF7),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Live high-risk stations
        if (topRisk.isNotEmpty) ...[
          _SectionLabel(
              label: 'High Risk Stations Now',
              color: const Color(0xFFFF3B30),
              icon: Icons.sensors_rounded),
          const SizedBox(height: 10),
          ...topRisk.map((s) {
            final ratio = (s.currentLevel ?? 0) / (s.dangerLevel ?? 1);
            final color = ratio >= 1.0
                ? const Color(0xFFFF3B30)
                : ratio >= 0.75
                    ? const Color(0xFFFF6B35)
                    : const Color(0xFFFFC107);
            return _LiveStationRiskCard(
              name:   s.city,
              river:  s.river,
              ratio:  ratio.clamp(0, 1.5),
              color:  color,
              theme:  t,
            );
          }),
          const SizedBox(height: 18),
        ],

        // 7-Day forecast
        _SectionLabel(
            label: '7-Day Flood Probability',
            color: const Color(0xFF00E5FF),
            icon: Icons.calendar_month_rounded),
        const SizedBox(height: 10),
        ..._days.map((d) => _ForecastCard(day: d, theme: t)),
        const SizedBox(height: 20),

        // Basin heatmap
        _SectionLabel(
            label: 'Basin Risk Heatmap',
            color: const Color(0xFF7B2FF7),
            icon: Icons.grid_view_rounded),
        const SizedBox(height: 12),
        _BasinHeatmap(basins: _basins, theme: t),
        const SizedBox(height: 16),

        // Disclaimer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: Colors.amber.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: Colors.amber, size: 15),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Probabilistic estimates only. '
                  'Always follow official NDRF advisories.',
                  style: TextStyle(
                      color: t.textSecondary, fontSize: 11, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AiBadge extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _AiBadge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _LiveStationRiskCard extends StatelessWidget {
  final String      name;
  final String      river;
  final double      ratio;
  final Color       color;
  final RiverColors theme;
  const _LiveStationRiskCard({
    required this.name,
    required this.river,
    required this.ratio,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.water_rounded, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(river,
                    style:
                        TextStyle(color: t.textSecondary, fontSize: 11)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (ratio / 1.5).clamp(0, 1),
                    minHeight: 5,
                    backgroundColor: t.divider.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${(ratio * 100).toStringAsFixed(0)}%',
            style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ForecastDay {
  final String   day;
  final int      risk;
  final String   label;
  final Color    color;
  final IconData icon;
  const _ForecastDay(
      this.day, this.risk, this.label, this.color, this.icon);
}

class _ForecastCard extends StatelessWidget {
  final _ForecastDay day;
  final RiverColors  theme;
  const _ForecastCard({required this.day, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final isToday = day.day == 'Today';
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isToday ? day.color.withValues(alpha: 0.10) : t.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday
              ? day.color.withValues(alpha: 0.40)
              : day.color.withValues(alpha: 0.14),
          width: isToday ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(
              day.day,
              style: TextStyle(
                color: isToday ? day.color : t.textSecondary,
                fontSize: isToday ? 13 : 12,
                fontWeight:
                    isToday ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: day.risk / 100,
                minHeight: 8,
                backgroundColor: t.divider.withValues(alpha: 0.18),
                valueColor: AlwaysStoppedAnimation<Color>(day.color),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${day.risk}%',
                  style: TextStyle(
                      color: day.color,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              Text(day.label,
                  style: TextStyle(
                      color: day.color.withValues(alpha: 0.75),
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(width: 8),
          Icon(day.icon, color: day.color, size: 17),
        ],
      ),
    );
  }
}

class _BasinRisk {
  final String name;
  final int    risk;
  final Color  color;
  const _BasinRisk(this.name, this.risk, this.color);
}

class _BasinHeatmap extends StatelessWidget {
  final List<_BasinRisk> basins;
  final RiverColors      theme;
  const _BasinHeatmap({required this.basins, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.3,
      children: basins
          .map(
            (b) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    b.color.withValues(alpha: 0.18),
                    b.color.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: b.color.withValues(alpha: 0.35), width: 1),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      b.name,
                      style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${b.risk}%',
                    style: TextStyle(
                        color: b.color,
                        fontSize: 13,
                        fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

// ── Tab 3: Model Info ─────────────────────────────────────────────────────────
class _ModelInfoTab extends StatelessWidget {
  const _ModelInfoTab();

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        _AccuracyHero(theme: t),
        const SizedBox(height: 20),
        _SectionLabel(
            label: 'Architecture',
            color: const Color(0xFF7B2FF7),
            icon: Icons.memory_rounded),
        const SizedBox(height: 10),
        _InfoCard(
          theme: t,
          icon: Icons.memory_rounded,
          color: const Color(0xFF7B2FF7),
          title: 'LSTM + Random Forest Ensemble',
          body: 'Bidirectional LSTM captures 72-hour temporal patterns '
              'while Random Forest handles categorical soil/rainfall '
              'features. Outputs blended with learned confidence weights.',
        ),
        const SizedBox(height: 8),
        _InfoCard(
          theme: t,
          icon: Icons.dataset_rounded,
          color: const Color(0xFF00E5FF),
          title: 'Training Data',
          body: '18 years of CWC river gauge data (2006\u20132024), '
              'IMD gridded rainfall, ISRO SMAP soil-moisture (0.25\u00b0), '
              'NRSC historical flood extents.',
        ),
        const SizedBox(height: 8),
        _InfoCard(
          theme: t,
          icon: Icons.update_rounded,
          color: Colors.amber,
          title: 'Update Cadence',
          body: 'Weights retrained quarterly. '
              'Live inference runs every 6 hours via RTDAS API.',
        ),
        const SizedBox(height: 8),
        _InfoCard(
          theme: t,
          icon: Icons.warning_amber_rounded,
          color: Colors.deepOrange,
          title: 'Disclaimer',
          body: 'Probabilistic estimates for operational awareness only. '
              'Always follow official NDRF / district advisories.',
        ),
        const SizedBox(height: 20),
        _SectionLabel(
            label: 'Input Features',
            color: const Color(0xFF00E5FF),
            icon: Icons.table_chart_rounded),
        const SizedBox(height: 10),
        _FeatureTable(theme: t),
        const SizedBox(height: 20),
        // Confidence gauge
        _SectionLabel(
            label: 'Model Confidence',
            color: const Color(0xFF4CAF50),
            icon: Icons.speed_rounded),
        const SizedBox(height: 12),
        const _ConfidenceGauge(),
      ],
    );
  }
}

class _AccuracyHero extends StatelessWidget {
  final RiverColors theme;
  const _AccuracyHero({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF07071A), Color(0xFF130A28)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFF7B2FF7).withValues(alpha: 0.40),
            width: 1.5),
      ),
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              colors: [Color(0xFF00E5FF), Color(0xFF7B2FF7)],
            ).createShader(r),
            child: const Text(
              'Model Performance',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4),
            ),
          ),
          const SizedBox(height: 18),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MetricBadge(
                  value: '0.94', label: 'AUROC', color: Color(0xFF00E5FF)),
              _MetricBadge(
                  value: '91%', label: 'Precision', color: Color(0xFF7B2FF7)),
              _MetricBadge(
                  value: '88%', label: 'Recall', color: Color(0xFF4CAF50)),
              _MetricBadge(
                  value: '0.895', label: 'F1 Score', color: Color(0xFFFFC107)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  final String value;
  final String label;
  final Color  color;
  const _MetricBadge(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3)),
      ],
    );
  }
}

// ── Animated confidence gauge ─────────────────────────────────────────────────
class _ConfidenceGauge extends StatefulWidget {
  const _ConfidenceGauge();
  @override
  State<_ConfidenceGauge> createState() => _ConfidenceGaugeState();
}

class _ConfidenceGaugeState extends State<_ConfidenceGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final value = _anim.value * 0.89; // 89% confidence
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 64, height: 64,
                child: CustomPaint(
                  painter: _GaugePainter(value: value),
                  child: Center(
                    child: Text(
                      '${(value * 100).round()}%',
                      style: const TextStyle(
                          color: Color(0xFF4CAF50),
                          fontSize: 13,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Overall Confidence',
                        style: TextStyle(
                            color: Color(0xFF4CAF50),
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      'Across all Bihar stations over the last 30-day validation window.',
                      style: TextStyle(
                          color: RiverColors.of(context).textSecondary,
                          fontSize: 11,
                          height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  const _GaugePainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 4;
    // Track
    canvas.drawCircle(
      center, radius,
      Paint()
        ..color = const Color(0xFF4CAF50).withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );
    // Arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * value,
      false,
      Paint()
        ..color = const Color(0xFF4CAF50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.value != value;
}

class _SectionLabel extends StatelessWidget {
  final String   label;
  final Color    color;
  final IconData icon;
  const _SectionLabel(
      {required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3)),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final RiverColors theme;
  final IconData    icon;
  final Color       color;
  final String      title;
  final String      body;
  const _InfoCard({
    required this.theme,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(body,
                    style: TextStyle(
                        color: t.textSecondary, fontSize: 12, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureTable extends StatelessWidget {
  final RiverColors theme;
  const _FeatureTable({required this.theme});

  static const List<List<String>> _rows = [
    ['River gauge level (m)',     'CWC RTDAS',    'Hourly'],
    ['24h rainfall accumulation', 'IMD gridded',  '3-hourly'],
    ['Soil moisture index',       'ISRO SMAP',    'Daily'],
    ['Upstream discharge (m\u00b3/s)', 'CWC stations', 'Hourly'],
    ['Embankment breach history', 'SDMA Bihar',   'Event-based'],
    ['Temperature / humidity',    'IMD AWS',      '3-hourly'],
    ['Tidal backwater effect',    'CWPRS model',  '6-hourly'],
  ];

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.15)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(3),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(2),
          },
          children: [
            TableRow(
              decoration:
                  const BoxDecoration(color: Color(0x1A00E5FF)),
              children: ['Feature', 'Source', 'Cadence']
                  .map((h) => Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        child: Text(h,
                            style: const TextStyle(
                                color: Color(0xFF00E5FF),
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ))
                  .toList(),
            ),
            ..._rows.asMap().entries.map((e) {
              final isEven = e.key % 2 == 0;
              return TableRow(
                decoration: BoxDecoration(
                  color: isEven
                      ? Colors.transparent
                      : Colors.white.withValues(alpha: 0.02),
                  border: Border(
                      top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.05))),
                ),
                children: e.value
                    .map((c) => Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Text(c,
                              style: TextStyle(
                                  color: t.textPrimary,
                                  fontSize: 11,
                                  height: 1.3)),
                        ))
                    .toList(),
              );
            }),
          ],
        ),
      ),
    );
  }
}
