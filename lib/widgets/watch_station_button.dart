// lib/widgets/watch_station_button.dart  v2
// Fixed:
//   AlertSubscription requires riverName (was missing)
//   radiusKm param → notifyRadiusKm
//   stationId/cityName/dangerLevel/warningLevel are now widget fields (no change)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/subscription_provider.dart';
import '../models/alert_subscription.dart';
import '../screens/alert_settings_screen.dart';
import '../theme/river_theme.dart';

class WatchStationButton extends ConsumerStatefulWidget {
  final String stationId;
  final String cityName;
  final String riverName;
  final double dangerLevel;
  final double warningLevel;

  const WatchStationButton({
    super.key,
    required this.stationId,
    required this.cityName,
    required this.riverName,
    required this.dangerLevel,
    required this.warningLevel,
  });

  @override
  ConsumerState<WatchStationButton> createState() => _WatchStationButtonState();
}

class _WatchStationButtonState extends ConsumerState<WatchStationButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _scale = Tween<double>(begin: 1.0, end: 1.3)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final watching = ref.watch(isWatchedProvider(widget.stationId));
    final t = RiverColors.of(context);

    return AnimatedBuilder(
      animation: _scale,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: IconButton(
          tooltip: watching ? 'Alert settings' : 'Watch this station',
          icon: Icon(
            watching
                ? Icons.notifications_active_rounded
                : Icons.notifications_none_rounded,
            color: watching ? t.accent : t.textSecondary,
          ),
          onPressed: () => _onTap(context, watching),
        ),
      ),
    );
  }

  Future<void> _onTap(BuildContext ctx, bool watching) async {
    _ac.forward().then((_) => _ac.reverse());

    if (!watching) {
      await ref.read(subscriptionProvider.notifier).subscribe(
            AlertSubscription(
              stationId: widget.stationId,
              cityName: widget.cityName,
              riverName: widget.riverName, // was missing
              notifyRadiusKm: 50.0, // correct field name
              createdAt: DateTime.now(),
            ),
          );
    }

    if (ctx.mounted) {
      await Navigator.of(ctx).push(MaterialPageRoute(
        builder: (_) => AlertSettingsScreen(
          stationId: widget.stationId,
          cityName: widget.cityName,
          dangerLevel: widget.dangerLevel,
          warningLevel: widget.warningLevel,
        ),
      ));
    }
  }
}
