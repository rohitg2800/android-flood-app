// lib/services/flood_notification_service.dart  v1.0  (Step 6.3)
// Wraps flutter_local_notifications.
// pubspec.yaml must have: flutter_local_notifications: ^17.0.0
// AndroidManifest: POST_NOTIFICATIONS + SCHEDULE_EXACT_ALARM permissions.
library;

import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FloodNotificationService {
  FloodNotificationService.internal();
  static FloodNotificationService _instance = FloodNotificationService.internal();
  static FloodNotificationService get instance => _instance;

  // Test helpers — no-op in production
  // ignore: invalid_use_of_visible_for_testing_member
  static void testOverride(FloodNotificationService fake) => _instance = fake;
  static void clearOverride() => _instance = FloodNotificationService.internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _critChannel = AndroidNotificationChannel(
    'flood_critical',
    'Flood Critical Alerts',
    description: 'Fires when a Bihar station crosses CRITICAL threshold.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static const _warnChannel = AndroidNotificationChannel(
    'flood_warning',
    'Flood Warning Alerts',
    description: 'Fires when a Bihar station crosses WARNING threshold.',
    importance: Importance.high,
    playSound: true,
  );

  Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    final ap = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await ap?.createNotificationChannel(_critChannel);
    await ap?.createNotificationChannel(_warnChannel);
    _ready = true;
  }

  Future<void> showCriticalAlert({
    required int    id,
    required String city,
    required double level,
    required double dangerLevel,
  }) async {
    if (!_ready) await init();
    final pct = dangerLevel > 0
        ? (level / dangerLevel * 100).toStringAsFixed(0)
        : '--';
    await _plugin.show(
      id,
      '🚨 CRITICAL FLOOD — $city',
      'Level ${level.toStringAsFixed(2)} m ($pct% of danger). Evacuate immediately.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _critChannel.id,
          _critChannel.name,
          channelDescription: _critChannel.description,
          importance: Importance.max,
          priority:   Priority.max,
          color:      const Color(0xFFE53935),
          playSound:  true,
          enableVibration: true,
          styleInformation: BigTextStyleInformation(
            'Water level at ${level.toStringAsFixed(2)} m — $pct% of danger. '
            'Follow official CWC/NDRF advisories immediately.',
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> showWarningAlert({
    required int    id,
    required String city,
    required double level,
  }) async {
    if (!_ready) await init();
    await _plugin.show(
      id,
      '⚠️ Flood Warning — $city',
      'Level rising to ${level.toStringAsFixed(2)} m. Stay alert.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _warnChannel.id,
          _warnChannel.name,
          importance: Importance.high,
          priority:   Priority.high,
          color:      const Color(0xFFFB8C00),
          playSound:  true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
    );
  }
}
