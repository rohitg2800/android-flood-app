// lib/services/alert_notification_bridge.dart  v2
// Fixed: _body() switch now covers all 14 AlertType values.
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'alert_engine.dart';

class _Topics {
  static const emergency = 'flood_emergency_topic';
  static const critical = 'flood_critical_topic';
  static const warning = 'flood_warning_topic';
  static const info = 'flood_info_topic';
}

class AlertNotificationBridge {
  AlertNotificationBridge._();
  static final AlertNotificationBridge instance = AlertNotificationBridge._();

  final FlutterLocalNotificationsPlugin _notif =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<FloodAlert>? _sub;
  bool _initialised = false;

  Future<void> init() async {
    if (_initialised) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _notif
        .initialize(const InitializationSettings(android: android, iOS: ios));
    _initialised = true;
  }

  void start(Stream<FloodAlert> alertStream) {
    _sub?.cancel();
    _sub = alertStream.listen(_onAlert);
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  Future<void> _onAlert(FloodAlert alert) async {
    await init();
    await _subscribeToTopic(alert.severity);
    await _notif.show(
      alert.id.hashCode.abs() % 100000,
      _title(alert),
      _body(alert),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId(alert.severity),
          'Flood Alerts',
          channelDescription: 'Real-time flood level alerts',
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
            presentAlert: true, presentSound: true),
      ),
    );
  }

  Future<void> _subscribeToTopic(AlertSeverity s) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(_severityTopic(s));
    } catch (_) {}
  }

  String _title(FloodAlert alert) {
    switch (alert.severity) {
      case AlertSeverity.emergency:
        return '\u{1F6A8} EMERGENCY — ${alert.stationName}';
      case AlertSeverity.critical:
        return '\u{1F534} CRITICAL — ${alert.stationName}';
      case AlertSeverity.warning:
        return '\u26A0\uFE0F WARNING — ${alert.stationName}';
      case AlertSeverity.info:
        return '\u2139\uFE0F WATCH — ${alert.stationName}';
    }
  }

  String _body(FloodAlert alert) {
    final cur = alert.currentLevel.toStringAsFixed(2);
    final thr = alert.thresholdLevel.toStringAsFixed(2);
    final dl = alert.dangerLevel.toStringAsFixed(2);
    final pct = (alert.pctOfDanger * 100).toStringAsFixed(0);
    final riv = alert.river;
    final sta = alert.stationName;

    switch (alert.type) {
      case AlertType.levelAboveHfl:
        return '$riv ($sta) has exceeded HFL. Current: $cur m (HFL: $thr m)';
      case AlertType.levelAboveDanger:
        return '$riv ($sta) is ABOVE DANGER LEVEL. Current: $cur m (Danger: $dl m, $pct%)';
      case AlertType.levelAboveWarning:
        return '$riv ($sta) crossed WARNING LEVEL. Current: $cur m (Threshold: $thr m)';
      case AlertType.rapidRise:
        final ror = alert.rateOfRiseMph != null
            ? '+${alert.rateOfRiseMph!.toStringAsFixed(2)} m/h'
            : 'rapid';
        return '$riv ($sta) is rising rapidly. Rate: $ror. Current: $cur m';
      case AlertType.forecastDanger24h:
        return '$riv ($sta) forecast to hit danger within 24h. Forecast: $cur m (Danger: $dl m)';
      case AlertType.forecastDanger48h:
        return '$riv ($sta) forecast to hit danger within 48h. Forecast: $cur m (Danger: $dl m)';
      case AlertType.rainfallExtreme:
        final rain = alert.rainfall24hMm != null
            ? '${alert.rainfall24hMm!.toStringAsFixed(1)} mm'
            : '>100 mm';
        return 'EXTREME RAINFALL near $sta. 24h accumulation: $rain';
      case AlertType.rainfallHeavy:
        final rain = alert.rainfall24hMm != null
            ? '${alert.rainfall24hMm!.toStringAsFixed(1)} mm'
            : '>64.5 mm';
        return 'HEAVY RAINFALL near $sta. 24h accumulation: $rain';
      case AlertType.upstreamCritical:
        return 'UPSTREAM CRITICAL on $riv. Multiple stations above danger. Downstream breach risk HIGH.';
      case AlertType.multiRiverAlert:
        return 'MULTI-RIVER CRISIS: 3+ rivers above warning. State emergency level.';
      case AlertType.breach:
        return '$riv has breached danger level. Current: $cur m ($pct% of DL $dl m)';
      case AlertType.approaching:
        return '$riv approaching danger. Current: $cur m ($pct% of DL $dl m)';
      case AlertType.forecast:
        return '$riv forecast to rise. Current: $cur m';
      case AlertType.custom:
        return '$riv crossed custom threshold ($thr m). Current: $cur m';
    }
  }

  static String _channelId(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.emergency:
        return 'flood_emergency';
      case AlertSeverity.critical:
        return 'flood_critical';
      case AlertSeverity.warning:
        return 'flood_warning';
      case AlertSeverity.info:
        return 'flood_info';
    }
  }

  static String _severityTopic(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.emergency:
        return _Topics.emergency;
      case AlertSeverity.critical:
        return _Topics.critical;
      case AlertSeverity.warning:
        return _Topics.warning;
      case AlertSeverity.info:
        return _Topics.info;
    }
  }
}
