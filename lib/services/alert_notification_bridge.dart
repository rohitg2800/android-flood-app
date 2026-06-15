// lib/services/alert_notification_bridge.dart
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'alert_engine.dart';
import '../constants/fcm_topics.dart';

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
    const ios     = DarwinInitializationSettings();
    await _notif.initialize(
        const InitializationSettings(android: android, iOS: ios));
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
          importance:    Importance.max,
          priority:      Priority.high,
          enableVibration: true,
          icon: _icon(alert.severity),
        ),
        iOS: const DarwinNotificationDetails(
            presentAlert: true, presentSound: true),
      ),
    );
  }

  Future<void> _subscribeToTopic(AlertSeverity s) async {
    try {
      await FirebaseMessaging.instance
          .subscribeToTopic(_severityTopic(s));
    } catch (_) {}
  }

  String _title(FloodAlert alert) {
    switch (alert.severity) {
      case AlertSeverity.emergency:
        return '\u{1F6A8} EMERGENCY — ${alert.stationName}';
      case AlertSeverity.critical:
        return '\u{1F534} CRITICAL — ${alert.stationName}';
      case AlertSeverity.warning:
        return '\u{26A0}\uFE0F WARNING — ${alert.stationName}';
      case AlertSeverity.info:
        return '\u2139\uFE0F WATCH — ${alert.stationName}';
    }
  }

  String _body(FloodAlert alert) {
    final pct = (alert.pctOfDanger * 100).toStringAsFixed(0);
    switch (alert.type) {
      case AlertType.breach:
        return '${alert.river} has breached danger level. '
            'Current: ${alert.currentLevel.toStringAsFixed(2)} m '
            '($pct% of DL ${alert.dangerLevel.toStringAsFixed(2)} m)';
      case AlertType.approaching:
        return '${alert.river} approaching danger. '
            'Current: ${alert.currentLevel.toStringAsFixed(2)} m '
            '($pct% of DL ${alert.dangerLevel.toStringAsFixed(2)} m)';
      case AlertType.forecast:
        return '${alert.river} forecast to rise. '
            'Current: ${alert.currentLevel.toStringAsFixed(2)} m';
      case AlertType.custom:
        return '${alert.river} crossed custom threshold '
            '(${alert.thresholdLevel.toStringAsFixed(2)} m). '
            'Current: ${alert.currentLevel.toStringAsFixed(2)} m';
    }
  }

  static String _icon(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.emergency: return '\u{1F6A8}';
      case AlertSeverity.critical:  return '\u{1F534}';
      case AlertSeverity.warning:   return '\u26A0\uFE0F';
      case AlertSeverity.info:      return '\u2139\uFE0F';
    }
  }

  static String _channelId(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.emergency: return 'flood_emergency';
      case AlertSeverity.critical:  return 'flood_critical';
      case AlertSeverity.warning:   return 'flood_warning';
      case AlertSeverity.info:      return 'flood_info';
    }
  }

  static String _severityTopic(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.emergency: return FcmTopics.emergency;
      case AlertSeverity.critical:  return FcmTopics.critical;
      case AlertSeverity.warning:   return FcmTopics.warning;
      case AlertSeverity.info:      return FcmTopics.info;
    }
  }
}
