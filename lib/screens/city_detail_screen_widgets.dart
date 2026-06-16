// lib/screens/city_detail_screen_widgets.dart
// v4 — fix: backgroun → backgroundColor typo at line 203
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

Color cityDetailRiskColor(String risk) {
  switch (risk.toUpperCase()) {
    case 'CRITICAL': return AppPalette.critical;
    case 'SEVERE':   return AppPalette.danger;
    case 'MODERATE': return AppPalette.warning;
    default:         return AppPalette.safe;
  }
}

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
        msg  = '\u{1F6A8} CRITICAL — Level above HFL. Immediate action required.';
        icon = Icons.warning_amber_rounded;
        break;
      case 'SEVERE':
        bg   = AppPalette.danger.withValues(alpha: 0.14);
        msg  = '\uD83D\uDD34 SEVERE — Above danger level. Stay alert.';
        icon = Icons.error_outline_rounded;
        break;
      case 'MODERATE':
        bg   = AppPalette.warning.withValues(alpha: 0.12);
        msg  = '\u26A0\uFE0F MODERATE — Above warning level. Monitor closely.';
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
        Text('Loading data for $cityName\u2026',
            style: TextStyle(color: t.textSecondary, fontSize: 13)),
      ]),
    );
  }
}

class GaugeHeroCard extends StatelessWidget {
  final FloodData data;
  const GaugeHeroCard({super.key, required this.data});

  static String _formatUpdated(DateTime ts) {
    final now     = DateTime.now();
    final hh      = ts.hour.toString().padLeft(2, '0');
    final mm      = ts.minute.toString().padLeft(2, '0');
    final time    = '$hh:$mm';
    final sameDay = ts.year == now.year &&
                    ts.month == now.month &&
                    ts.day == now.day;
    if (sameDay) return 'Updated $time';
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return 'Updated ${ts.day} ${months[ts.month - 1]} $time';
  }

  @override
  Widget build(BuildContext context) {
    final t     = RiverColors.of(context);
    final riskC = cityDetailRiskColor(data.riskLevel);
    final pct   = (data.currentLevel / data.dangerLevel).clamp(0.0, 1.2);
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
            backgroundColor: t.cardBgElevated,
            valueColor: AlwaysStoppedAnimation<Color>(riskC),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _MetricPair(
              label: 'Danger Level',
              value: '${data.dangerLevel.toStringAsFixed(2)} m',
              color: t.textSecondary,
            ),
          ),
          Expanded(
            child: _MetricPair(
              label: 'Warning Level',
              value: '${data.warningLevel.toStringAsFixed(2)} m',
              color: t.textSecondary,
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.access_time_rounded, size: 11, color: t.textSecondary),
          const SizedBox(width: 4),
          Text(updatedLabel,
              style: TextStyle(color: t.textSecondary, fontSize: 11)),
          if (hasRain) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: t.chipBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '\uD83C\uDF27 ${rainfall!.toStringAsFixed(1)} mm',
                style: TextStyle(color: t.metricColor,
                    fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}

class _MetricPair extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  const _MetricPair({
    required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: t.textSecondary, fontSize: 10)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(color: color,
          fontSize: 13, fontWeight: FontWeight.w700)),
    ]);
  }
}

class SparklineSection extends StatelessWidget {
  final FloodData data;
  final List<double> history;
  const SparklineSection({super.key, required this.data, required this.history});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.stroke),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Level Trend (24h)',
            style: TextStyle(color: t.textSecondary, fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        SizedBox(
          height: 80,
          child: SparklineChart(
            values: history,
            color: cityDetailRiskColor(data.riskLevel),
          ),
        ),
      ]),
    );
  }
}

class CollapsibleContacts extends StatefulWidget {
  final String stationName;
  const CollapsibleContacts({super.key, required this.stationName});

  @override
  State<CollapsibleContacts> createState() => _CollapsibleContactsState();
}

class _CollapsibleContactsState extends State<CollapsibleContacts> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Column(children: [
      GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.stroke),
          ),
          child: Row(children: [
            Icon(Icons.contacts_rounded, size: 16, color: t.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Emergency Contacts',
                  style: TextStyle(color: t.textPrimary,
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            Icon(_expanded
                ? Icons.expand_less_rounded
                : Icons.expand_more_rounded,
                size: 18, color: t.textSecondary),
          ]),
        ),
      ),
      if (_expanded)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _ContactButtons(stationName: widget.stationName),
        ),
    ]);
  }
}

class _ContactButtons extends StatelessWidget {
  final String stationName;
  const _ContactButtons({required this.stationName});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Column(children: [
      _ContactTile(
        icon: Icons.warning_amber_rounded,
        label: 'SOS / Rescue',
        color: AppPalette.critical,
        onTap: () => Navigator.pushNamed(
          context, '/sos',
          arguments: {'district': stationName},
        ),
      ),
      const SizedBox(height: 6),
      _ContactTile(
        icon: Icons.call_rounded,
        label: 'NDRF Helpline: 9711077372',
        color: t.accent,
        onTap: () => launchUrl(Uri.parse('tel:9711077372')),
      ),
      const SizedBox(height: 6),
      _ContactTile(
        icon: Icons.call_rounded,
        label: 'SDRF Bihar: 0612-2215401',
        color: t.accent,
        onTap: () => launchUrl(Uri.parse('tel:06122215401')),
      ),
    ]);
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final VoidCallback onTap;
  const _ContactTile({
    required this.icon, required this.label,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Row(children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: t.textPrimary,
              fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class QuickActionRow extends StatelessWidget {
  final FloodData data;
  const QuickActionRow({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: _QuickBtn(
          icon: Icons.show_chart_rounded,
          label: 'Predict',
          onTap: () => Navigator.pushNamed(
            context, '/predict',
            arguments: data.stationId,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _QuickBtn(
          icon: Icons.map_rounded,
          label: 'Map',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const BiharRiverMapScreen()),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _QuickBtn(
          icon: Icons.copy_rounded,
          label: 'Copy',
          onTap: () {
            final text = 'Station: ${data.city}\n'
                'Level: ${data.currentLevel.toStringAsFixed(2)} m\n'
                'Risk: ${data.riskLevel}';
            Clipboard.setData(ClipboardData(text: text));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Copied to clipboard')),
            );
          },
        ),
      ),
    ]);
  }
}

class _QuickBtn extends StatelessWidget {
  final IconData icon;
  final String   label;
  final VoidCallback onTap;
  const _QuickBtn({
    required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: t.chipBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.stroke),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: t.accent),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: t.textPrimary,
              fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
