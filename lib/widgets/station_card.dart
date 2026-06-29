// lib/widgets/station_card.dart
// Robotic-themed StationCard — theme-aware, sharp-edged, glow effects.
// Logic (alert-level conditional, data binding) is fully preserved.
// Supports Tactical-Dark / System-Light via RoboticTheme from Riverpod.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/flood_data.dart';
import '../theme/robotic_theme.dart';
import '../providers/theme_provider.dart';

// ─── Public widget ─────────────────────────────────────────────────────────

class StationCard extends ConsumerWidget {
  const StationCard({super.key, required this.data, this.onTap});

  final FloodData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rt = ref.watch(robTheme);
    return _RoboticCard(data: data, theme: rt, onTap: onTap);
  }
}

// ─── Internal implementation ───────────────────────────────────────────────

class _RoboticCard extends StatelessWidget {
  const _RoboticCard({
    required this.data,
    required this.theme,
    this.onTap,
  });

  final FloodData   data;
  final RoboticTheme theme;
  final VoidCallback? onTap;

  // ── Alert-level logic (unchanged) ─────────────────────────────────────
  Color get _alertColor {
    switch (data.riskLevel) {
      case 'CRITICAL': return theme.danger;
      case 'SEVERE':   return theme.warning;
      case 'MODERATE': return theme.accent2;
      default:         return theme.accent;
    }
  }

  bool get _isCritical  => data.riskLevel == 'CRITICAL';
  bool get _isSevere    => data.riskLevel == 'SEVERE';
  bool get _isElevated  => _isCritical || _isSevere;

  double get _levelPct =>
      data.dangerLevel > 0
          ? (data.currentLevel / data.dangerLevel * 100).clamp(0.0, 100.0)
          : 0.0;

  // ── Glow helpers ──────────────────────────────────────────────────────
  List<BoxShadow> _glowFor(Color c, {double intensity = 1.0}) => [
    BoxShadow(
      color:       c.withValues(alpha: 0.25 * intensity),
      blurRadius:  12 * intensity,
      spreadRadius: 1 * intensity,
    ),
    BoxShadow(
      color:       c.withValues(alpha: 0.10 * intensity),
      blurRadius:  28 * intensity,
      spreadRadius: 0,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final accent   = _alertColor;
    final elevated = _isElevated;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve:    Curves.easeOut,
      decoration: BoxDecoration(
        color:  theme.surface,
        border: Border.all(
          color: elevated ? accent.withValues(alpha: 0.8) : theme.border,
          width: elevated ? 1.5 : 1.0,
        ),
        // Sharp corners — Robotic design language
        borderRadius: BorderRadius.zero,
        boxShadow: elevated ? _glowFor(accent, intensity: elevated ? 1.2 : 0.6) : [
          BoxShadow(
            color:      theme.accent.withValues(alpha: 0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Material(
        color:         Colors.transparent,
        child: InkWell(
          onTap:          onTap,
          splashColor:    accent.withValues(alpha: 0.08),
          highlightColor: accent.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(data: data, theme: theme, alertColor: accent),
                const SizedBox(height: 10),
                _LevelBar(pct: _levelPct, alertColor: accent, theme: theme),
                const SizedBox(height: 10),
                _MetricsRow(data: data, theme: theme),
                if (data.riverName != null) ...[
                  const SizedBox(height: 6),
                  _RiverTag(name: data.riverName!, theme: theme, accent: accent),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sub-widgets ───────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.data,
    required this.theme,
    required this.alertColor,
  });

  final FloodData    data;
  final RoboticTheme theme;
  final Color        alertColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Alert indicator dot
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: alertColor,
            boxShadow: [
              BoxShadow(
                color:      alertColor.withValues(alpha: 0.6),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            (data.city ?? "").toUpperCase(),
            style: TextStyle(
              fontFamily:     'RobotoMono',
              fontSize:       13,
              fontWeight:     FontWeight.w700,
              color:          theme.text,
              letterSpacing:  1.4,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        _RiskBadge(riskLevel: data.riskLevel, color: alertColor, theme: theme),
      ],
    );
  }
}

class _RiskBadge extends StatelessWidget {
  const _RiskBadge({
    required this.riskLevel,
    required this.color,
    required this.theme,
  });

  final String       riskLevel;
  final Color        color;
  final RoboticTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:  color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
        // Sharp — no radius
      ),
      child: Text(
        riskLevel,
        style: TextStyle(
          fontFamily:    'RobotoMono',
          fontSize:      10,
          fontWeight:    FontWeight.w700,
          color:         color,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _LevelBar extends StatelessWidget {
  const _LevelBar({
    required this.pct,
    required this.alertColor,
    required this.theme,
  });

  final double       pct;
  final Color        alertColor;
  final RoboticTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'LEVEL',
              style: TextStyle(
                fontFamily:    'RobotoMono',
                fontSize:      9,
                letterSpacing: 1.4,
                color:         theme.textMuted,
              ),
            ),
            Text(
              '${pct.toStringAsFixed(1)}%',
              style: TextStyle(
                fontFamily:    'RobotoMono',
                fontSize:      11,
                fontWeight:    FontWeight.w700,
                color:         alertColor,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Track
        Container(
          height:      4,
          decoration: BoxDecoration(
            color: theme.surface2,
            border: Border.all(color: theme.border.withValues(alpha: 0.5), width: 0.5),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: pct / 100,
            child: Container(
              decoration: BoxDecoration(
                color:      alertColor,
                boxShadow: [
                  BoxShadow(
                    color:      alertColor.withValues(alpha: 0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({required this.data, required this.theme});

  final FloodData    data;
  final RoboticTheme theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Metric(
          label: 'CURRENT',
          value: '${data.currentLevel.toStringAsFixed(2)}m',
          theme: theme,
        ),
        _VertDivider(theme: theme),
        _Metric(
          label: 'DANGER',
          value: '${data.dangerLevel.toStringAsFixed(2)}m',
          theme: theme,
          isAlert: data.currentLevel >= data.dangerLevel,
        ),
        _VertDivider(theme: theme),
        _Metric(
          label: 'WARN',
          value: '${data.warningLevel.toStringAsFixed(2)}m',
          theme: theme,
          isAlert: data.currentLevel >= data.warningLevel &&
                   data.currentLevel <  data.dangerLevel,
        ),
        if (data.effectiveRainfallMm > 0) ...[
          _VertDivider(theme: theme),
          _Metric(
            label: 'RAIN',
            value: '${data.effectiveRainfallMm.toStringAsFixed(1)}mm',
            theme: theme,
          ),
        ],
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.theme,
    this.isAlert = false,
  });

  final String       label;
  final String       value;
  final RoboticTheme theme;
  final bool         isAlert;

  @override
  Widget build(BuildContext context) {
    final valColor = isAlert ? theme.danger : theme.text;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily:    'RobotoMono',
              fontSize:      8,
              letterSpacing: 1.2,
              color:         theme.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontFamily:    'RobotoMono',
              fontSize:      12,
              fontWeight:    FontWeight.w600,
              color:         valColor,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  const _VertDivider({required this.theme});
  final RoboticTheme theme;

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: theme.border, margin: const EdgeInsets.symmetric(horizontal: 8));
}

class _RiverTag extends StatelessWidget {
  const _RiverTag({
    required this.name,
    required this.theme,
    required this.accent,
  });

  final String       name;
  final RoboticTheme theme;
  final Color        accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.water, size: 11, color: accent.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Text(
          (name ?? "").toUpperCase(),
          style: TextStyle(
            fontFamily:    'RobotoMono',
            fontSize:      9,
            letterSpacing: 1.2,
            color:         theme.textMuted,
          ),
        ),
      ],
    );
  }
}
