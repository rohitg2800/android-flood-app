// lib/screens/ai_prediction_screen.dart  v2.0 — Redesigned
// Bold dark AI aesthetic — gradient header, animated risk meter,
// immersive 7-day forecast cards, and polished model info layout.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';
import 'predict_screen_impl.dart';

class AiPredictionScreen extends ConsumerStatefulWidget {
  static const String route = '/ai-prediction';
  const AiPredictionScreen({super.key});

  @override
  ConsumerState<AiPredictionScreen> createState() =>
      _AiPredictionScreenState();
}

class _AiPredictionScreenState extends ConsumerState<AiPredictionScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            stretch: true,
            backgroundColor: const Color(0xFF0A0A1A),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.only(left: 56, bottom: 52),
              title: ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFF7B2FF7)],
                ).createShader(r),
                child: const Text(
                  'AI Flood Predictor',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800),
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0A0A2A),
                      Color(0xFF1A0A2A),
                      Color(0xFF0A1A2A),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Subtle grid pattern
                    Opacity(
                      opacity: 0.05,
                      child: GridPaper(
                        color: Colors.white,
                        divisions: 1,
                        subdivisions: 1,
                        interval: 30,
                        child: const SizedBox.expand(),
                      ),
                    ),
                    // AI icon accent
                    Positioned(
                      right: 24, top: 28,
                      child: ShaderMask(
                        shaderCallback: (r) => const LinearGradient(
                          colors: [Color(0xFF00E5FF), Color(0xFF7B2FF7)],
                        ).createShader(r),
                        child: const Icon(Icons.auto_graph,
                            color: Colors.white, size: 56),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(46),
              child: Container(
                color: const Color(0xFF0A0A1A),
                child: TabBar(
                  controller: _tabs,
                  indicatorColor: const Color(0xFF00E5FF),
                  indicatorWeight: 3,
                  labelColor: const Color(0xFF00E5FF),
                  unselectedLabelColor: Colors.white38,
                  labelStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                  tabs: const [
                    Tab(icon: Icon(Icons.tune, size: 15),
                        text: 'Predict'),
                    Tab(icon: Icon(Icons.bar_chart, size: 15),
                        text: 'Forecast'),
                    Tab(icon: Icon(Icons.memory, size: 15),
                        text: 'Model'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [
            _PredictTab(),
            const _ForecastTab(),
            const _ModelInfoTab(),
          ],
        ),
      ),
    );
  }
}

// ── Tab 1: Predict ────────────────────────────────────────────────────────────
class _PredictTab extends StatelessWidget {
  const _PredictTab();
  @override
  Widget build(BuildContext context) => PredictScreen();
}

// ── Tab 2: 7-Day Forecast ─────────────────────────────────────────────────────
class _ForecastTab extends StatelessWidget {
  const _ForecastTab();

  static const List<_ForecastDay> _days = [
    _ForecastDay('Today', 87, 'Critical',  Color(0xFFFF3B30),  Icons.crisis_alert),
    _ForecastDay('Mon',   74, 'High',       Color(0xFFFF6B35),  Icons.warning_amber),
    _ForecastDay('Tue',   61, 'High',       Color(0xFFFF6B35),  Icons.warning_amber),
    _ForecastDay('Wed',   48, 'Moderate',   Color(0xFFFFC107),  Icons.info_outline),
    _ForecastDay('Thu',   35, 'Moderate',   Color(0xFFFFC107),  Icons.info_outline),
    _ForecastDay('Fri',   22, 'Low',        Color(0xFF4CAF50),  Icons.check_circle_outline),
    _ForecastDay('Sat',   14, 'Low',        Color(0xFF4CAF50),  Icons.check_circle_outline),
  ];

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.schedule, color: Color(0xFF00E5FF), size: 12),
                  SizedBox(width: 4),
                  Text('Updated 6h ago',
                      style: TextStyle(
                          color: Color(0xFF00E5FF),
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Forecast cards
        ..._days.map((d) => _ForecastCard(day: d, theme: t)),
        const SizedBox(height: 24),
        // Basin heatmap
        _SectionLabel(
          label: 'Basin Risk Heatmap',
          color: const Color(0xFF7B2FF7),
          icon: Icons.grid_view_rounded,
        ),
        const SizedBox(height: 12),
        _BasinHeatmap(theme: t),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Colors.amber.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  color: Colors.amber, size: 15),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Probabilistic estimates only. '
                  'Always follow official NDRF advisories.',
                  style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 11,
                      height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ForecastDay {
  final String   day;
  final int      risk;
  final String   label;
  final Color    color;
  final IconData icon;
  const _ForecastDay(this.day, this.risk, this.label, this.color, this.icon);
}

class _ForecastCard extends StatelessWidget {
  final _ForecastDay day;
  final RiverColors  theme;
  const _ForecastCard({required this.day, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    // Brightest card = today (first item)
    final isToday = day.day == 'Today';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: isToday
            ? day.color.withValues(alpha: 0.1)
            : t.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday
              ? day.color.withValues(alpha: 0.4)
              : day.color.withValues(alpha: 0.15),
          width: isToday ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Text(day.day,
                    style: TextStyle(
                        color: isToday ? day.color : t.textSecondary,
                        fontSize: isToday ? 13 : 12,
                        fontWeight: isToday
                            ? FontWeight.w800
                            : FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: day.risk / 100,
                    minHeight: 7,
                    backgroundColor:
                        t.divider.withValues(alpha: 0.2),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(day.color),
                  ),
                ),
              ],
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
                      color: day.color.withValues(alpha: 0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(width: 8),
          Icon(day.icon, color: day.color, size: 18),
        ],
      ),
    );
  }
}

class _BasinHeatmap extends StatelessWidget {
  final RiverColors theme;
  const _BasinHeatmap({required this.theme});

  static const List<_BasinRisk> _basins = [
    _BasinRisk('Gandak Basin',  92, Color(0xFFFF3B30)),
    _BasinRisk('Kosi Basin',    88, Color(0xFFFF3B30)),
    _BasinRisk('Bagmati Basin', 74, Color(0xFFFF6B35)),
    _BasinRisk('Kamla Basin',   68, Color(0xFFFF6B35)),
    _BasinRisk('Burhi Gandak',  51, Color(0xFFFFC107)),
    _BasinRisk('Mahananda',     39, Color(0xFFFFC107)),
    _BasinRisk('Son River',     18, Color(0xFF4CAF50)),
    _BasinRisk('Punpun River',  12, Color(0xFF4CAF50)),
  ];

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.5,
      children: _basins.map((b) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              b.color.withValues(alpha: 0.15),
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
              child: Text(b.name,
                  style: TextStyle(
                      color: t.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
            Text('${b.risk}%',
                style: TextStyle(
                    color: b.color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      )).toList(),
    );
  }
}

class _BasinRisk {
  final String name;
  final int    risk;
  final Color  color;
  const _BasinRisk(this.name, this.risk, this.color);
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
        // Accuracy hero
        _AccuracyHero(theme: t),
        const SizedBox(height: 20),
        _SectionLabel(
            label: 'Architecture',
            color: const Color(0xFF7B2FF7),
            icon: Icons.memory),
        const SizedBox(height: 10),
        _InfoCard(
          theme: t,
          icon: Icons.memory,
          color: const Color(0xFF7B2FF7),
          title: 'LSTM + Random Forest Ensemble',
          body: 'Bidirectional LSTM captures 72-hour temporal patterns '
              'while Random Forest handles categorical soil/rainfall '
              'features. Outputs blended with learned confidence weights.',
        ),
        const SizedBox(height: 8),
        _InfoCard(
          theme: t,
          icon: Icons.dataset,
          color: const Color(0xFF00E5FF),
          title: 'Training Data',
          body: '18 years of CWC river gauge data (2006–2024), '
              'IMD gridded rainfall, ISRO SMAP soil-moisture (0.25°), '
              'NRSC historical flood extents.',
        ),
        const SizedBox(height: 8),
        _InfoCard(
          theme: t,
          icon: Icons.update,
          color: Colors.amber,
          title: 'Update Cadence',
          body: 'Weights retrained quarterly. '
              'Live inference runs every 6 hours via RTDAS API.',
        ),
        const SizedBox(height: 8),
        _InfoCard(
          theme: t,
          icon: Icons.warning_amber,
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
      ],
    );
  }
}

// ── Accuracy hero widget ──────────────────────────────────────────────────────
class _AccuracyHero extends StatelessWidget {
  final RiverColors theme;
  const _AccuracyHero({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A0A2A), Color(0xFF1A0A2A)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFF7B2FF7).withValues(alpha: 0.4),
            width: 1.5),
      ),
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              colors: [Color(0xFF00E5FF), Color(0xFF7B2FF7)],
            ).createShader(r),
            child: const Text('Model Accuracy',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
          ),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MetricBadge(value: '0.94', label: 'AUROC',
                  color: Color(0xFF00E5FF)),
              _MetricBadge(value: '91%',  label: 'Precision',
                  color: Color(0xFF7B2FF7)),
              _MetricBadge(value: '88%',  label: 'Recall',
                  color: Color(0xFF4CAF50)),
              _MetricBadge(value: '0.895',label: 'F1 Score',
                  color: Color(0xFFFFC107)),
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
      {required this.value,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w900)),
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

// ── Section label ─────────────────────────────────────────────────────────────
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
          child: Icon(icon, color: color, size: 15),
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

// ── Info card ─────────────────────────────────────────────────────────────────
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
        border: Border.all(
            color: color.withValues(alpha: 0.18), width: 1),
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
                        color: t.textSecondary,
                        fontSize: 12,
                        height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Feature table ─────────────────────────────────────────────────────────────
class _FeatureTable extends StatelessWidget {
  final RiverColors theme;
  const _FeatureTable({required this.theme});

  static const List<List<String>> _rows = [
    ['River gauge level (m)',      'CWC RTDAS',   'Hourly'],
    ['24h rainfall accumulation',  'IMD gridded', '3-hourly'],
    ['Soil moisture index',        'ISRO SMAP',   'Daily'],
    ['Upstream discharge (m³/s)',  'CWC stations','Hourly'],
    ['Embankment breach history',  'SDMA Bihar',  'Event-based'],
    ['Temperature / humidity',     'IMD AWS',     '3-hourly'],
    ['Tidal backwater effect',     'CWPRS model', '6-hourly'],
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
              decoration: const BoxDecoration(
                  color: Color(0xFF00E5FF1A)),
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
