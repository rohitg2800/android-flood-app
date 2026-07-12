// lib/providers/notification_watcher_provider.dart
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bihar_prediction_provider.dart';
import '../services/flood_notification_service.dart';

class _NotificationWatcherNotifier extends Notifier<void> {
  final _firedCritical = <String>{};
  final _firedWarning = <String>{};

  @override
  void build() {
    final preds = ref.watch(biharBulkPredictionsProvider);
    final svc = FloodNotificationService.instance;

    for (final pred in preds) {
      final key = pred.station;
      final city = pred.station.split(' (').first;

      if (pred.severity == 'INFO' || pred.severity == 'NORMAL') {
        _firedCritical.remove(key);
        _firedWarning.remove(key);
        continue;
      }

      if (pred.severity == 'CRITICAL') {
        _firedWarning.remove(key);
        if (_firedCritical.add(key)) {
          svc.showCriticalAlert(
            id: key.hashCode.abs() % 100000,
            city: city,
            level: pred.currentLevel,
            dangerLevel: pred.dangerLevel,
          );
        }
        continue;
      }

      if (pred.severity == 'SEVERE') {
        _firedCritical.remove(key);
        if (_firedWarning.add(key)) {
          svc.showWarningAlert(
            id: (key.hashCode.abs() % 100000) + 100000,
            city: city,
            level: pred.currentLevel,
          );
        }
        continue;
      }
    }
  }
}

final notificationWatcherProvider =
    NotifierProvider<_NotificationWatcherNotifier, void>(
      _NotificationWatcherNotifier.new,
    );