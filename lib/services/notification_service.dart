// lib/services/notification_service.dart
// Singleton wrapper around flutter_local_notifications.
// Provides: NotificationService.instance.showFloodAlert(...)

import 'dart:typed_data';
import 'package:flutter/painting.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialised = false;

  Future<void> init() async {
    if (_initialised) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin
        .initialize(const InitializationSettings(android: android, iOS: ios));
    _initialised = true;
  }

  Future<void> showFloodAlert({
    required int id,
    required String title,
    required String body,
    required String channelId,
    String? payload,
  }) async {
    await init();
    final androidDetails = AndroidNotificationDetails(
      channelId,
      _channelName(channelId),
      channelDescription: 'OpsFlood flood alerts',
      importance: Importance.max,
      priority: Priority.high,
      color: _channelColor(channelId),
      ledColor: _channelColor(channelId),
      ledOnMs: 500,
      ledOffMs: 500,
      enableLights: true,
    );
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  static String _channelName(String id) {
    switch (id) {
      case 'flood_emergency':
        return 'Emergency Flood Alerts';
      case 'flood_critical':
        return 'Critical Flood Alerts';
      case 'flood_warning':
        return 'Flood Warnings';
      default:
        return 'Flood Advisories';
    }
  }

  static Color _channelColor(String id) {
    switch (id) {
      case 'flood_emergency':
        return const Color(0xFFFF1744);
      case 'flood_critical':
        return const Color(0xFFFF6D00);
      case 'flood_warning':
        return const Color(0xFFFFD600);
      default:
        return const Color(0xFF00E5FF);
    }
  }
}
