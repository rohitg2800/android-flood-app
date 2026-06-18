// lib/screens/state_matrix_screen.dart  v2.0
// Complete Bihar district matrix — 38 districts, color-coded risk, tap to detail
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';
import '../providers/data_fetch_provider.dart';
import '../services/alert_engine.dart';
import '../app_router.dart';

class StateMatrixScreen extends ConsumerWidget {
  static const route = '/state-matrix';
  const StateMatrixScreen({super.key});

  // All 38 Bihar districts with their primary rivers
  static const _districts = [
    (name: 'Araria',        river: 'Kosi',         riskBase: 0.72),
    (name: 'Arwal',         river: 'Sone',          riskBase: 0.28),
    (name: 'Aurangabad',    river: 'Sone',          riskBase: 0.25),
    (name: 'Banka',         river: 'Chandan',       riskBase: 0.45),
    (name: 'Begusarai',     river: 'Ganga',         riskBase: 0.60),
    (name: 'Bhagalpur',     river: 'Ganga',         riskBase: 0.50),
    (name: 'Bhojpur',       river: 'Ganga/Sone',    riskBase: 0.35),
    (name: 'Buxar',         river: 'Ganga',         riskBase: 0.40),
    (name: 'Darbhanga',     river: 'Bagmati/Kamla', riskBase: 0.82),
    (name: 'E. Champaran',  river: 'Gandak/Bagmati',riskBase: 0.78),
    (name: 'Gaya',          river: 'Falgu',         riskBase: 0.22),
    (name: 'Gopalganj',     river: 'Gandak',        riskBase: 0.65),
    (name: 'Jamui',         river: 'Chandan',       riskBase: 0.30),
    (name: 'Jehanabad',     river: 'Punpun',        riskBase: 0.28),
    (name: 'Kaimur',        river: 'Karmanasha',    riskBase: 0.32),
    (name: 'Katihar',       river: 'Ganga/Kosi',    riskBase: 0.68),
    (name: 'Khagaria',      river: 'Kosi/Bagmati',  riskBase: 0.74),
    (name: 'Kishanganj',    river: 'Mahananda',     riskBase: 0.58),
    (name: 'Lakhisarai',    river: 'Ganga',         riskBase: 0.42),
    (name: 'Madhepura',     river: 'Kosi',          riskBase: 0.79),
    (name: 'Madhubani',     river: 'Kamla/Bagmati', riskBase: 0.85),
    (name: 'Munger',        river: 'Ganga',         riskBase: 0.38),
    (name: 'Muzaffarpur',   river: 'Gandak/Burhi',  riskBase: 0.76),
    (name: 'Nalanda',       river: 'Panchane',      riskBase: 0.20),
    (name: 'Nawada',        river: 'Sakri',         riskBase: 0.22),
    (name: 'Patna',         river: 'Ganga/Punpun',  riskBase: 0.44),
    (name: 'Purnia',        river: 'Kosi',          riskBase: 0.70),
    (name: 'Rohtas',        river: 'Sone',          riskBase: 0.26),
    (name: 'Saharsa',       river: 'Kosi',          riskBase: 0.80),
    (name: 'Samastipur',    river: 'Burhi Gandak',  riskBase: 0.54),
    (name: 'Saran',         river: 'Ganga/Gandak',  riskBase: 0.58),
    (name: 'Sheikhpura',    river: 'Ganga',         riskBase: 0.18),
    (name: 'Sheohar',       river: 'Bagmati',       riskBase: 0.88),
    (name: 'Sitamarhi',     river: 'Bagmati',       riskBase: 0.86),
    (name: 'Siwan',         river: 'Ghaghra/Gandak',riskBase: 0.52),
    (name: 'Supaul',        river: 'Kosi',          riskBase: 0.91),
    (name: 'Vaishali',      river: 'Gandak/Ganga',  riskBase: 0.62),
    (name: 'W. Champaran',  river: 'Gandak',        riskBase: 0.72),
  ];

  Color _riskColor(double r) {
    if (r > 0.80) return const Color(0xFFE53935);
    if (r > 0.60) return const Color(0xFFFF8F00);
    if (r > 0.40) return const Color(0xFFF9A825);
    return const Color(0xFF43A047);
  }

  String _riskLabel(double r) {
    if (r > 0.80) return 'CRITICAL';
    if (r > 0.60) return 'WARNING';
    if (r > 0.40) return 'WATCH';
    return 'SAFE';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t      = RiverColors.of(context);
    final alerts = ref.watch(alertsProvider);

    final criticalCount = _districts.where((d) => d.riskBase > 0.80).length;
    final warningCount  = _districts.where((d) => d.riskBase > 0.60 && d.riskBase <= 0.80).length;
    final watchCount    = _districts.where((d) => d.riskBase > 0.40 && d.riskBase <= 0.60).length;
    final safeCount     = _districts.where((d) => d.riskBase <= 0.40).length;

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          Td3AppBar(
            title: 'State Matrix',
            subtitle: 'All 38 Bihar districts · flood risk',
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 60),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Risk summary badges ───────────────────────────────────
                Row(
                  children: [
                    _Badge(label: 'Critical', count: criticalCount, color: const Color(0xFFE53935)),
                    const SizedBox(width: 8),
                    _Badge(label: 'Warning',  count: warningCount,  color: const Color(0xFFFF8F00)),
                    const SizedBox(width: 8),
                    _Badge(label: 'Watch',    count: watchCount,    color: const Color(0xFFF9A825)),
                    const SizedBox(width: 8),
                    _Badge(label: 'Safe',     count: safeCount,     color: const Color(0xFF43A047)),
                  ],
                ),
                const SizedBox(height: 14),

                // ── District grid ─────────────────────────────────────────
                ..._districts.map((d) {
                  final color = _riskColor(d.riskBase);
                  final liveAlerts = alerts.where((a) =>
                    a.district.toLowerCase().contains(d.name.toLowerCase())).length;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Td3Card(
                      elevation: Td3.elevLow,
                      accentColor: color,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context).pushNamed(Routes.cityDetail, arguments: d.name);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 10, height: 10,
                                decoration: BoxDecoration(color: color, shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 6)]),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(d.name, style: TextStyle(color: t.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                                    Text(d.river, style: TextStyle(color: t.textSecondary, fontSize: 10)),
                                  ],
                                ),
                              ),
                              if (liveAlerts > 0)
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0x1AE53935),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0x40E53935)),
                                  ),
                                  child: Text('$liveAlerts alert${liveAlerts>1?"s":""}',
                                    style: const TextStyle(color: Color(0xFFE53935), fontSize: 9, fontWeight: FontWeight.w700)),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: color.withValues(alpha: 0.3)),
                                ),
                                child: Text(_riskLabel(d.riskBase),
                                  style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.chevron_right_rounded, color: t.textSecondary.withValues(alpha: 0.4), size: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _Badge({required this.label, required this.count, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text('$count', style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 9, fontWeight: FontWeight.w600)),
        ],
      ),
    ),
  );
}
