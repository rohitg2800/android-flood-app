// lib/widgets/danger_proximity_banner.dart  v2.2
//
// v2.2 fix:
//   - Riverpod 3.x removed valueOrNull; use asData?.value instead.
//
// v2.1 fix:
//   - Use userLocationProvider (FutureProvider<Position?>) instead of
//     the non-existent locationProvider.
//
// v2.0 changes:
//   - Reads from ActiveAlertController.alerts (not raw liveLevelsProvider)
//   - Shows rate-of-rise in banner text when >= 0.5 m/h
//   - Distance threshold varies by severity:
//       EXTREME / CRITICAL → 120 km
//       DANGER             → 80 km
//       RISING             → 60 km
//   - Added RISING tier to banner colour (sky blue)
library;

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../data/bihar_rivers.dart';
import '../providers/location_provider.dart';
import '../services/active_alert_controller.dart';
import '../theme/river_theme.dart';

class DangerProximityBanner extends ConsumerWidget {
  const DangerProximityBanner({super.key});

  // Distance thresholds per severity (km)
  static const _distBySeverity = {
    AlertSeverity.extreme: 120.0,
    AlertSeverity.critical: 120.0,
    AlertSeverity.danger: 80.0,
    AlertSeverity.rising: 60.0,
    AlertSeverity.normal: 0.0,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Riverpod 3.x: use asData?.value instead of valueOrNull
    final Position? position = ref.watch(userLocationProvider).asData?.value;
    if (position == null) return const SizedBox.shrink();

    final activeAlerts = ActiveAlertController.instance.alerts;
    if (activeAlerts.isEmpty) return const SizedBox.shrink();

    // Find the nearest alerting station within threshold
    AlertItem? nearest;
    double minDist = double.infinity;

    for (final alert in activeAlerts) {
      final threshold = _distBySeverity[alert.severity] ?? 80.0;
      if (threshold == 0.0) continue;

      // Look up lat/lon from gauge registry
      final gauge = kBiharGauges
          .where(
            (g) => g.station.toLowerCase() == alert.stationName.toLowerCase(),
          )
          .firstOrNull;
      if (gauge == null) continue;

      final d = _haversine(
        position.latitude,
        position.longitude,
        gauge.lat,
        gauge.lon,
      );
      if (d > threshold) continue;

      if (d < minDist) {
        minDist = d;
        nearest = alert;
      }
    }

    if (nearest == null) return const SizedBox.shrink();
    return _BannerWidget(alert: nearest, distKm: minDist);
  }

  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}

// ── Animated banner ───────────────────────────────────────────────────────────
class _BannerWidget extends StatefulWidget {
  final AlertItem alert;
  final double distKm;
  const _BannerWidget({required this.alert, required this.distKm});
  @override
  State<_BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<_BannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sev = widget.alert.severity;
    final baseColor = switch (sev) {
      AlertSeverity.extreme => const Color(0xFFD32F2F),
      AlertSeverity.critical => AppPalette.critical,
      AlertSeverity.danger => AppPalette.warning,
      AlertSeverity.rising => const Color(0xFF039BE5),
      AlertSeverity.normal => AppPalette.textGrey,
    };

    final ror = widget.alert.rateOfRiseMph ?? 0.0;
    final rorText =
        ror >= 0.5 ? ' · rising +${ror.toStringAsFixed(2)} m/h' : '';
    final sevLabel = switch (sev) {
      AlertSeverity.extreme => 'EXTREME FLOOD',
      AlertSeverity.critical => 'CRITICAL',
      AlertSeverity.danger => 'DANGER',
      AlertSeverity.rising => 'RAPID RISE',
      AlertSeverity.normal => '',
    };

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Color.lerp(
            baseColor, baseColor.withValues(alpha: 0.70), _anim.value),
        child: Row(
          children: [
            Icon(
              sev == AlertSeverity.rising
                  ? Icons.trending_up_rounded
                  : Icons.warning_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$sevLabel: ${widget.alert.stationName} '
                '(${widget.alert.district}) '
                '${widget.distKm.toStringAsFixed(0)} km away$rorText',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
