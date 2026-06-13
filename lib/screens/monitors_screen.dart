// lib/screens/monitors_screen.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';
import '../providers/flood_provider.dart';

class MonitorsScreen extends ConsumerWidget {
  const MonitorsScreen({super.key});

  static const String route = '/monitors';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t  = RiverColors.of(context);
    final fp = ref.watch(floodProvider);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          Td3AppBar(
            title: 'River Monitors',
            subtitle: '${fp.stationCount} stations',
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final d = fp.liveLevels[i];
                  final color = d.riskLevel == 'CRITICAL'
                      ? t.riverDanger
                      : d.riskLevel == 'HIGH' || d.riskLevel == 'WARNING'
                          ? t.riverWarning
                          : d.riskLevel == 'DANGER'
                              ? t.riverDanger
                              : t.riverNormal;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Td3Card(
                      elevation: Td3.elevLow,
                      child: ListTile(
                        leading: Icon(Icons.water_rounded,
                            color: color, size: 24),
                        title: Text(
                            d.cityName ?? d.stationId,
                            style: TextStyle(
                                color: t.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        subtitle: Text(
                            d.riverName ?? '',
                            style: TextStyle(
                                color: t.textSecondary,
                                fontSize: 11)),
                        trailing: Text(
                            d.riskLevel,
                            style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  );
                },
                childCount: fp.liveLevels.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
