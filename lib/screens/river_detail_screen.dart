// lib/screens/river_detail_screen.dart  v3.3
// Fixed: data.city/district/state (String?) null guards, data.hfl (double?) null guard
library;

import 'package:flutter/material.dart';
import '../models/flood_data.dart';
import '../theme/river_theme.dart';
import '../widgets/ops_area_chart.dart';
import '../widgets/probability_bar_widget.dart';
import '../widgets/risk_bar.dart';

class RiverDetailScreen extends StatelessWidget {
  final FloodData data;
  const RiverDetailScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final col = data.priorityColor;
    return Scaffold(
      backgroundColor: AppPalette.abyss1,
      appBar: AppBar(
        backgroundColor: AppPalette.abyss2,
        foregroundColor: AppPalette.textWhite,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.city ?? data.stationName, style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, color: AppPalette.textWhite,
            )),
            Text(_headerSub, style: const TextStyle(
              fontSize: 11, color: AppPalette.textGrey,
            )),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _RiskBadge(risk: data.riskLevel, color: col),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MetaCard(
              river:    data.riverName ?? '—',
              district: data.district  ?? '',
              state:    data.state     ?? '',
              color:    col,
            ),
            const SizedBox(height: 14),
            const _SectionTitle('Water Level'),
            _LevelGrid(data: data, col: col),
            const SizedBox(height: 14),
            const _SectionTitle('Risk Gauge'),
            RiskBar(
              value:   data.capacityPercent.clamp(0, 100),
              warning: data.warningLevel > 0 && data.dangerLevel > 0
                  ? (data.warningLevel / data.dangerLevel * 100).clamp(0, 100)
                  : 60,
              danger: 80,
            ),
            const SizedBox(height: 14),
            const _SectionTitle('Rainfall & Flow'),
            _RainfallCard(data: data, col: col),
            const SizedBox(height: 14),
            const _SectionTitle('Flood Probability'),
            ProbabilityBarWidget(
              probabilities: {
                'LOW':      (100 - data.capacityPercent.clamp(0, 100)),
                'MODERATE': (data.capacityPercent.clamp(0, 60) > 30 ? 40.0 : 15.0),
                'SEVERE':   (data.capacityPercent.clamp(0, 90) > 60 ? 35.0 : 10.0),
                'CRITICAL': data.capacityPercent.clamp(0, 100) > 80
                    ? (data.capacityPercent - 80).clamp(0, 100)
                    : 0.0,
              },
              topSeverity: data.riskLevel,
            ),
            const SizedBox(height: 14),
            const _SectionTitle('Recent Trend'),
            SizedBox(
              height: 180,
              child: OpsAreaChart(
                values: [
                  data.currentLevel,
                  data.warningLevel * 0.85,
                  data.currentLevel * 0.95,
                  data.currentLevel,
                  data.dangerLevel  * 0.75,
                  data.currentLevel * 1.02,
                ],
                xLabels: const ['T-5h', 'T-4h', 'T-3h', 'T-2h', 'T-1h', 'Now'],
                lineColor: col,
                minY: 0,
                maxY: (data.hfl != null && data.hfl! > 0)
                    ? data.hfl!
                    : data.dangerLevel * 1.1,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String get _headerSub {
    final parts = <String>[];
    if ((data.riverName ?? '').isNotEmpty) parts.add(data.riverName!);
    if ((data.district  ?? '').isNotEmpty) parts.add(data.district!);
    if ((data.state     ?? '').isNotEmpty) parts.add(data.state!);
    return parts.join('  ·  ');
  }
}

class _MetaCard extends StatelessWidget {
  final String river, district, state;
  final Color  color;
  const _MetaCard({
    required this.river,
    required this.district,
    required this.state,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppPalette.abyss2, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.20)),
    ),
    child: Column(children: [
      _MetaRow(icon: Icons.water_outlined,        label: 'River',            value: river,    color: color),
      if (district.isNotEmpty) ...[
        const Divider(color: AppPalette.abyss4, height: 14),
        _MetaRow(icon: Icons.location_city_outlined, label: 'District (Zila)', value: district, color: color),
      ],
      if (state.isNotEmpty) ...[
        const Divider(color: AppPalette.abyss4, height: 14),
        _MetaRow(icon: Icons.map_outlined, label: 'State', value: state, color: color),
      ],
    ]),
  );
}

class _MetaRow extends StatelessWidget {
  final IconData icon; final String label, value; final Color color;
  const _MetaRow({required this.icon, required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 15, color: color.withValues(alpha: 0.80)),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(color: AppPalette.textGrey, fontSize: 11)),
    const Spacer(),
    Text(value,  style: const TextStyle(color: AppPalette.textWhite, fontSize: 12, fontWeight: FontWeight.w700)),
  ]);
}

class _LevelGrid extends StatelessWidget {
  final FloodData data; final Color col;
  const _LevelGrid({required this.data, required this.col});
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: _StatTile(label: 'Current', value: '${data.currentLevel.toStringAsFixed(2)} m', color: col)),
    const SizedBox(width: 8),
    Expanded(child: _StatTile(label: 'Warning', value: '${data.warningLevel.toStringAsFixed(2)} m', color: AppPalette.amber)),
    const SizedBox(width: 8),
    Expanded(child: _StatTile(label: 'Danger',  value: '${data.dangerLevel.toStringAsFixed(2)} m',  color: AppPalette.critical)),
  ]);
}

class _StatTile extends StatelessWidget {
  final String label, value; final Color color;
  const _StatTile({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
    decoration: BoxDecoration(
      color: AppPalette.abyss2, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppPalette.textGrey, fontSize: 10)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
    ]),
  );
}

class _RainfallCard extends StatelessWidget {
  final FloodData data; final Color col;
  const _RainfallCard({required this.data, required this.col});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppPalette.abyss2, borderRadius: BorderRadius.circular(12)),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _InfoPill(
          label: 'Rainfall',
          value: '${data.imdRainfallMm?.toStringAsFixed(1) ?? data.effectiveRainfallMm.toStringAsFixed(1)} mm',
          color: col,
        ),
        _InfoPill(
          label: 'Flow Rate',
          value: data.flowRate != null ? '${data.flowRate!.toStringAsFixed(0)} m³/s' : '—',
          color: col,
        ),
        _InfoPill(
          label: 'Capacity',
          value: '${data.capacityPercent.toStringAsFixed(0)}%',
          color: col,
        ),
      ],
    ),
  );
}

class _InfoPill extends StatelessWidget {
  final String label, value; final Color color;
  const _InfoPill({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(label, style: const TextStyle(color: AppPalette.textGrey, fontSize: 10)),
    const SizedBox(height: 4),
    Text(value,  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
  ]);
}

class _RiskBadge extends StatelessWidget {
  final String risk; final Color color;
  const _RiskBadge({required this.risk, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.40)),
    ),
    child: Text(risk, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(
      color: AppPalette.textGrey, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1,
    )),
  );
}
