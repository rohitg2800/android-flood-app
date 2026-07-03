// lib/services/notification_handler.dart
// OpsFlood — Module 13: Push Notification Deep-Link Handler
//
// Handles FCM messages in all 3 states:
//   foreground   → shows in-app SnackBar/banner + routes on tap
//   background   → on notification tap, routes when app resumes
//   terminated   → reads initial message on cold start and routes
//
// Add to pubspec.yaml:
//   firebase_messaging: ^15.0.0
//   flutter_local_notifications: ^17.0.0
//
// Call NotificationHandler.init(router) once in main() after Firebase.init.

import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ---------------------------------------------------------------------------
// Background handler (top-level, outside any class)
// ---------------------------------------------------------------------------

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage msg) async {
  // Firebase is already initialised by the system before this runs.
  debugPrint('[FCM-bg] ${msg.messageId}: ${msg.notification?.title}');
}

// ---------------------------------------------------------------------------
// Deep-link route resolver
// ---------------------------------------------------------------------------

class _RouteResolver {
  static String resolve(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';
    final target = data['target'] as String? ?? '';
    return switch (type) {
      'alert' => '/shell?tab=2', // Alerts tab
      'station' => '/station/$target', // CWC station detail
      'evacuation' => '/evacuation', // Evacuation routes
      'news' => '/shell?tab=3', // News tab
      'sos' => '/sos', // SOS screen
      _ => '/shell', // Fallback → dashboard
    };
  }
}

// ---------------------------------------------------------------------------
// NotificationHandler
// ---------------------------------------------------------------------------

class NotificationHandler {
  NotificationHandler._();

  static final _localNotifs = FlutterLocalNotificationsPlugin();
  static GlobalKey<NavigatorState>? _navigatorKey;

  static const _channel = AndroidNotificationChannel(
    'opsflood_alerts',
    'OpsFlood Alerts',
    description: 'Flood alerts and emergency notifications',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  // --------------------------------------------------
  // Init — call from main() after Firebase.initializeApp()
  // --------------------------------------------------
  static Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;

    // 1. Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 2. Android notification channel
    await _localNotifs
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 3. Local notifications init
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true),
    );
    await _localNotifs.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) {
        final payload = resp.payload;
        if (payload != null) {
          _navigate(jsonDecode(payload) as Map<String, dynamic>);
        }
      },
    );

    // 4. Request FCM permission
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      carPlay: false,
      criticalAlert: true,
    );

    // 5. FCM foreground presentation (iOS)
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 6. Foreground message handler
    FirebaseMessaging.onMessage.listen(_onForeground);

    // 7. Background tap (app was in background, user taps notif)
    FirebaseMessaging.onMessageOpenedApp.listen(_onTap);

    // 8. Terminated state: app opened via notification
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _onTap(initial);

    // 9. Log FCM token (remove in prod or send to Firestore)
    final token = await FirebaseMessaging.instance.getToken();
    debugPrint('[FCM] token: $token');

    // Refresh token listener
    FirebaseMessaging.instance.onTokenRefresh.listen((t) {
      debugPrint('[FCM] token refreshed: $t');
      // TODO: save to Firestore: users/{uid}/fcmToken
    });
  }

  // --------------------------------------------------
  // Foreground: show local notification
  // --------------------------------------------------
  static Future<void> _onForeground(RemoteMessage msg) async {
    final n = msg.notification;
    if (n == null) return;
    debugPrint('[FCM-fg] ${n.title}: ${n.body}');
    await _localNotifs.show(
      msg.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF0D47A1),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(msg.data),
    );
  }

  // --------------------------------------------------
  // Tap handler — navigate to deep-link route
  // --------------------------------------------------
  static void _onTap(RemoteMessage msg) {
    final route = _RouteResolver.resolve(msg.data);
    debugPrint('[FCM] navigating to $route');
    _navigatorKey?.currentState?.pushNamed(route);
  }

  // --------------------------------------------------
  // Manual navigate (call from anywhere)
  // --------------------------------------------------
  static void _navigate(Map<String, dynamic> data) {
    final route = _RouteResolver.resolve(data);
    _navigatorKey?.currentState?.pushNamed(route);
  }

  // --------------------------------------------------
  // Subscribe / unsubscribe to district topics
  // --------------------------------------------------
  static Future<void> subscribeDistrict(String district) async {
    final topic = 'district_${district.toLowerCase().replaceAll(' ', '_')}';
    await FirebaseMessaging.instance.subscribeToTopic(topic);
    debugPrint('[FCM] subscribed: $topic');
  }

  static Future<void> unsubscribeDistrict(String district) async {
    final topic = 'district_${district.toLowerCase().replaceAll(' ', '_')}';
    await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    debugPrint('[FCM] unsubscribed: $topic');
  }

  static Future<void> subscribeToSeverity(String level) async {
    // e.g. level = 'emergency' | 'danger' | 'warning'
    await FirebaseMessaging.instance.subscribeToTopic('severity_$level');
  }
}
