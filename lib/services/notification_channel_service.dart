// lib/services/notification_channel_service.dart
// Creates Android notification channels on first launch.

import 'dart:typed_data';
import 'package:flutter/painting.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationChannelService {
  NotificationChannelService._();
  static final instance = NotificationChannelService._();

  static const _channels = [
    _ChannelDef(
      id: 'flood_emergency',
      name: 'Emergency Flood Alerts',
      description: 'Immediate life-safety flood emergencies',
      importance: Importance.max,
      ledColorHex: 0xFFFF1744,
    ),
    _ChannelDef(
      id: 'flood_critical',
      name: 'Critical Flood Alerts',
      description: 'Danger-level threshold crossings',
      importance: Importance.high,
      ledColorHex: 0xFFFF6D00,
    ),
    _ChannelDef(
      id: 'flood_warning',
      name: 'Flood Warnings',
      description: 'Warning-level threshold crossings',
      importance: Importance.high,
      ledColorHex: 0xFFFFD600,
    ),
    _ChannelDef(
      id: 'flood_info',
      name: 'Flood Advisories',
      description: 'Informational flood advisories',
      importance: Importance.defaultImportance,
      ledColorHex: 0xFF00E5FF,
    ),
  ];

  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> createChannels() async {
    for (final ch in _channels) {
      final ledColor = Color(ch.ledColorHex);
      final details = AndroidNotificationChannel(
        ch.id,
        ch.name,
        description: ch.description,
        importance: ch.importance,
        ledColor: ledColor,
        enableLights: true,
        playSound: true,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(details);
    }
  }

  /// Alias kept for call-sites that use .init() instead of .createChannels()
  Future<void> init() => createChannels();
}

class _ChannelDef {
  final String id;
  final String name;
  final String description;
  final Importance importance;
  final int ledColorHex;
  const _ChannelDef({
    required this.id,
    required this.name,
    required this.description,
    required this.importance,
    required this.ledColorHex,
  });
}
