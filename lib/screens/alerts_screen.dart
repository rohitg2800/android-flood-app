import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../constants/bihar_constants.dart';

class AlertsScreen extends ConsumerWidget {
  static const String route = '/alerts';
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final criticalDistricts = kBiharDistricts
        .where((d) => d['risk'] == 'CRITICAL').toList();
    final highDistricts = kBiharDistricts
        .where((d) => d['risk'] == 'HIGH').toList();

    return Scaffold(
      backgroundColor: AppPalette.navy0,
      appBar: AppBar(
        backgroundColor: AppPalette.navy1,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Flood Alerts', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
            Text('Bihar — All Districts', style: TextStyle(fontSize: 12, color: AppPalette.textMuted)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // — Active alerts banner
          if (criticalDistricts.isNotEmpty) ..._buildAlertBanner(
            title: '🔴 CRITICAL ALERT',
            subtitle: '${criticalDistricts.length} districts at critical flood risk',
            color: AppPalette.red,
          ),
          const SizedBox(height: 12),
          if (highDistricts.isNotEmpty) ..._buildAlertBanner(
            title: '🟠 HIGH ALERT',
            subtitle: '${highDistricts.length} districts at high flood risk',
            color: AppPalette.orange,
          ),
          const SizedBox(height: 20),

          // — District alerts list
          const Text('District Risk Status',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: AppPalette.textMuted, letterSpacing: 0.8)),
          const SizedBox(height: 10),
          ...kBiharDistricts.map((d) => _DistrictAlertTile(district: d)),
          const SizedBox(height: 20),

          // — Emergency contacts
          const Text('Emergency Contacts — Bihar',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: AppPalette.textMuted, letterSpacing: 0.8)),
          const SizedBox(height: 10),
          _EmergencyContacts(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  List<Widget> _buildAlertBanner({required String title, required String subtitle, required Color color}) {
    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_rounded, color: color, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 14)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppPalette.textMuted)),
              ],
            ),
          ],
        ),
      ),
    ];
  }
}

class _DistrictAlertTile extends StatelessWidget {
  final Map<String, dynamic> district;
  const _DistrictAlertTile({required this.district});

  Color _riskColor(String risk) {
    switch (risk) {
      case 'CRITICAL': return AppPalette.red;
      case 'HIGH':     return AppPalette.orange;
      case 'MODERATE': return AppPalette.gold;
      default:         return AppPalette.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final risk = district['risk'] as String;
    final color = _riskColor(risk);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppPalette.navy1,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(district['name'] as String,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, color: Colors.white, fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(district['hindi'] as String,
                        style: const TextStyle(fontSize: 11, color: AppPalette.textMuted)),
                  ],
                ),
                Text('River: ${district['river']}',
                    style: const TextStyle(fontSize: 11, color: AppPalette.textMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(risk, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }
}

class _EmergencyContacts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const contacts = [
      {'name': 'Bihar SDRF', 'number': '0612-2294204', 'icon': Icons.shield_rounded},
      {'name': 'NDRF Bihar', 'number': '9473191253',   'icon': Icons.emergency_rounded},
      {'name': 'Flood Control Room', 'number': '0612-2215629', 'icon': Icons.water_damage_rounded},
      {'name': 'District DM Patna', 'number': '0612-2219277', 'icon': Icons.location_city_rounded},
    ];
    return Column(
      children: contacts.map((c) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppPalette.navy1,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppPalette.divider),
        ),
        child: Row(
          children: [
            Icon(c['icon'] as IconData, color: AppPalette.blue1, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(c['name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 14)),
            ),
            Text(c['number'] as String,
                style: const TextStyle(fontSize: 13, color: AppPalette.textMuted)),
          ],
        ),
      )).toList(),
    );
  }
}
