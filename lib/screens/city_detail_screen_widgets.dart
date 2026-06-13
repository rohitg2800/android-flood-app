// lib/screens/city_detail_screen_widgets.dart
// Public widget classes used by city_detail_screen.dart
// KEY FIX: All classes are PUBLIC (no leading underscore) so they are
// accessible across file boundaries via import.
//
// v2 wiring (2026-06-11):
//   CollapsibleContacts now accepts stationName and passes it to SosScreen
//   via route arguments so SosScreen can pre-filter to that district.
//
// v3 (2026-06-13) — Gap 1:
//   GaugeHeroCard: added freshness footer row showing lastUpdated timestamp
//   and effectiveRainfallMm badge when rainfall > 0.
//
// fix (2026-06-13): _sevColor returned `const AppPalette.gold` which is a
//   class constructor call, not a Color. Replaced with the static field
//   AppPalette.gold directly (no `const` keyword, no `new`, just the field).
//
// fix2 (2026-06-13): _formatUpdated receives DateTime (non-null);
//   call site now uses data.lastUpdated! to unwrap the nullable field.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import '../theme/river_theme.dart';
import '../widgets/sparkline_chart.dart';
import 'bihar_river_map_screen.dart';
import 'predict_screen.dart';
import 'sos_screen.dart';

// ── top-level helper ──────────────────────────────────────────────────────────
Color cityDetailRiskColor(String risk) {
  switch (risk.toUpperCase()) {
    case 'CRITICAL': return AppPalette.critical;
    case 'SEVERE':   return AppPalette.danger;
    case 'MODERATE': return AppPalette.warning;
    default:         return AppPalette.safe;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ThresholdBanner
// ─────────────────────────────────────────────────────────────────────────────
class ThresholdBanner extends StatelessWidget {
  final FloodData data;
  const ThresholdBanner({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final t    = RiverColors.of(context);
    final risk = data.riskLevel.toUpperCase();
    final Color    bg;
    final String   msg;
    final IconData icon;

    switch (risk) {
      case 'CRITICAL':
        bg   = AppPalette.critical.withValues(alpha: 0.18);
        msg  = '🚨 CRITICAL — Level above HFL. Immediate action required.';
        icon = Icons.warning_amber_rounded;
        break;
      case 'SEVERE':
        bg   = AppPalette.danger.withValues(alpha: 0.14);
        msg  = '🔴 SEVERE — Above danger level. Stay alert.';
        icon = Icons.error_outline_rounded;
        break;
      case 'MODERATE':
        bg   = AppPalette.warning.withValues(alpha: 0.12);
        msg  = '⚠️ MODERATE — Above warning level. Monitor closely.';
        icon = Icons.info_outline_rounded;
        break;
      default:
        return const SizedBox.shrink();
    }

    final rc = cityDetailRiskColor(data.riskLevel);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rc.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: rc),
        const SizedBox(width: 8),
        Expanded(
          child: Text(msg,
              style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CitySkeletonView
// ─────────────────────────────────────────────────────────────────────────────
class CitySkeletonView extends StatelessWidget {
  final String cityName;
  const CitySkeletonView({super.key, required this.cityName});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 28, height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: t.accent)),
        const SizedBox(height: 16),
        Text('Loading data for $cityName…',
            style: TextStyle(color: t.textSecondary, fontSize: 13)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GaugeHeroCard   (v3 — Gap 1: freshness footer)
// ─────────────────────────────────────────────────────────────────────────────
class GaugeHeroCard extends StatelessWidget {
  final FloodData data;
  const GaugeHeroCard({super.key, required this.data});

  static String _formatUpdated(DateTime ts) {
    final now   = DateTime.now();
    final hh    = ts.hour.toString().padLeft(2, '0');
    final mm    = ts.minute.toString().padLeft(2, '0');
    final time  = '$hh:$mm';
    final sameDay = ts.year == now.year &&
                    ts.month == now.month &&
                    ts.day == now.day;
    if (sameDay) return 'Updated $time';
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return 'Updated ${ts.day} ${months[ts.month - 1]} $time';
  }

  @override
  Widget build(BuildContext context) {
    final t     = RiverColors.of(context);
    final riskC = cityDetailRiskColor(data.riskLevel);
    final pct   = (data.currentLevel / data.dangerLevel).clamp(0.0, 1.2);

    // FIX: data.lastUpdated is DateTime? — unwrap with ! before passing to
    // _formatUpdated which expects non-nullable DateTime.
    final updatedLabel = _formatUpdated(data.lastUpdated!);
    final rainfall     = data.effectiveRainfallMm;
    final hasRain      = rainfall != null && rainfall > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: riskC.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(color: riskC.withValues(alpha: 0.08),
              blurRadius: 18, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Level',
                  style: TextStyle(color: t.textSecondary, fontSize: 11,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('${data.currentLevel.toStringAsFixed(2)} m',
                  style: TextStyle(color: riskC, fontSize: 28,
                      fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            ],
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: riskC.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: riskC.withValues(alpha: 0.4)),
            ),
            child: Text(data.riskLevel.toUpperCase(),
                style: TextStyle(color: riskC,
                    fontWeight: FontWeight.w800, fontSize: 13)),
          ),
        ]),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            backgroun