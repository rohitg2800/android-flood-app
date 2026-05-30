import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../constants/bihar_constants.dart';
import '../providers/flood_providers.dart';
import 'predict_screen.dart';
import 'bihar_river_map_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final telemetry = ref.watch(telemetryProvider(
      (state: kBiharState, station: kBiharDefaultStation, limit: 6),
    ));

    return Scaffold(
      backgroundColor: AppPalette.navy0,
      appBar: AppBar(
        backgroundColor: AppPalette.navy1,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bihar Flood Watch',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            Text('बिहार बाढ़ निगरानी',
                style: TextStyle(fontSize: 12, color: AppPalette.textMuted)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.water_damage_rounded, color: AppPalette.blue1),
            tooltip: 'Predict Flood',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PredictScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppPalette.blue1,
        onRefresh: () async => ref.invalidate(telemetryProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // — Season banner
            _SeasonBanner(),
            const SizedBox(height: 16),

            // — Bihar summary KPIs
            const Text('Active Monitoring',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                    color: AppPalette.textMuted, letterSpacing: 0.8)),
            const SizedBox(height: 10),
            _BiharKpiRow(),
            const SizedBox(height: 20),

            // — River status cards
            const Text('Bihar Rivers — Current Status',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                    color: AppPalette.textMuted, letterSpacing: 0.8)),
            const SizedBox(height: 10),
            ...kBiharRivers.map((r) => _RiverStatusCard(river: r)),
            const SizedBox(height: 20),

            // — Critical districts
            const Text('High Risk Districts',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                    color: AppPalette.textMuted, letterSpacing: 0.8)),
            const SizedBox(height: 10),
            _CriticalDistrictsGrid(),
            const SizedBox(height: 20),

            // — Quick actions
            const Text('Quick Actions',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                    color: AppPalette.textMuted, letterSpacing: 0.8)),
            const SizedBox(height: 10),
            _QuickActionsRow(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SeasonBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isMonsoon = now.month >= kMonsoonStartMonth && now.month <= kMonsoonEndMonth;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isMonsoon
              ? [AppPalette.blue1.withOpacity(0.3), AppPalette.navy1]
              : [AppPalette.navy1, AppPalette.navy2],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMonsoon ? AppPalette.blue1.withOpacity(0.5) : AppPalette.divider,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isMonsoon ? Icons.water_drop_rounded : Icons.wb_sunny_rounded,
            color: isMonsoon ? AppPalette.blue1 : AppPalette.gold,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMonsoon ? '🌧️ Monsoon Active' : '☀️ Pre-Monsoon',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: Colors.white, fontSize: 15),
                ),
                Text(
                  isMonsoon
                      ? 'Bihar flood monitoring is at heightened alert'
                      : 'Monsoon season: Jun–Oct. Stay prepared.',
                  style: const TextStyle(fontSize: 12, color: AppPalette.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BiharKpiRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final criticalCount = kBiharDistricts
        .where((d) => d['risk'] == 'CRITICAL').length;
    final highCount = kBiharDistricts
        .where((d) => d['risk'] == 'HIGH').length;
    return Row(
      children: [
        Expanded(child: _KpiCard(label: 'Rivers\nMonitored',
            value: '${kBiharRivers.length}', color: AppPalette.blue1,
            icon: Icons.waves_rounded)),
        const SizedBox(width: 10),
        Expanded(child: _KpiCard(label: 'Stations\nActive',
            value: '${kBiharStations.length}', color: AppPalette.green,
            icon: Icons.sensors_rounded)),
        const SizedBox(width: 10),
        Expanded(child: _KpiCard(label: 'Critical\nDistricts',
            value: '$criticalCount', color: AppPalette.red,
            icon: Icons.warning_rounded)),
        const SizedBox(width: 10),
        Expanded(child: _KpiCard(label: 'High Risk\nDistricts',
            value: '$highCount', color: AppPalette.orange,
            icon: Icons.error_outline_rounded)),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _KpiCard({required this.label, required this.value,
      required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.navy1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: AppPalette.textMuted)),
        ],
      ),
    );
  }
}

class _RiverStatusCard extends StatelessWidget {
  final Map<String, dynamic> river;
  const _RiverStatusCard({required this.river});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.navy1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppPalette.blue1.withOpacity(0.15),
            ),
            child: const Icon(Icons.waves_rounded, color: AppPalette.blue1, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(river['name'] as String,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, color: Colors.white, fontSize: 15)),
                    const SizedBox(width: 8),
                    Text(river['hindi'] as String,
                        style: const TextStyle(fontSize: 12, color: AppPalette.textMuted)),
                  ],
                ),
                const SizedBox(height: 2),
                Text('${(river['stations'] as List).length} stations  •  ${river['length_km']} km',
                    style: const TextStyle(fontSize: 12, color: AppPalette.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('⚠️ ${river['danger_level_m']} m',
                  style: const TextStyle(fontSize: 11, color: AppPalette.red)),
              Text('🔔 ${river['warning_level_m']} m',
                  style: const TextStyle(fontSize: 11, color: AppPalette.orange)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CriticalDistrictsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final critical = kBiharDistricts
        .where((d) => d['risk'] == 'CRITICAL' || d['risk'] == 'HIGH')
        .toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.4),
      itemCount: critical.length,
      itemBuilder: (_, i) {
        final d = critical[i];
        final isCritical = d['risk'] == 'CRITICAL';
        final color = isCritical ? AppPalette.red : AppPalette.orange;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Icon(isCritical ? Icons.warning_rounded : Icons.error_outline_rounded,
                  color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(d['name'] as String,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13)),
                    Text(d['river'] as String,
                        style: TextStyle(fontSize: 10, color: color)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Widget _QuickActionsRow(BuildContext context) {
  return Row(
    children: [
      Expanded(
        child: _ActionButton(
          icon: Icons.water_damage_rounded,
          label: 'Predict Flood',
          color: AppPalette.blue1,
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const PredictScreen())),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _ActionButton(
          icon: Icons.map_rounded,
          label: 'River Map',
          color: AppPalette.green,
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const BiharRiverMapScreen())),
        ),
      ),
    ],
  );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.icon, required this.label,
        required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}
