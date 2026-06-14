// lib/screens/alerts_screen.dart  nav-v1 fix2
// FIX: import alerts_provider.dart so AlertSeverity is in scope.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';
import '../providers/alert_provider.dart';
import '../providers/alerts_provider.dart'; // FIX: exports AlertSeverity
import '../app_router.dart';

class AlertsScreen extends ConsumerWidget {
  static const String route = Routes.alerts;
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t      = RiverColors.of(context);
    final ap     = ref.watch(alertProvider);
    final alerts = ap.all;

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          Td3AppBar(
            title: 'Alerts',
            subtitle: '${alerts.length} active alerts',
            actions: [
              IconButton(
                icon: Icon(Icons.map_outlined, color: t.accent),
                tooltip: 'Bihar Map',
                onPressed: () =>
                    Navigator.of(context).pushNamed(Routes.biharRiverMap),
              ),
            ],
          ),
          if (alerts.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 64, color: t.riverNormal),
                    const SizedBox(height: 12),
                    Text('No active alerts',
                        style: TextStyle(
                            color: t.textPrimary, fontSize: 16)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final a = alerts[i];
                    final color =
                        a.severity == AlertSeverity.critical ||
                                a.severity == AlertSeverity.emergency
                            ? t.riverDanger
                            : a.severity == AlertSeverity.warning
                                ? t.riverWarning
                                : t.riverNormal;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Td3Card(
                        elevation: Td3.elevMid,
                        child: ListTile(
                          leading: Icon(Icons.warning_rounded,
                              color: color, size: 22),
                          title: Text(a.title,
                              style: TextStyle(
                                  color: t.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                          subtitle: Text(
                            '${a.river}  ·  ${a.currentLevel.toStringAsFixed(2)} m',
                            style: TextStyle(
                                color: t.textSecondary, fontSize: 12),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border:
                                  Border.all(color: color.withOpacity(0.5)),
                            ),
                            child: Text(
                              a.severity.name.toUpperCase(),
                              style: TextStyle(
                                  color: color,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800)),
                          ),
                          onTap: () => Navigator.of(context).pushNamed(
                            Routes.cityDetail,
                            arguments: a.title,
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: alerts.length,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'alerts_sos',
        backgroundColor: t.riverDanger,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.sos_rounded),
        label: const Text('SOS'),
        onPressed: () => Navigator.of(context).pushNamed(Routes.sos),
      ),
    );
  }
}
