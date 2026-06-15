// lib/widgets/ai_prediction_panel.dart
//
// Drop-in panel that reads predictionProvider(station) and renders:
//  • Severity badge + confidence chip
//  • Animated probability bars (CRITICAL / SEVERE / MODERATE / LOW)
//    — derived from level-proximity since FloodPrediction has no
//      probabilities map; these reflect real cwcRiskScore when available.
//  • 24 h / 48 h / 72 h sparkline (custom painter, no extra package)
//  • Peak-level line with warning/danger ticks
//  • Monitoring advice
//  • Source trail: backend LSTM → CWC-sim → offline
// Usage:
//   AiPredictionPanel(stationKey: 'Gandhighat')
//   AiPredictionPanel.fromCwc(site: cwcStation.site)
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/prediction_provider.dart';
import '../models/flood_prediction.dart';
import '../models/prediction_point.dart';
import '../theme/river_theme.dart';


// ─────────────────────────────────────────────────────────────────────────────
// Public widget
// ─────────────────────────────────────────────────────────────────────────────

class AiPredictionPanel extends ConsumerStatefulWidget {
  final String stationKey;
  const AiPredictionPanel({super.key, required this.stationKey});

  /// Convenience: pass a CwcStation site name directly.
  static Widget fromCwc({required String site, Key? key}) =>
      AiPredictionPanel(key: key, stationKey: site);

  @override
  ConsumerState<AiPredictionPanel> createState() => _AiPredictionPanelState();
}

class _AiPredictionPanelState extends ConsumerState<AiPredictionPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _anim;
  int _window = 24; // 24 | 48 | 72

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _anim = CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic);
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(predictionProvider(widget.stationKey));
    return async.when(
      loading: () => _skeleton(),
      error:   (e, _) => _errorTile(e.toString()),
      data:    (pred) => _body(pred),
    );
  }

  // ── loading skeleton ────────────────────────────────────────────────────────
  Widget _skeleton() => Container(
        height: 200,
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          color: AppPalette.abyss1,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                  strokeWidth: 2, color: AppPalette.cyan),
              SizedBox(height: 10),
              Text('Running AI model…',
                  style: TextStyle(
                      color: AppPalette.textGrey, fontSize: 11)),
            ],
          ),
        ),
      );

  // ── error tile ──────────────────────────────────────────────────────────────
  Widget _errorTile(String msg) => Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          color: AppPalette.abyss1,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppPalette.amber.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppPalette.amber, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Prediction unavailable: $msg',
                  style: const TextStyle(
                      color: AppPalette.textGrey, fontSize: 11)),
            ),
          ],
        ),
      );

  // ── full body ────────────────────────────────────────────────────────────────
  Widget _body(FloodPrediction pred) {
    final severity = _severityOf(pred);
    final color    = _sevColor(severity);
    final probs    = _computeProbs(pred);
    final points   = _window == 24
        ? pred.next24h
        : _window == 48 ? pred.next48h : pred.next72h;

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: AppPalette.abyss1,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── header ────────────────────────────────────────────────────
              _Header(pred: pred, severity: severity, color: color),

              _div(),

              // ── probability bars ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Probability Distribution'),
                    const SizedBox(height: 8),
                    for (final lbl in ['CRITICAL', 'SEVERE', 'MODERATE', 'LOW'])
                      _ProbBar(
                        label:     lbl,
                        pct:       probs[lbl] ?? 0,
                        highlight: lbl == severity,
                      ),
                  ],
                ),
              ),

              _div(),

              // ── sparkline ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _label('Forecast'),
                        const Spacer(),
                        for (final w in [24, 48, 72])
                          GestureDetector(
                            onTap: () => setState(() => _window = w),
                            child: Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _window == w
                                    ? color.withValues(alpha: 0.18)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _window == w
                                      ? color.withValues(alpha: 0.45)
                                      : AppPalette.abyss2,
                                ),
                              ),
                              child: Text('${w}h',
                                  style: TextStyle(
                                      color: _window == w
                                          ? color
                                          : AppPalette.textGrey,
                                      fontSize: 9,
                                      fontWeight: _window == w
                                          ? FontWeight.w800
                                          : FontWeight.w400)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (points.isNotEmpty)
                      SizedBox(
                        height: 100,
                        child: CustomPaint(
                          painter: _SparklinePainter(
                            points:  points,
                            warning: pred.warningLevel,
                            danger:  pred.dangerLevel,
                            color:   color,
                          ),
                          size: const Size(double.infinity, 100),
                        ),
                      )
                    else
                      const SizedBox(
                        height: 40,
                        child: Center(
                          child: Text('No forecast data',
                              style: TextStyle(
                                  color: AppPalette.textGrey, fontSize: 11)),
                        ),
                      ),
                    const SizedBox(height: 6),
                    if (points.length >= 2)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _tiny(DateFormat('HH:mm').format(points.first.time)),
                          if (points.length > 12)
                            _tiny(DateFormat('HH:mm')
                                .format(points[points.length ~/ 2].time)),
                          _tiny(DateFormat('HH:mm').format(points.last.time)),
                        ],
                      ),
                  ],
                ),
              ),

              _div(),

              // ── stats row ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatPill(
                      icon:  Icons.height_rounded,
                      label: 'Now',
                      value: '${pred.currentLevel.toStringAsFixed(2)} m',
                      color: color,
                    ),
                    _StatPill(
                      icon:  Icons.trending_up_rounded,
                      label: 'Peak ${_window}h',
                      value: '${_peakLevel(points).toStringAsFixed(2)} m',
                      color: color,
                    ),
                    _StatPill(
                      icon:  Icons.warning_amber_rounded,
                      label: 'Warning',
                      value: '${pred.warningLevel.toStringAsFixed(2)} m',
                      color: AppPalette.amber,
                    ),
                    _StatPill(
                      icon:  Icons.dangerous_rounded,
                      label: 'Danger',
                      value: '${pred.dangerLevel.toStringAsFixed(2)} m',
                      color: AppPalette.danger,
                    ),
                  ],
                ),
              ),

              _div(),

              // ── monitoring advice ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.radar_rounded, color: color, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _monitoringLevel(severity),
                            style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _monitoringAdvice(severity, pred),
                            style: const TextStyle(
                                color: AppPalette.textGrey,
                                fontSize: 11,
                                height: 1.45),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── source trail ───────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: const BoxDecoration(
                  color: AppPalette.abyss0,
                  borderRadius: BorderRadius.only(
                    bottomLeft:  Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.model_training_rounded,
                        size: 11, color: AppPalette.textGrey),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        '${pred.modelVersion}  ·  '
                        'Confidence ${pred.confidencePct.toStringAsFixed(0)}%'
                        '${pred.cwcRiskScore != null ? '  ·  CWC risk ${pred.cwcRiskScore!.toStringAsFixed(0)}%' : ''}',
                        style: const TextStyle(
                            color: AppPalette.textGrey,
                            fontSize: 9,
                            letterSpacing: 0.2),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── helpers ──────────────────────────────────────────────────────────────────

  Widget _div() => const Divider(
      height: 1, thickness: 1, color: AppPalette.abyss2);

  Widget _label(String t) => Text(t.toUpperCase(),
      style: const TextStyle(
          color: AppPalette.textGrey,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2));

  Widget _tiny(String t) => Text(t,
      style: const TextStyle(
          color: AppPalette.textGrey, fontSize: 8));

  double _peakLevel(List<PredictionPoint> pts) =>
      pts.isEmpty ? 0 : pts.map((p) => p.level).reduce(math.max);

  // ── Severity derived from level proximity to danger ──────────────────────────
  String _severityOf(FloodPrediction pred) {
    final pct = pred.dangerLevel > 0
        ? pred.currentLevel / pred.dangerLevel
        : 0.0;
    if (pct >= 1.00) return 'CRITICAL';
    if (pct >= 0.97) return 'SEVERE';
    if (pct >= 0.85) return 'MODERATE';
    return 'LOW';
  }

  // ── Soft probability distribution from proximity ratio ───────────────────────
  // FloodPrediction has no probabilities field — we compute a plausible
  // soft-max distribution from (currentLevel / dangerLevel) and cwcRiskScore.
  Map<String, double> _computeProbs(FloodPrediction pred) {
    final pct  = pred.dangerLevel > 0
        ? (pred.currentLevel / pred.dangerLevel).clamp(0.0, 1.1)
        : 0.0;
    final risk = (pred.cwcRiskScore ?? (pct * 100)).clamp(0.0, 100.0);

    // Raw logit scores — higher pct pushes mass toward CRITICAL
    final rawCritical = math.max(0.0, (pct - 1.00) * 20 + (risk - 90) * 0.5);
    final rawSevere   = math.max(0.0, (pct - 0.97) * 15 + (risk - 75) * 0.4);
    final rawModerate = math.max(0.0, (pct - 0.85) * 10 + (risk - 50) * 0.3);
    final rawLow      = math.max(0.0, (1.0 - pct) * 12 + (100 - risk) * 0.2);

    final total = rawCritical + rawSevere + rawModerate + rawLow;
    if (total == 0) {
      return {'CRITICAL': 2, 'SEVERE': 5, 'MODERATE': 15, 'LOW': 78};
    }
    return {
      'CRITICAL': (rawCritical / total * 100).roundToDouble(),
      'SEVERE':   (rawSevere   / total * 100).roundToDouble(),
      'MODERATE': (rawModerate / total * 100).roundToDouble(),
      'LOW':      (rawLow      / total * 100).roundToDouble(),
    };
  }

  Color _sevColor(String sev) {
    switch (sev) {
      case 'CRITICAL': return AppPalette.critical;
      case 'SEVERE':   return AppPalette.danger;
      case 'MODERATE': return AppPalette.amber;
      default:         return AppPalette.safe;
    }
  }

  String _monitoringLevel(String sev) {
    switch (sev) {
      case 'CRITICAL': return '🔴  EMERGENCY MONITORING';
      case 'SEVERE':   return '🟠  HIGH ALERT';
      case 'MODERATE': return '🟡  ACTIVE WATCH';
      default:         return '🟢  ROUTINE MONITORING';
    }
  }

  String _monitoringAdvice(String sev, FloodPrediction pred) {
    final gap = pred.dangerLevel - pred.currentLevel;
    switch (sev) {
      case 'CRITICAL':
        return 'Level is at or above danger. Evacuate low-lying areas, '
            'alert disaster management, suspend all river-crossing activity.';
      case 'SEVERE':
        return 'Only ${gap.toStringAsFixed(2)} m below danger. Deploy rescue '
            'teams on standby, alert downstream populations, monitor every 30 min.';
      case 'MODERATE':
        return '${gap.toStringAsFixed(2)} m below danger. Increase monitoring '
            'frequency to hourly. Alert village panchayats in flood-prone zones.';
      default:
        return 'Level is safe. Continue routine monitoring. '
            'Watch weather forecasts for upstream rainfall.';
    }
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final FloodPrediction pred;
  final String severity;
  final Color  color;
  const _Header(
      {required this.pred,
      required this.severity,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Icon(_icon(severity), color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_alert(severity)}  $severity',
                  style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3),
                ),
                const SizedBox(height: 3),
                Text(
                  'AI Flood Prediction  ·  ${pred.station}',
                  style: const TextStyle(
                      color: AppPalette.textGrey, fontSize: 10),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _pill('${pred.confidencePct.toStringAsFixed(0)}% conf', color),
              if (pred.cwcRiskScore != null) ...[
                const SizedBox(height: 4),
                _pill('CWC ${pred.cwcRiskScore!.toStringAsFixed(0)}%',
                    AppPalette.cyan),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withValues(alpha: 0.35)),
        ),
        child: Text(t,
            style: TextStyle(
                color: c,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3)),
      );

  String _alert(String sev) {
    switch (sev) {
      case 'CRITICAL': return '🚨';
      case 'SEVERE':   return '⚠️';
      case 'MODERATE': return '🟡';
      default:         return '✅';
    }
  }

  IconData _icon(String sev) {
    switch (sev) {
      case 'CRITICAL': return Icons.crisis_alert_rounded;
      case 'SEVERE':   return Icons.warning_rounded;
      case 'MODERATE': return Icons.warning_amber_rounded;
      default:         return Icons.check_circle_outline_rounded;
    }
  }
}

// ─── Probability bar ───────────────────────────────────────────────────────────

class _ProbBar extends StatelessWidget {
  final String label;
  final double pct;
  final bool   highlight;
  const _ProbBar(
      {required this.label,
      required this.pct,
      required this.highlight});

  Color get _c {
    switch (label) {
      case 'CRITICAL': return AppPalette.critical;
      case 'SEVERE':   return AppPalette.danger;
      case 'MODERATE': return AppPalette.amber;
      default:         return AppPalette.safe;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final f = (pct / 100.0).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            child: Text(label,
                style: TextStyle(
                    color: highlight ? c : AppPalette.textGrey,
                    fontSize: 9,
                    fontWeight:
                        highlight ? FontWeight.w800 : FontWeight.w500)),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                    height: 6,
                    decoration: BoxDecoration(
                        color: c.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(4))),
                FractionallySizedBox(
                  widthFactor: f,
                  child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                          color: highlight
                              ? c
                              : c.withValues(alpha: 0.40),
                          borderRadius: BorderRadius.circular(4))),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            child: Text('${pct.toStringAsFixed(1)}%',
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: highlight ? c : AppPalette.textDim,
                    fontSize: 9,
                    fontWeight: highlight
                        ? FontWeight.w800
                        : FontWeight.w400)),
          ),
        ],
      ),
    );
  }
}

// ─── Sparkline painter ─────────────────────────────────────────────────────────

class _SparklinePainter extends CustomPainter {
  final List<PredictionPoint> points;
  final double warning, danger;
  final Color  color;
  const _SparklinePainter({
    required this.points,
    required this.warning,
    required this.danger,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final levels = points.map((p) => p.level).toList();
    final minL   = levels.reduce(math.min);
    final maxL   = math.max(levels.reduce(math.max), danger * 1.02);
    final rangeL = maxL - minL;
    if (rangeL == 0) return;

    double xOf(int i) => i / (points.length - 1) * size.width;
    double yOf(double l) => size.height - (l - minL) / rangeL * size.height;

    // shaded area
    final areaPath = Path();
    areaPath.moveTo(xOf(0), size.height);
    areaPath.lineTo(xOf(0), yOf(levels[0]));
    for (int i = 1; i < levels.length; i++) {
      final x0 = xOf(i - 1), y0 = yOf(levels[i - 1]);
      final x1 = xOf(i),     y1 = yOf(levels[i]);
      areaPath.cubicTo(
          x0 + (x1 - x0) / 3, y0,
          x1 - (x1 - x0) / 3, y1,
          x1, y1);
    }
    areaPath.lineTo(xOf(levels.length - 1), size.height);
    areaPath.close();
    canvas.drawPath(
        areaPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end:   Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.28),
              color.withValues(alpha: 0.01),
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    // line
    final linePath = Path();
    linePath.moveTo(xOf(0), yOf(levels[0]));
    for (int i = 1; i < levels.length; i++) {
      final x0 = xOf(i - 1), y0 = yOf(levels[i - 1]);
      final x1 = xOf(i),     y1 = yOf(levels[i]);
      linePath.cubicTo(
          x0 + (x1 - x0) / 3, y0,
          x1 - (x1 - x0) / 3, y1,
          x1, y1);
    }
    canvas.drawPath(
        linePath,
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);

    // warning line
    final wY = yOf(warning);
    if (wY >= 0 && wY <= size.height) {
      canvas.drawLine(
          Offset(0, wY), Offset(size.width, wY),
          Paint()
            ..color = AppPalette.warning.withValues(alpha: 0.55)
            ..strokeWidth = 1
            ..style = PaintingStyle.stroke);
      canvas.drawParagraph(
          _buildPara('⚠ warn', AppPalette.warning, 7.5),
          Offset(size.width - 34, wY - 11));
    }

    // danger line
    final dY = yOf(danger);
    if (dY >= 0 && dY <= size.height) {
      canvas.drawLine(
          Offset(0, dY), Offset(size.width, dY),
          Paint()
            ..color = AppPalette.danger.withValues(alpha: 0.70)
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke);
      canvas.drawParagraph(
          _buildPara('🔴 danger', AppPalette.danger, 7.5),
          Offset(size.width - 48, dY - 11));
    }

    // current dot
    final dotX = xOf(0), dotY = yOf(levels[0]);
    canvas.drawCircle(Offset(dotX, dotY), 5, Paint()..color = color);
    canvas.drawCircle(
        Offset(dotX, dotY), 5,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  ui.Paragraph _buildPara(String text, Color c, double fontSize) {
    final pb = ui.ParagraphBuilder(
        ui.ParagraphStyle(fontSize: fontSize, fontWeight: FontWeight.w700))
      ..pushStyle(ui.TextStyle(color: c))
      ..addText(text);
    return pb.build()..layout(const ui.ParagraphConstraints(width: 60));
  }

  @override
  bool shouldRepaint(_SparklinePainter o) =>
      o.points != points || o.color != color;
}

// ─── Tiny stat pill ────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String   label, value;
  final Color    color;
  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style: const TextStyle(
                  color: AppPalette.textGrey, fontSize: 8)),
        ],
      );
}
