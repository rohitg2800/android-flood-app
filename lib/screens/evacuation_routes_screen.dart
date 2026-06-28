// lib/screens/evacuation_routes_screen.dart  v2 — explicit back button
// Retains all original content; adds AppBackButton leading.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../widgets/app_back_button.dart';
import '../providers/flood_data_provider.dart';

final _selectedDistrictEvrProvider = StateProvider<String?>((_) => null);

class EvacuationRoutesScreen extends ConsumerWidget {
  const EvacuationRoutesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t      = RiverColors.of(context);
    final selDist = ref.watch(_selectedDistrictEvrProvider);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.navBg,
        foregroundColor: t.textPrimary,
        leading: const AppBackButton(),
        title: Text(
          'Evacuation Routes',
          style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.location_city_rounded, color: t.accent),
            tooltip: 'Select District',
            onPressed: () => _showDistrictPicker(context, ref, t),
          ),
        ],
        elevation: 0,
      ),
      body: selDist == null
          ? _DistrictPrompt(
              t: t,
              onTap: () => _showDistrictPicker(context, ref, t),
            )
          : _RouteList(t: t, district: selDist),
    );
  }

  void _showDistrictPicker(
      BuildContext context, WidgetRef ref, RiverColors t) {
    final districts = [
      'patna', 'muzaffarpur', 'bhagalpur', 'darbhanga',
      'sitamarhi', 'supaul', 'madhubani', 'saharsa',
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.navBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Select District',
              style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 8),
          for (final d in districts)
            ListTile(
              leading:
                  Icon(Icons.location_on_rounded, color: t.accent, size: 20),
              title: Text(
                d[0].toUpperCase() + d.substring(1),
                style: TextStyle(
                    color: t.textPrimary, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                ref.read(_selectedDistrictEvrProvider.notifier).state = d;
                Navigator.pop(context);
              },
            ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

class _DistrictPrompt extends StatelessWidget {
  const _DistrictPrompt({required this.t, required this.onTap});
  final RiverColors t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: t.accent.withValues(alpha: 0.25), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_rounded, color: t.accent, size: 48),
              const SizedBox(height: 14),
              Text(
                'Select a District',
                style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap to choose your district and view evacuation routes',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: t.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteList extends StatelessWidget {
  const _RouteList({required this.t, required this.district});
  final RiverColors t;
  final String district;

  static const _routes = {
    'patna': [
      ('NH 19 → Ara bypass', 'Patna ↔ Arrah via NH 19'),
      ('Danapur Rd → Fatuha', 'Western corridor'),
    ],
    'muzaffarpur': [
      ('NH 28 → Hajipur', 'Muzaffarpur ↔ Hajipur bridge'),
      ('Sitamarhi Rd elevated', 'North corridor'),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final label = district[0].toUpperCase() + district.substring(1);
    final routes = _routes[district] ?? [
      ('Route data pending', 'Contact local authorities for guidance'),
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            '$label — Evacuation Routes',
            style: TextStyle(
                color: t.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800),
          ),
        ),
        for (final (name, desc) in routes)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: t.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.directions_rounded,
                      color: t.accent, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: TextStyle(
                              color: t.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                      Text(desc,
                          style: TextStyle(
                              color: t.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
