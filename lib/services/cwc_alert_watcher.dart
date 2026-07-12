// lib/services/cwc_alert_watcher.dart
// Polls cwcStationsProvider every 15 min.
// Fires a local notification when ANY station crosses danger or warning.
// Deduplicates: same station won't re-notify within 1 hour.
// Also subscribes the device to FCM topic flood_cwc_<site> so
// server-side pushes arrive even when the app is killed.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/cwc_provider.dart';
import '../services/befiqr_cwc_service.dart';
import 'fcm_service.dart';

class CwcAlertWatcher {
  static final CwcAlertWatcher _i = CwcAlertWatcher._();
  factory CwcAlertWatcher() => _i;
  static CwcAlertWatcher get instance => _i;
  CwcAlertWatcher._();

  static const _pollInterval = Duration(minutes: 15);
  static const _cooldownPeriod = Duration(hours: 1);

  // When did we last notify for each site?
  final Map<String, DateTime> _lastNotified = {};

  ProviderSubscription<AsyncValue<List<CwcStation>>>? _sub;
  Timer? _pollTimer;
  bool _started = false;

  // ── Notification channels ─────────────────────────────────────────────────
  static const _alertChannelId = 'cwc_flood_alerts';
  static const _alertChannelName = 'CWC Flood Alerts';
  static const _newsChannelId = 'flood_news';
  static const _newsChannelName = 'Flood News';

  final FlutterLocalNotificationsPlugin _notif =
      FlutterLocalNotificationsPlugin();

  // ── Start ─────────────────────────────────────────────────────────────────

  Future<void> start(ProviderContainer container) async {
    if (_started) return;
    _started = true;

    await _initChannels();

    // Immediate first check
    await _check(container);

    // Poll every 15 min
    _pollTimer = Timer.periodic(_pollInterval, (_) => _check(container));

    // Also react instantly when the Riverpod provider refreshes
    _sub = container.listen<AsyncValue<List<CwcStation>>>(
      cwcStationsProvider,
      (_, next) => next.whenData((stations) => _evaluate(stations)),
      fireImmediately: false,
    );
  }

  void dispose() {
    _pollTimer?.cancel();
    _sub?.close();
    _started = false;
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _check(ProviderContainer container) async {
    try {
      final stations = await container.read(cwcStationsProvider.future);
      _evaluate(stations);
    } catch (e) {
      if (kDebugMode) debugPrint('[CwcAlertWatcher] fetch error: $e');
    }
  }

  void _evaluate(List<CwcStation> stations) {
    for (final s in stations) {
      if (!s.isDanger && !s.isWarning) continue;
      if (_isCoolingDown(s.site)) continue;

      _notify(s);
      _lastNotified[s.site] = DateTime.now();
    }
  }

  bool _isCoolingDown(String site) {
    final last = _lastNotified[site];
    if (last == null) return false;
    return DateTime.now().difference(last) < _cooldownPeriod;
  }

  Future<void> _notify(CwcStation s) async {
    final isCrit = s.isDanger;
    final riskScore = BefiqrCwcService.riskScore(s);
    final title =
        isCrit ? '🚨 DANGER ALERT — ${s.site}' : '⚠️ WARNING — ${s.site}';
    final body = '${s.river} · Level ${s.currentLevel.toStringAsFixed(2)} m  '
        '(danger ${s.dangerLevel.toStringAsFixed(2)} m)  '
        '· Risk ${riskScore.toStringAsFixed(0)}%';

    try {
      await _notif.show(
        s.site.hashCode,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _alertChannelId,
            _alertChannelName,
            channelDescription: 'Real-time CWC Bihar station flood alerts',
            importance: isCrit ? Importance.max : Importance.high,
            priority: isCrit ? Priority.max : Priority.high,
            playSound: true,
            enableVibration: true,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
              presentAlert: true, presentSound: true),
        ),
      );

      // Subscribe device to site-specific FCM topic
      final topic = 'flood_cwc_${s.site}'
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
      await FcmService.instance.subscribeToTopic(topic);

      if (kDebugMode) debugPrint('[CwcAlertWatcher] notified: $title');
    } catch (e) {
      if (kDebugMode) debugPrint('[CwcAlertWatcher] notify error: $e');
    }
  }

  // ── News notification (called from NewsFeedScreen on new articles) ─────────

  Future<void> showNewsNotification({
    required String headline,
    required String source,
  }) async {
    try {
      await _notif.show(
        headline.hashCode,
        '📰 Flood News',
        '$headline — $source',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _newsChannelId,
            _newsChannelName,
            channelDescription: 'Flood-related news headlines',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            playSound: false,
          ),
          iOS: DarwinNotificationDetails(presentAlert: true),
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[CwcAlertWatcher] news notify error: $e');
    }
  }

  // ── Channel init ──────────────────────────────────────────────────────────

  Future<void> _initChannels() async {
    await _notif.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    final android = _notif.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _alertChannelId,
        _alertChannelName,
        description: 'Real-time CWC Bihar station flood alerts',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _newsChannelId,
        _newsChannelName,
        description: 'Flood-related news headlines',
        importance: Importance.defaultImportance,
        playSound: false,
      ),
    );
  }
}
