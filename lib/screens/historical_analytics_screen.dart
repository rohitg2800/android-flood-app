// lib/screens/historical_analytics_screen.dart  v2.0
// Historical flood explorer — year/month filters, peak events, district rows
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';

class HistoricalAnalyticsScreen extends StatefulWidget {
  static const route = '/historical-analytics';
  const HistoricalAnalyticsScreen({super.key});
  @override
  State<HistoricalAnalyticsScreen> createState() => _HistoricalAnalyticsScreenState();
}

class _HistoricalAnalyticsScreenState extends State<HistoricalAnalyticsScreen> {
  int  _selectedYear = 2024;
  int? _selectedMonth;

  static const _years = [2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2016, 2015];
  static const _months = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec',
  ];

  // Synthetic historical data keyed by year
  static const _peakEvents = {
    2024: [
      (river: 'Kosi',    district: 'Supaul',    level: 44.82, date: '12 Aug'),
      (river: 'Bagmati', district: 'Sitamarhi', level: 68.20, date: '19 Aug'),
      (river: 'Gandak',  district: 'Gopalganj', level: 62.14, date: '04 Sep'),
      (river: 'Ganga',   district: 'Patna',     level: 50.71, date: '27 Sep'),
    ],
    2023: [
      (river: 'Burhi Gandak', district: 'Muzaffarpur', level: 55.40, date: '08 Aug'),
      (river: 'Bagmati',      district: 'Darbhanga',   level: 71.30, date: '22 Aug'),
      (river: 'Kosi',         district: 'Khagaria',    level: 46.90, date: '30 Aug'),
    ],
    2022: [
      (river: 'Ganga',   district: 'Bhagalpur', level: 37.60, date: '17 Sep'),
      (river: 'Gandak',  district: 'W Champaran',level:59.80, date: '02 Aug'),
    ],
  };

  static const _districtRisks = [
    (district: 'Supaul',       flooded2024: true,  avgRainfall: 1480, riskScore: 0.92),
    (district: 'Sitamarhi',    flooded2024: true,  avgRainfall: 1310, riskScore: 0.87),
    (district: 'Madhubani',    flooded2024: true,  avgRainfall: 1420, riskScore: 0.84),
    (district: 'Darbhanga',    flooded2024: true,  avgRainfall: 1180, riskScore: 0.81),
    (district: 'Muzaffarpur',  flooded2024: true,  avgRainfall: 1200, riskScore: 0.78),
    (district: 'Gopalganj',    flooded2024: false, avgRainfall: 1050, riskScore: 0.64),
    (district: 'Khagaria',     flooded2024: true,  avgRainfall: 1100, riskScore: 0.72),
    (district: 'Samastipur',   flooded2024: false, avgRainfall: 980,  riskScore: 0.55),
    (district: 'Bhagalpur',    flooded2024: false, avgRainfall: 870,  riskScore: 0.45),
    (district: 'Patna',        flooded2024: false, avgRainfall: 930,  riskScore: 0.39),
  ];

  @override
  Widget build(BuildContext context) {
    final t      = RiverColors.of(context);
    final events = _peakEvents[_selectedYear] ?? [];

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          Td3AppBar(
            title: 'Historical Analytics',
            subtitle: 'Flood records & district trends',
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 60),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Year filter ───────────────────────────────────────────
                Text('Select Year', style: TextStyle(color: t.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _years.map((y) {
                      final sel = y == _selectedYear;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() { _selectedYear = y; _selectedMonth = null; });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel ? const Color(0xFF0288D1) : t.cardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sel ? const Color(0xFF0288D1) : t.stroke.withValues(alpha: 0.3)),
                          ),
                          child: Text('$y', style: TextStyle(color: sel ? Colors.white : t.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),

                // ── Month filter ──────────────────────────────────────────
                SizedBox(
                  height: 30,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _MonthChip(t: t, label: 'All', sel: _selectedMonth == null,
                        onTap: () => setState(() => _selectedMonth = null)),
                      ...List.generate(12, (i) => _MonthChip(
                        t: t, label: _months[i], sel: _selectedMonth == i + 1,
                        onTap: () => setState(() => _selectedMonth = i + 1),
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Summary KPIs ──────────────────────────────────────────
                Row(
                  children: [
                    Expanded(child: _MiniKpi(t: t, label: 'Peak Events', value: '${events.length}', color: const Color(0xFFE53935))),
                    const SizedBox(width: 10),
                    Expanded(child: _MiniKpi(t: t, label: 'Districts Affected', value: '${(events.length * 2.3).round()}', color: const Color(0xFFFF8F00))),
                    const SizedBox(width: 10),
                    Expanded(child: _MiniKpi(t: t, label: 'Avg Max Level', value: events.isEmpty ? '—' : '${(events.map((e) => e.level).reduce((a,b)=>a+b)/events.length).toStringAsFixed(1)}m', color: const Color(0xFF0288D1))),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Peak Events Timeline ──────────────────────────────────
                Td3Card(
                  elevation: Td3.elevMid,
                  accentColor: const Color(0xFFE53935),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Peak Flood Events — $_selectedYear',
                          style: TextStyle(color: t.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 14),
                        if (events.isEmpty)
                          Text('No peak events recorded for $_selectedYear.',
                            style: TextStyle(color: t.textSecondary, fontSize: 12))
                        else
                          ...events.map((e) => _EventRow(t: t, event: e)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── District Risk Table ───────────────────────────────────
                Td3Card(
                  elevation: Td3.elevMid,
                  accentColor: const Color(0xFF26A69A),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('District Flood Risk Index',
                          style: TextStyle(color: t.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('Based on 10-year historical average',
                          style: TextStyle(color: t.textSecondary, fontSize: 10)),
                        const SizedBox(height: 14),
                        ..._districtRisks.map((d) => _DistrictRiskRow(t: t, data: d)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthChip extends StatelessWidget {
  final RiverColors t;
  final String label;
  final bool sel;
  final VoidCallback onTap;
  const _MonthChip({required this.t, required this.label, required this.sel, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () { HapticFeedback.selectionClick(); onTap(); },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: sel ? const Color(0xFF0288D1).withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sel ? const Color(0xFF0288D1) : t.stroke.withValues(alpha: 0.2)),
      ),
      child: Text(label, style: TextStyle(color: sel ? const Color(0xFF0288D1) : t.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
    ),
  );
}

class _MiniKpi extends StatelessWidget {
  final RiverColors t;
  final String label, value;
  final Color color;
  const _MiniKpi({required this.t, required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
        Text(label,  style: TextStyle(color: t.textSecondary, fontSize: 9, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
      ],
    ),
  );
}

class _EventRow extends StatelessWidget {
  final RiverColors t;
  final ({String river, String district, double level, String date}) event;
  const _EventRow({required this.t, required this.event});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: const Color(0x1AE53935),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x40E53935)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(event.date.split(' ')[0], style: const TextStyle(color: Color(0xFFE53935), fontSize: 14, fontWeight: FontWeight.w800, height: 1)),
              Text(event.date.split(' ')[1], style: const TextStyle(color: Color(0xFFE53935), fontSize: 9)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.river, style: TextStyle(color: t.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
              Text(event.district, style: TextStyle(color: t.textSecondary, fontSize: 11)),
            ],
          ),
        ),
        Text('${event.level}m', style: const TextStyle(color: Color(0xFFE53935), fontSize: 13, fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

class _DistrictRiskRow extends StatelessWidget {
  final RiverColors t;
  final ({String district, bool flooded2024, int avgRainfall, double riskScore}) data;
  const _DistrictRiskRow({required this.t, required this.data});
  @override
  Widget build(BuildContext context) {
    final color = data.riskScore > 0.80 ? const Color(0xFFE53935)
                : data.riskScore > 0.60 ? const Color(0xFFFF8F00)
                : const Color(0xFF43A047);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(data.district, style: TextStyle(color: t.textPrimary, fontSize: 12, fontWeight: FontWeight.w500))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: data.riskScore,
                minHeight: 5,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('${(data.riskScore * 100).round()}%', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          if (data.flooded2024)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: const Color(0x1AE53935), borderRadius: BorderRadius.circular(4)),
              child: const Text('2024', style: TextStyle(color: Color(0xFFE53935), fontSize: 9, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}
