// lib/providers/notification_watcher_provider.dart  v2.0  (Step 6.3 fix)
// Uses Notifier<void> so state mutations stay within the same provider —
// zero cross-provider writes during build, satisfying Riverpod's assert.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bihar_prediction_provider.dart';
import '../services/flood_notification_service.dart';

class _NotificationWatcherNotifier extends Notifier<void> {
  final _firedCritical = <String>{};
  final _firedWarning  = <String>{};

  @override
  void build() {
    final preds = ref.watch(biharBulkPredictionsProvider);
    final svc   = FloodNotificationService.instance;

    for (final pred in preds) {
      final key = pred.station;

      // Reset fired-sets when level returns to normal so alerts re-arm
      if (pred.severity == 'INFO' || pred.severity == 'NORMAL') {
        _firedCritical.remove(key);
        _firedWarning.remove(key);
        continue;
      }

      if (pred.severity == 'CRITICAL' && _firedCritical.add(key)) {
        svc.showCriticalAlert(
          id:          key.hashCode.abs() % 100000,
          city:        pred.station.split(' (').first,
          level:       pred.currentLevel,
          dangerLevel: pred.dangerLevel,
        );
      } else if (pred.severity == 'SEVERE' && _firedWarning.add(key)) {
        svc.showWarningAlert(
          id:    (key.hashCode.abs() % 100000) + 100000,
          city:  pred.station.split(' (').first,
          level: pred.currentLevel,
        );
      }
    }
  }
}

/// Watch this from your app root to activate flood notifications.
final notificationWatcherProvider =
    NotifierProvider<_NotificationWatcherNotifier, void>(
  _NotificationWatcherNotifier.new,
);
