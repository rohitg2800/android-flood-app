// lib/widgets/watch_button.dart  Step 3.6
// Reusable bell-icon button that subscribes / unsubscribes a station.
// Drop into CityDetailScreen AppBar and _StationSheet header.
//
// Usage:
//   WatchButton(stationId: data.stationId, cityName: data.city,
//               riverName: data.riverName ?? '')

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/alert_subscription.dart';
import '../providers/subscription_provider.dart';
import '../theme/river_theme.dart';

class WatchButton extends ConsumerWidget {
  final String stationId;
  final String cityName;
  final String riverName;

  const WatchButton({
    super.key,
    required this.stationId,
    required this.cityName,
    required this.riverName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watched = ref.watch(isWatchedProvider(stationId));
    final t = RiverColors.of(context);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: IconButton(
        key: ValueKey(watched),
        tooltip: watched ? 'Stop watching' : 'Watch this station',
        icon: Icon(
          watched
              ? Icons.notifications_active_rounded
              : Icons.notifications_none_rounded,
          color: watched ? AppPalette.gold : t.textSecondary,
        ),
        onPressed: () => _toggle(context, ref, watched),
      ),
    );
  }

  void _toggle(BuildContext context, WidgetRef ref, bool currentlyWatched) {
    final notifier = ref.read(subscriptionProvider.notifier);
    if (currentlyWatched) {
      notifier.unsubscribe(stationId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stopped watching $cityName'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      notifier.subscribe(AlertSubscription(
        stationId: stationId,
        cityName: cityName,
        riverName: riverName,
        createdAt: DateTime.now(),
      ));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔔 Now watching $cityName'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
