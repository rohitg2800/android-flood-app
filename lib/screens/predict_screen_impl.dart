// lib/screens/predict_screen_impl.dart
// EQUINOX-BR05 — LSTM Flood Prediction Screen  (v1.3 — Riverpod 3.x compat)
//
// FloodPrediction fields used here (from prediction_provider.dart):
//   • confidencePct  (not 'confidence')
//   • trend          (String: 'rising' | 'stable' | 'falling', not enum)
//   • riskScore, modelVersion  (unchanged)
//   • no updatedAt field — omitted from model meta
// Provider: predictionProvider (FutureProvider.family<FloodPrediction, String>)
//
// FIX v1.3: AsyncValue.valueOrNull was removed in riverpod 3.x.
//   Use .value instead (returns null when loading/error, the value when data).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../theme/river_theme.dart';
import '../theme/app_palette.dart';
import '../models/flood_alert.dart';
import '../models/river_station.dart';
import '../providers/prediction_provider.dart';
import '../models/flood_prediction.dart';
import '../providers/real_time_river_provider.dart';
import '../services/predict.dart' as predict_lib;


// ─────────────────────────────────────────────────────────────────────────────
//  PredictScreen
// ─────────────────────────────────────────────────────────────────────────────

class PredictScreen extends ConsumerStatefulWidget {
  const PredictScreen({super.key});

  static const String route = '/predict';

  @override
  ConsumerState<PredictScreen> createState() => _PredictScreenState();

  static Color levelColor(BuildContext context, AlertLevel? level) {
    final t = RiverColors.of(context);
    if (level == AlertLevel.danger || level == AlertLevel.extreme) {
      return t.riverDanger;
    }
    if (level == AlertLevel.warning) return t.riverWarning;
    return t.riverNormal;
  }
}

class _PredictScreenState extends ConsumerState<PredictScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedStationId;
  int     _horizonHours = 24;
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // trend is a String: 'rising' | 'stable' | 'falling'
  String _severityFromPrediction(FloodPrediction p) {
    final pct = p.progressPct.clamp(0.0, 100.0);
    if (pct >= 100) return 'CRITICAL';
    if (pct >= 80)  return 'SEVERE';
    if (pct >= 60)  return 'MODERATE';
    return 'LOW';
  }

  @override
  Widget build(BuildContext context) {
    final t        = RiverColors.of(context);
    final stations = ref.watch(mergedStationsProvider);

    if (_selectedStationId == null && stations.isNotEmpty) {
      _selectedStationId = stations.first.station;
    }

    final station = stations.isEmpty
        ? null
        : stations.firstWhere(
            (s) => s.station == _selectedStationId,
            orElse: () => stations.first,
          );

    // predictionProvider is FutureProvider.family<FloodPrediction, String>
    final predAsync = station == null
        ? null
        : ref.watch(predictionProvider((station.station, _horizonHours)));

    // FIX: Riverpod 3.x removed valueOrNull — use .value instead.
    // AsyncValue.value returns null when loading or error, and T when data.
    final prediction = predAsync?.value;

    final showOfflineBanner = predAsync?.hasError == true;

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: Container(
        decoration: AppPalette.scaffoldDecoration(),
        child: SafeArea(
          child: RefreshIndicator(
            color: AppPalette.gold,
            backgroundColor: AppPalette.abyss2,
            onRefresh: () async {
              ref.invalidate(mergedStationsProvider);
              await Future<void>.delayed(const Duration(milliseconds: 600));
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _buildAppBar(t),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ── Offline stale-cache banner ──────────────────
                      if (showOfflineBanner && station != null)
                        FutureBuilder<predict_lib.FloodPrediction?>(
                          future: predict_lib.PredictionService.loadCached(
                              station.station),
                          builder: (ctx, snap) {
                            if (snap.data == null) return const SizedBox();
                            final cached = snap.data!;
                            final age = DateTime.now()
                                .difference(cached.timestamp);
                            final ageStr = age.inHours > 0
                                ? '\${age.inHours}h ago'
                                : '\${age.inMinutes}m ago';
                            if (ageStr.isEmpty) return const SizedBox();
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppPalette.gold.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: AppPalette.gold.withOpacity(0.35)),
                              ),
                              child: Row(children: [
                                const Icon(Icons.offline_bolt_rounded,
                                    size: 16, color: AppPalette.gold),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Offline — showing cached result from \$ageStr',
                                    style: TextStyle(
                                        color: AppPalette.gold,
                                        fontSize: 12),
                                  ),
                                ),
                              ]),
                            );
                          },
                        ),
                      _StationPickerCard(
                        stations: stations,
                        selectedId: _selectedStationId,
                        onChanged: (id) =>
                            setState(() => _selectedStationId = id),
                        theme: t,
                      ),
                      const SizedBox(height: 16),
                      if (station == null)
                        _EmptyState(theme: t)
                      else if (prediction == null)
                        _LoadingState(theme: t, pulseAnim: _pulseAnim)
                      else ...[
                        _CurrentLevelCard(
                          station: station,
                          prediction: prediction,
                          theme: t,
                          pulseAnim: _pulseAnim,
                        ),
                        const SizedBox(height: 16),
                        _HorizonSelector(
                          selected: _horizonHours,
                          onChanged: (h) {
                          setState(() => _horizonHours = h);
                          if (station != null) {
                            ref.invalidate(predictionProvider((station.station, h)));
                          }
                        },
                          theme: t,
                        ),
                        const SizedBox(height: 16),
                        _ForecastGrid(
                          prediction: prediction,
                          horizonHours: _horizonHours,
                          theme: t,
                        ),
                        const SizedBox(height: 16),
                        _SparklineCard(
                          prediction: prediction,
                          horizonHours: _horizonHours,
                          dangerLevel: station.danger,
                          warningLevel: station.warning,
                          theme: t,
                        ),
                        const SizedBox(height: 16),
                        _ModelMetaCard(prediction: prediction, theme: t),
                        const SizedBox(height: 16),
                        _ActionAdviceCard(
                          severity: _severityFromPrediction(prediction),
                          theme: t,
                        ),
                      ],
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar(RiverColors t) => SliverAppBar(
        pinned: true,
        backgroundColor: AppPalette.abyss1.withValues(alpha: 0.96),
        title: Row(
          children: [
            const Icon(Icons.auto_graph_rounded,
                color: AppPalette.gold, size: 22),
            const SizedBox(width: 8),
            Text('LSTM Flood Prediction',
                style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                )),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded,
                color: AppPalette.textGrey),
            tooltip: 'About this model',
            onPressed: () => _showModelInfo(context, t),
          ),
        ],
      );

  void _showModelInfo(BuildContext ctx, RiverColors t) {
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: AppPalette.abyss2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('LSTM Model — v1.3',
                style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _infoRow(t, 'Architecture',
                'Bidirectional LSTM + Ensemble blend'),
            _infoRow(t, 'Input features',
                '11 features: peak level, duration, 7-day rainfall'),
            _infoRow(t, 'Forecast window', '24h / 48h / 72h'),
            _infoRow(t, 'Training data',
                'CWC Bihar stations 2000–2026'),
            _infoRow(t, 'Blend weights',
                'ML 70% + Rule engine 30%'),
            _infoRow(t, 'Terrain calibration',
                'PLAINS / HIMALAYAN / COASTAL / ARID'),
            const SizedBox(height: 8),
            Text(
              'Predictions are probabilistic estimates. '
              'Always follow official CWC / NDRF advisories.',
              style: TextStyle(
                  color: AppPalette.textGrey,
                  fontSize: 12,
                  height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(RiverColors t, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 150,
              child: Text(label,
                  style: const TextStyle(
                      color: AppPalette.textGrey, fontSize: 13)),
            ),
            Expanded(
              child: Text(value,
                  style: TextStyle(
                      color: t.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Station Picker
// ─────────────────────────────────────────────────────────────────────────────

class _StationPickerCard extends StatelessWidget {
  final List<RiverStation> stations;
  final String?            selectedId;
  final ValueChanged<String?> onChanged;
  final RiverColors        theme;

  const _StationPickerCard({
    required this.stations,
    required this.selectedId,
    required this.onChanged,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppPalette.glassMorph(
        borderColor: AppPalette.abyssStroke,
        radius: 16,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          dropdownColor: AppPalette.abyss3,
          isExpanded: true,
          value: selectedId,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppPalette.gold),
          hint: Text('Select station',
              style:
                  TextStyle(color: theme.textSecondary, fontSize: 14)),
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          items: stations.map((s) {
            final cls = s.dangerClass;
            final dot = _dotColor(cls);
            return DropdownMenuItem<String>(
              value: s.station,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                      boxShadow: AppPalette.glowShadow(dot, blur: 6),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${s.station}  •  ${s.river}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: theme.textPrimary, fontSize: 14),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Color _dotColor(DangerClass cls) {
    switch (cls) {
      case DangerClass.extreme:
        return AppPalette.critical;
      case DangerClass.severe:
        return AppPalette.danger;
      case DangerClass.aboveNormal:
        return AppPalette.warning;
      default:
        return AppPalette.safe;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Current Level Card
// ─────────────────────────────────────────────────────────────────────────────

class _CurrentLevelCard extends StatelessWidget {
  final RiverStation      station;
  final FloodPrediction   prediction;
  final RiverColors       theme;
  final Animation<double> pulseAnim;

  const _CurrentLevelCard({
    required this.station,
    required this.prediction,
    required this.theme,
    required this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    final pct      = (prediction.progressPct).clamp(0.0, 100.0);
    final barColor = _barColor(pct);
    final isAlert  = pct >= 80;

    return Container(
      decoration: AppPalette.glassMorph(
        borderColor: isAlert
            ? barColor.withValues(alpha: 0.5)
            : AppPalette.abyssStroke,
        radius: 20,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(station.station,
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        )),
                    const SizedBox(height: 2),
                    Text(station.river,
                        style: const TextStyle(
                            color: AppPalette.textGrey, fontSize: 13)),
                  ],
                ),
              ),
              _TrendBadge(trend: prediction.trend),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedBuilder(
                animation: pulseAnim,
                builder: (_, __) => Opacity(
                  opacity: isAlert ? pulseAnim.value : 1.0,
                  child: Text(
                    '${prediction.currentLevel.toStringAsFixed(2)} m',
                    style: TextStyle(
                      color: barColor,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${pct.toStringAsFixed(1)}% of danger',
                  style: const TextStyle(
                      color: AppPalette.textGrey, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 8,
              backgroundColor:
                  AppPalette.abyss4.withValues(alpha: 0.6),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _ThresholdChip(
                label: 'Warning',
                value: station.warning,
                color: AppPalette.warning,
              ),
              const SizedBox(width: 8),
              _ThresholdChip(
                label: 'Danger',
                value: station.danger,
                color: AppPalette.critical,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _barColor(double pct) {
    if (pct >= 100) return AppPalette.critical;
    if (pct >= 80)  return AppPalette.danger;
    if (pct >= 60)  return AppPalette.warning;
    return AppPalette.safe;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Horizon Selector
// ─────────────────────────────────────────────────────────────────────────────

class _HorizonSelector extends StatelessWidget {
  final int               selected;
  final ValueChanged<int> onChanged;
  final RiverColors       theme;

  const _HorizonSelector({
    required this.selected,
    required this.onChanged,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [24, 48, 72].map((h) {
        final active = h == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(h),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: active
                    ? AppPalette.gold.withValues(alpha: 0.15)
                    : AppPalette.abyss3.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active
                      ? AppPalette.gold
                      : AppPalette.abyssStroke,
                  width: active ? 1.5 : 1,
                ),
              ),
              child: Text(
                '${h}h',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: active
                      ? AppPalette.gold
                      : theme.textSecondary,
                  fontWeight: active
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Forecast Grid
// ─────────────────────────────────────────────────────────────────────────────

class _ForecastGrid extends StatelessWidget {
  final FloodPrediction prediction;
  final int             horizonHours;
  final RiverColors     theme;

  const _ForecastGrid({
    required this.prediction,
    required this.horizonHours,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      _ForecastData(
        label: '24h',
        level: prediction.predicted24h,
        danger: prediction.dangerLevel,
        active: horizonHours == 24,
      ),
      _ForecastData(
        label: '48h',
        level: prediction.predicted48h,
        danger: prediction.dangerLevel,
        active: horizonHours == 48,
      ),
      _ForecastData(
        label: '72h',
        level: prediction.predicted72h,
        danger: prediction.dangerLevel,
        active: horizonHours == 72,
      ),
    ];

    return Row(
      children: cards.map((c) {
        final pct   = (c.level / (c.danger > 0 ? c.danger : c.level * 1.3) * 100)
            .clamp(0.0, 100.0);
        final color = _pctColor(pct);
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.active
                  ? color.withValues(alpha: 0.10)
                  : AppPalette.abyss2.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: c.active
                    ? color.withValues(alpha: 0.6)
                    : AppPalette.abyssStroke,
                width: c.active ? 1.5 : 1,
              ),
            ),
            child: Column(
              children: [
                Text(c.label,
                    style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  '${c.level.toStringAsFixed(2)} m',
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${pct.toStringAsFixed(0)}%',
                  style: TextStyle(
                      color: color.withValues(alpha: 0.7),
                      fontSize: 11),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 4,
                    backgroundColor:
                        AppPalette.abyss4.withValues(alpha: 0.5),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _pctColor(double pct) {
    if (pct >= 100) return AppPalette.critical;
    if (pct >= 80)  return AppPalette.danger;
    if (pct >= 60)  return AppPalette.warning;
    return AppPalette.safe;
  }
}

class _ForecastData {
  final String label;
  final double level;
  final double danger;
  final bool   active;
  const _ForecastData({
    required this.label,
    required this.level,
    required this.danger,
    required this.active,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sparkline Chart
// ─────────────────────────────────────────────────────────────────────────────

class _SparklineCard extends StatelessWidget {
  final FloodPrediction prediction;
  final int             horizonHours;
  final double          dangerLevel;
  final double          warningLevel;
  final RiverColors     theme;

  const _SparklineCard({
    required this.prediction,
    required this.horizonHours,
    required this.dangerLevel,
    required this.warningLevel,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final series = horizonHours == 24
        ? prediction.next24h
        : horizonHours == 48
            ? prediction.next48h
            : prediction.next72h;

    if (series.isEmpty) return const SizedBox.shrink();

    final maxY = [
      ...series.map((p) => p.level),
      dangerLevel * 1.05,
    ].reduce(math.max);
    final minY = series.map((p) => p.level).reduce(math.min) * 0.95;

    final spots = series.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.level))
        .toList();
    final dangerSpots = series.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), dangerLevel))
        .toList();
    final warnSpots = series.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), warningLevel))
        .toList();

    return Container(
      decoration: AppPalette.glassMorph(
          borderColor: AppPalette.abyssStroke, radius: 20),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart_rounded,
                  color: AppPalette.cyan, size: 18),
              const SizedBox(width: 8),
              Text('${horizonHours}h Forecast Curve',
                  style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _LegendDot(color: AppPalette.cyan, label: 'Predicted'),
              const SizedBox(width: 12),
              _LegendDot(color: AppPalette.critical, label: 'Danger'),
              const SizedBox(width: 12),
              _LegendDot(color: AppPalette.warning, label: 'Warning'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppPalette.abyssStroke.withValues(alpha: 0.4),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, _) => Text(
                        v.toStringAsFixed(1),
                        style: const TextStyle(
                            color: AppPalette.textGrey, fontSize: 9),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (series.length / 4).ceilToDouble(),
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= series.length) {
                          return const SizedBox.shrink();
                        }
                        final h = series[idx].time.hour;
                        return Text('${h}h',
                            style: const TextStyle(
                                color: AppPalette.textGrey, fontSize: 9));
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: dangerSpots,
                    isCurved: false,
                    color: AppPalette.critical.withValues(alpha: 0.5),
                    barWidth: 1,
                    dotData: const FlDotData(show: false),
                    dashArray: [6, 4],
                  ),
                  LineChartBarData(
                    spots: warnSpots,
                    isCurved: false,
                    color: AppPalette.warning.withValues(alpha: 0.5),
                    barWidth: 1,
                    dotData: const FlDotData(show: false),
                    dashArray: [4, 4],
                  ),
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: AppPalette.cyan,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppPalette.cyan.withValues(alpha: 0.22),
                          AppPalette.cyan.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppPalette.abyss3,
                    getTooltipItems: (spots) => spots.map((s) {
                      return LineTooltipItem(
                        '${s.y.toStringAsFixed(2)} m',
                        TextStyle(
                            color: AppPalette.cyan,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Model Meta Card
// ─────────────────────────────────────────────────────────────────────────────

class _ModelMetaCard extends StatelessWidget {
  final FloodPrediction prediction;
  final RiverColors     theme;
  const _ModelMetaCard({required this.prediction, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppPalette.glassMorph(
          borderColor: AppPalette.abyssStroke, radius: 16),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined,
                  color: AppPalette.gold, size: 16),
              const SizedBox(width: 8),
              Text('Model Analysis',
                  style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          _metaRow('Confidence',
              '${prediction.confidencePct.toStringAsFixed(0)}%'),
          _metaRow('Risk Score',
              prediction.riskScore.toStringAsFixed(2)),
          _metaRow('Trend',     prediction.trend),
          _metaRow('Model',     prediction.modelVersion),
          _metaRow('Outlook',   prediction.outlook),
        ],
      ),
    );
  }

  Widget _metaRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(label,
                  style: const TextStyle(
                      color: AppPalette.textGrey, fontSize: 12)),
            ),
            Expanded(
              child: Text(value,
                  style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Action Advice Card  (Phase 2)
// ─────────────────────────────────────────────────────────────────────────────

class _ActionAdviceCard extends StatelessWidget {
  final String      severity;
  final RiverColors theme;

  const _ActionAdviceCard({
    required this.severity,
    required this.theme,
  });

  static const _advice = {
    'CRITICAL': (
      icon: '🚨',
      title: 'IMMEDIATE EVACUATION REQUIRED',
      body:
          'Danger level exceeded. Move to designated high-ground shelters immediately. '
          'Do NOT attempt to cross flooded roads or bridges. '
          'Bihar SDRF: 0612-2217305  |  NDRF: 011-24363260.',
      color: Color(0xFFE53935),
    ),
    'SEVERE': (
      icon: '⚠️',
      title: 'PREPARE TO EVACUATE — 6 h window',
      body:
          'Levels rising critically. Move valuables to upper floors. '
          'Prepare go-bag: documents, medicines, 3 days of food and water. '
          'Await evacuation advisory. Avoid river banks.',
      color: Color(0xFFFB8C00),
    ),
    'MODERATE': (
      icon: '🟡',
      title: 'STAY ALERT — Monitor every 30 min',
      body:
          'Elevated but below danger threshold. Avoid crossing streams. '
          'Keep emergency kit ready. Monitor IMD alerts for upstream rainfall.',
      color: Color(0xFFFDD835),
    ),
    'LOW': (
      icon: '✅',
      title: 'NORMAL CONDITIONS',
      body:
          'Levels within safe range. Continue routine monitoring. '
          'Check forecast during heavy rain spells.',
      color: Color(0xFF43A047),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final entry = _advice[severity] ?? _advice['LOW']!;
    final color = entry.color;

    return Container(
      decoration: AppPalette.glassMorph(
        borderColor: color.withValues(alpha: 0.45),
        radius: 16,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(entry.icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.title,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: color.withValues(alpha: 0.25), height: 1),
          const SizedBox(height: 10),
          Text(
            entry.body,
            style: TextStyle(
              color: theme.textPrimary.withValues(alpha: 0.88),
              fontSize: 13,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Always follow official CWC / NDRF advisories.',
            style: TextStyle(
              color: AppPalette.textGrey,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Small helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Trend badge — prediction.trend is a String: 'rising' | 'falling' | 'stable'
class _TrendBadge extends StatelessWidget {
  final String trend;
  const _TrendBadge({required this.trend});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color    color;
    switch (trend) {
      case 'rising':
        icon  = Icons.trending_up_rounded;
        color = AppPalette.danger;
      case 'falling':
        icon  = Icons.trending_down_rounded;
        color = AppPalette.safe;
      default:
        icon  = Icons.trending_flat_rounded;
        color = AppPalette.warning;
    }
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}

class _ThresholdChip extends StatelessWidget {
  final String label;
  final double value;
  final Color  color;
  const _ThresholdChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
                text: '$label  ',
                style: const TextStyle(
                    color: AppPalette.textGrey, fontSize: 11)),
            TextSpan(
                text: '${value.toStringAsFixed(2)} m',
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color  color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                color: AppPalette.textGrey, fontSize: 10)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final RiverColors theme;
  const _EmptyState({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.water_outlined,
                size: 56, color: AppPalette.textGrey),
            const SizedBox(height: 16),
            Text('No stations available',
                style: TextStyle(
                    color: theme.textSecondary, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  final RiverColors       theme;
  final Animation<double> pulseAnim;
  const _LoadingState({required this.theme, required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: AnimatedBuilder(
          animation: pulseAnim,
          builder: (_, __) => Opacity(
            opacity: pulseAnim.value,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation(AppPalette.cyan)),
                const SizedBox(height: 16),
                Text('Loading prediction…',
                    style: TextStyle(
                        color: theme.textSecondary, fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
