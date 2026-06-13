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

  /// Format lastUpdated as:
  ///   • "Updated 14:32"         — same calendar day
  ///   • "Updated 11 Jun 14:32"  — different day
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

    final updatedLabel = _formatUpdated(data.lastUpdated);
    final rainfall     = data.effectiveRainfallMm;   // double or null
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

        // ── Level + Risk badge ──────────────────────────────────────────────
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

        // ── Progress bar ────────────────────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            backgroundColor: t.stroke,
            valueColor: AlwaysStoppedAnimation<Color>(riskC),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 8),

        // ── Warning / Danger pills ──────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _levelPill(t, 'Warning', data.warningLevel, AppPalette.warning),
            _levelPill(t, 'Danger',  data.dangerLevel,  AppPalette.danger),
          ],
        ),

        // ── Freshness footer (Gap 1) ────────────────────────────────────────
        const SizedBox(height: 10),
        Divider(height: 1, color: t.stroke),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.access_time_rounded, size: 11, color: t.textSecondary),
            const SizedBox(width: 4),
            Text(updatedLabel,
                style: TextStyle(color: t.textSecondary, fontSize: 10,
                    fontWeight: FontWeight.w600)),
            if (hasRain) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.lightBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.lightBlue.withValues(alpha: 0.30)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.grain_rounded,
                        size: 10, color: Colors.lightBlue),
                    const SizedBox(width: 3),
                    Text('${rainfall!.toStringAsFixed(1)} mm',
                        style: const TextStyle(
                            color: Colors.lightBlue,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ]),
    );
  }

  Widget _levelPill(RiverColors t, String label, double level, Color color) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text('$label: ${level.toStringAsFixed(2)} m',
            style: TextStyle(color: t.textSecondary, fontSize: 10,
                fontWeight: FontWeight.w600)),
      ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// TrendCard
// ─────────────────────────────────────────────────────────────────────────────
class TrendCard extends StatelessWidget {
  final List<RiverLevelSnapshot> trend;
  final double warningLevel;
  final double dangerLevel;
  final Color  riskColor;
  const TrendCard({
    super.key,
    required this.trend,
    required this.warningLevel,
    required this.dangerLevel,
    required this.riskColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.stroke),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.show_chart_rounded, size: 14, color: t.textSecondary),
          const SizedBox(width: 6),
          Text('24-Hour Trend',
              style: TextStyle(color: t.textPrimary,
                  fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 80,
          child: SparklineChart(
            snapshots:    trend,
            color:        riskColor,
            warningLevel: warningLevel,
            dangerLevel:  dangerLevel,
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SectionLabel
// ─────────────────────────────────────────────────────────────────────────────
class SectionLabel extends StatelessWidget {
  final String label;
  const SectionLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label,
          style: TextStyle(color: t.textPrimary,
              fontWeight: FontWeight.w800, fontSize: 13)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ImdAlertTile
// ─────────────────────────────────────────────────────────────────────────────
class ImdAlertTile extends StatelessWidget {
  final Map<String, dynamic> alert;
  const ImdAlertTile({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    final t        = RiverColors.of(context);
    final headline = (alert['headline'] ?? alert['title'] ?? 'IMD Alert').toString();
    final desc     = (alert['description'] ?? alert['body'] ?? '').toString();
    final sev      = (alert['severity'] ?? 'YELLOW').toString();
    final color    = _sevColor(sev);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 4, height: 40,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2)),
        ),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(headline,
                style: TextStyle(color: t.textPrimary, fontSize: 12,
                    fontWeight: FontWeight.w700)),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(desc,
                  style: TextStyle(color: t.textSecondary, fontSize: 11),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ],
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(sev,
              style: TextStyle(color: color, fontSize: 9,
                  fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }

  static Color _sevColor(String sev) {
    switch (sev.toUpperCase()) {
      case 'RED':    return AppPalette.danger;
      case 'ORANGE': return AppPalette.warning;
      default:       return const AppPalette.gold;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NdmaAdvisoryTile
// ─────────────────────────────────────────────────────────────────────────────
class NdmaAdvisoryTile extends StatelessWidget {
  final Map<String, dynamic> adv;
  const NdmaAdvisoryTile({super.key, required this.adv});

  @override
  Widget build(BuildContext context) {
    final t     = RiverColors.of(context);
    final title = (adv['title'] ?? adv['headline'] ?? 'NDMA Advisory').toString();
    final body  = (adv['body']  ?? adv['description'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.critical.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(color: t.textPrimary, fontSize: 12,
                fontWeight: FontWeight.w700)),
        if (body.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(body,
              style: TextStyle(color: t.textSecondary, fontSize: 11),
              maxLines: 3, overflow: TextOverflow.ellipsis),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CollapsibleContacts
// stationName is passed through to SosScreen so that screen pre-filters
// contacts to the matching district.
// ─────────────────────────────────────────────────────────────────────────────
class CollapsibleContacts extends StatelessWidget {
  final List<EmergencyContact> contacts;
  final String       state;
  final String       stationName;   // e.g. "Birpur", "Gandhi Ghat"
  final bool         expanded;
  final VoidCallback onToggle;

  const CollapsibleContacts({
    super.key,
    required this.contacts,
    required this.state,
    required this.stationName,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.stroke),
      ),
      child: Column(children: [
        // ── Header row ──────────────────────────────────────────────────────
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              const Icon(Icons.contact_phone_rounded,
                  size: 14, color: AppPalette.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '📞  Emergency Contacts — $state',
                  style: TextStyle(color: t.textPrimary,
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: t.textSecondary, size: 18,
              ),
            ]),
          ),
        ),

        // ── Expanded body ────────────────────────────────────────────────────
        if (expanded) ...[
          Divider(height: 1, color: t.stroke),
          if (contacts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text('No contacts available.',
                  style: TextStyle(color: t.textSecondary, fontSize: 12)),
            )
          else
            ...contacts.map((c) => _ContactRow(contact: c, t: t)),

          // ── "View All" button → SosScreen with stationName ───────────────
          Divider(height: 1, color: t.stroke),
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.pushNamed(
                context,
                SosScreen.route,
                arguments: {'stationName': stationName},
              );
            },
            borderRadius: const BorderRadius.only(
              bottomLeft:  Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sos_rounded,
                      size: 14, color: AppPalette.critical),
                  const SizedBox(width: 6),
                  Text(
                    'View All Emergency Contacts for $stationName',
                    style: const TextStyle(
                      color: AppPalette.critical,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded,
                      size: 14, color: AppPalette.critical),
                ],
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final EmergencyContact contact;
  final RiverColors      t;
  const _ContactRow({required this.contact, required this.t});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        HapticFeedback.selectionClick();
        final uri = Uri.parse('tel:${contact.phone}');
        if (await canLaunchUrl(uri)) launchUrl(uri);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppPalette.warning.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppPalette.warning.withValues(alpha: 0.35)),
            ),
            child: const Icon(Icons.phone_rounded, size: 15, color: AppPalette.warning),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(contact.name,
                  style: TextStyle(color: t.textPrimary,
                      fontWeight: FontWeight.w700, fontSize: 12)),
              Text(contact.phone,
                  style: TextStyle(color: t.textSecondary, fontSize: 11)),
            ],
          )),
          Icon(Icons.chevron_right_rounded, size: 16, color: t.textSecondary),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PredictCta
// ─────────────────────────────────────────────────────────────────────────────
class PredictCta extends StatelessWidget {
  final String cityName;
  final double currentLevel;
  const PredictCta({
    super.key,
    required this.cityName,
    required this.currentLevel,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.pushNamed(
          context,
          PredictScreen.route,
          arguments: {'cityName': cityName, 'currentLevel': currentLevel},
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: t.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.accent.withValues(alpha: 0.40)),
        ),
        child: Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.auto_graph_rounded, size: 14, color: t.accent),
            const SizedBox(width: 6),
            Text('Predict',
                style: TextStyle(color: t.accent,
                    fontWeight: FontWeight.w800, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MapChip
// ─────────────────────────────────────────────────────────────────────────────
class MapChip extends StatelessWidget {
  final String cityName;
  const MapChip({super.key, required this.cityName});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.pushNamed(context, BiharRiverMapScreen.route);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: t.cardBgElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.stroke),
        ),
        child: Icon(Icons.map_rounded, size: 16, color: t.textSecondary),
      ),
    );
  }
}
