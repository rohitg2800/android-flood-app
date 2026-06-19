// lib/services/fcm_service.dart
//
// OpsFlood — FcmService
// Supports both FcmService.instance (legacy) and FcmService() factory.
//
// Topic naming: flood_alert_<State>_<City>  e.g. flood_alert_Bihar_Patna
// State topic:  flood_state_<State>
// Global:       flood_alerts_india
library;

import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) debugPrint('[FCM] Background: ${message.notification?.title}');
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );
  final title = message.notification?.title ?? 'Flood Alert';
  final body  = message.notification?.body  ?? '';
  await plugin.show(
    message.hashCode, title, body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'flood_alerts', 'Flood Alerts',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    ),
  );
}

class FcmService {
  static final FcmService _instance = FcmService._();
  factory FcmService() => _instance;
  static FcmService get instance => _instance;
  FcmService._();

  final FirebaseMessaging               _messaging  = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotif = FlutterLocalNotificationsPlugin();

  String?      fcmToken;
  bool         _initialised = false;
  final Set<String> _subscribed = {};

  // ── Init ───────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final settings = await _messaging.requestPermission(
      alert: true, badge: true, sound: true,
    );
    if (kDebugMode) debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    await _localNotif.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'flood_alerts', 'Flood Alerts',
            description: 'Live flood risk alerts for Indian cities',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );

    try {
      fcmToken = await _messaging.getToken();
      if (kDebugMode) debugPrint('[FCM] token: $fcmToken');
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] getToken failed: $e');
    }

    await subscribeToTopic('flood_alerts_india');

    FirebaseMessaging.onMessage.listen(_handleForeground);
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      if (kDebugMode) debugPrint('[FCM] opened: ${msg.notification?.title}');
    });
  }

  // ── Topic management ─────────────────────────────────────────────────────

  Future<void> subscribeToTopic(String topic) async {
    final clean = _cleanTopic(topic);
    if (_subscribed.contains(clean)) return;
    try {
      await _messaging.subscribeToTopic(clean);
      _subscribed.add(clean);
      if (kDebugMode) debugPrint('[FCM] subscribed: $clean');
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] subscribe error ($clean): $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    final clean = _cleanTopic(topic);
    if (!_subscribed.contains(clean)) return;
    try {
      await _messaging.unsubscribeFromTopic(clean);
      _subscribed.remove(clean);
      if (kDebugMode) debugPrint('[FCM] unsubscribed: $clean');
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] unsubscribe error ($clean): $e');
    }
  }

  Future<void> subscribeToState(String state) =>
      subscribeToTopic('flood_state_${state.replaceAll(' ', '_')}');

  Future<void> unsubscribeFromState(String state) =>
      unsubscribeFromTopic('flood_state_${state.replaceAll(' ', '_')}');

  // ── showAlertNotification ───────────────────────────────────────────────────
  //
  // Called by ThresholdAlertService._notify() with discharge-based data.

  Future<void> showAlertNotification({
    required String cityName,
    required String state,
    required String river,
    required String severity,          // 'EXTREME' | 'DANGER' | 'WARNING'
    required double currentLevel,      // m³/s
    required double dangerLevel,       // m³/s
    String? message,
  }) async {
    final isCrit = severity == 'EXTREME' || severity == 'DANGER';
    final title  = '$severity FLOOD ALERT — $cityName, $state';
    final body   = message ??
        '$river discharge at ${currentLevel.toStringAsFixed(0)} m³/s '
        '(danger: ${dangerLevel.toStringAsFixed(0)} m³/s)';

    final android = AndroidNotificationDetails(
      'flood_alerts',
      'Flood Alerts',
      channelDescription: 'Live flood risk alerts for Indian cities',
      importance: isCrit ? Importance.max  : Importance.high,
      priority:   isCrit ? Priority.max    : Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );
    const ios = DarwinNotificationDetails(presentAlert: true, presentSound: true);

    await _localNotif.show(
      '$cityName$state'.hashCode,
      title,
      body,
      NotificationDetails(android: android, iOS: ios),
    );

    // Also subscribe device to the city FCM topic so future server pushes
    // are received even when app is closed.
    final topic = 'flood_alert_${state}_$cityName'
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    await subscribeToTopic(topic);
  }

  // ── Foreground handler ────────────────────────────────────────────────────

  Future<void> _handleForeground(RemoteMessage message) async {
    if (kDebugMode) debugPrint('[FCM] Foreground: ${message.notification?.title}');
    final notif = message.notification;
    if (notif == null) return;
    await _localNotif.show(
      message.hashCode,
      notif.title ?? 'Flood Alert',
      notif.body  ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'flood_alerts', 'Flood Alerts',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _cleanTopic(String raw) {
    final s = raw.replaceAll(' ', '_')
                 .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    return s.length > 900 ? s.substring(0, 900) : s;
  }

  bool isSubscribed(String topic) => _subscribed.contains(_cleanTopic(topic));
  Set<String> get subscribedTopics => Set.unmodifiable(_subscribed);
}
