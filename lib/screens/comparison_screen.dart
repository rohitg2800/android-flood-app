// lib/screens/comparison_screen.dart  v2.2
// Fixed: dataFetchProvider (undefined) → liveLevelsProvider (synchronous List<FloodData>)
//        Import updated: data_fetch_provider → flood_providers
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';
import '../providers/flood_providers.dart';
import '../models/flood_data.dart';

class ComparisonScreen extends ConsumerStatefulWidget {
  static const route = '/comparison';
  const ComparisonScreen({super.key});
  @override
  ConsumerState<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends ConsumerState<ComparisonScreen> {
  String? _stationA;
  String? _stationB;

  @override
  Widget build(BuildContext context) {
    final t      = RiverColors.of(context);
    final rivers = ref.watch(liveLevelsProvider);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          Td3AppBar(
            title: 'Station Comparison',
            subtitle: 'Compare two monitoring stations',
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 60),
            sliver: () {
              final names = rivers.map((r) => r.riverName ?? r.stationName).toSet().toList()..sort();
              final dataA = _stationA != null
                  ? rivers.firstWhere(
                      (r) => (r.riverName ?? r.stationName) == _stationA,
                      orElse: () => rivers.first)
                  : null;
              final dataB = _stationB != null
                  ? rivers.firstWhere(
                      (r) => (r.riverName ?? r.stationName) == _stationB,
                      orElse: () => rivers.first)
                  : null;

              return SliverList(
                delegate: SliverChildListDelegate([

                  // ── Station selectors ──────────────────────────────────
                  Row(
                    children: [
                      Expanded(child: _StationDropdown(
                        t: t, label: 'Station A', color: const Color(0xFF1976D2),
                        value: _stationA, items: names,
                        onChanged: (v) => setState(() => _stationA = v),
                      )),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.compare_arrows_rounded, color: t.textSecondary, size: 22),
                      ),
                      Expanded(child: _StationDropdown(
                        t: t, label: 'Station B', color: const Color(0xFF26A69A),
                        value: _stationB, items: names,
                        onChanged: (v) => setState(() => _stationB = v),
                      )),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (dataA != null && dataB != null) ..._buildComparison(t, dataA, dataB)
                  else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(Icons.compare_arrows_rounded,
                                color: t.textSecondary.withValues(alpha: 0.3), size: 48),
                            const SizedBox(height: 12),
                            Text('Select two stations to compare',
                                style: TextStyle(color: t.textSecondary, fontSize: 13),
                                textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                ]),
              );
            }(),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildComparison(RiverColors t, FloodData a, FloodData b) {
    final nameA = a.riverName ?? a.stationName;
    final nameB = b.riverName ?? b.stationName;
    return [
      Td3Card(
        elevation: Td3.elevMid,
        accentColor: const Color(0xFF0288D1),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(nameA,
                        style: const TextStyle(
                            color: Color(0xFF1976D2),
                            fontSize: 13,
                            fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center)),
                  SizedBox(
                      width: 70,
                      child: Text('Metric',
                          style: TextStyle(
                              color: t.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center)),
                  Expanded(
                    child: Text(nameB,
                        style: const TextStyle(
                            color: Color(0xFF26A69A),
                            fontSize: 13,
                            fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center)),
                ],
              ),
              const Divider(height: 20),
              _CompRow(t: t, label: 'Level (m)',    vA: a.currentLevel, vB: b.currentLevel, unit: 'm', higherIsBad: true),
              _CompRow(t: t, label: 'Danger Level', vA: a.dangerLevel,  vB: b.dangerLevel,  unit: 'm', higherIsBad: false),
              _CompRow(t: t, label: 'Warning Level',vA: a.warningLevel, vB: b.warningLevel, unit: 'm', higherIsBad: false),
              _CompRow(
                t: t, label: '% of Danger',
                vA: a.dangerLevel > 0 ? (a.currentLevel / a.dangerLevel) * 100 : 0,
                vB: b.dangerLevel > 0 ? (b.currentLevel / b.dangerLevel) * 100 : 0,
                unit: '%', higherIsBad: true),
            ],
          ),
        ),
      ),
    ];
  }
}

class _StationDropdown extends StatelessWidget {
  final RiverColors t;
  final String label;
  final Color color;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _StationDropdown({
    required this.t,
    required this.label,
    required this.color,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            hint: Text('Select…', style: TextStyle(color: t.textSecondary, fontSize: 12)),
            isExpanded: true,
            items: items
                .map((n) => DropdownMenuItem(
                    value: n,
                    child: Text(n,
                        style: TextStyle(color: t.textPrimary, fontSize: 12),
                        overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
          ),
        ),
      ),
    ],
  );
}

class _CompRow extends StatelessWidget {
  final RiverColors t;
  final String label, unit;
  final double vA, vB;
  final bool higherIsBad;
  const _CompRow({
    required this.t,
    required this.label,
    required this.vA,
    required this.vB,
    required this.unit,
    required this.higherIsBad,
  });
  @override
  Widget build(BuildContext context) {
    final aIsBetter = higherIsBad ? vA < vB : vA > vB;
    final aColor = aIsBetter ? const Color(0xFF43A047) : const Color(0xFFE53935);
    final bColor = !aIsBetter ? const Color(0xFF43A047) : const Color(0xFFE53935);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
              child: Text('${vA.toStringAsFixed(2)}$unit',
                  style: TextStyle(color: aColor, fontSize: 13, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center)),
          SizedBox(
              width: 70,
              child: Text(label,
                  style: TextStyle(color: t.textSecondary, fontSize: 10),
                  textAlign: TextAlign.center)),
          Expanded(
              child: Text('${vB.toStringAsFixed(2)}$unit',
                  style: TextStyle(color: bColor, fontSize: 13, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}
