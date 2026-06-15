// lib/services/alert_engine.dart  v2.0 — Step 3.3
// Upgraded alert engine:
//   • Deduplication — skip if same alert fired within 6h
//   • Geofence — skip if user GPS is outside subscriptionRadiusKm
//   • Custom threshold — cross-refs SubscriptionNotifier
//   • Default threshold fallback — uses warning/dangerLevel from FloodData

import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/flood_data.dart';
import '../models/alert_subscription.dart';

const _kDedupKey    = 'alert_dedup_v2';
const _kDedupWindow = Duration(hours: 6);

class AlertEngine {
  AlertEngine._();
  static final AlertEngine instance = AlertEngine._();

  final FlutterLocalNotificationsPlugin _notif =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;

  Future<void> init() async {
    if (_initialised) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings();
    await _notif.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialised = true;
  }

  /// Main entry point. Call with fresh FloodData list + current subscriptions.
  Future<void> evaluate(
    List<FloodData>          gauges,
    List<AlertSubscription>  subscriptions,
  ) async {
    await init();
    Position? userPos = await _getUserPosition();
    final prefs       = await SharedPreferences.getInstance();
    final dedupMap    = _loadDedup(prefs);

    for (final gauge in gauges) {
      final sub = subscriptions
          .where((s) => s.stationId == gauge.stationId)
          .firstOrNull;

      // ─ Determine effective threshold ───────────────────────────────────
      double threshold;
      if (sub?.customThresholdLevel != null) {
        threshold = sub!.customThresholdLevel!;
      } else {
        // Default: fire at warning level for watched stations, danger for all
        threshold = sub != null
            ? (gauge.warningLevel ?? gauge.dangerLevel)
            : gauge.dangerLevel;
      }

      final isBreach = gauge.currentLevel >= threshold;
      if (!isBreach) continue;

      // ─ notifyOnBreachOnly gate ──────────────────────────────────────
      if (sub != null && sub.notifyOnBreachOnly) {
        final willBreach = gauge.willBreachDanger ?? false;
        if (!willBreach) continue;
      }

      // ─ Deduplication ─────────────────────────────────────────────────
      final key = '${gauge.stationId}_${gauge.riskLevel}_${DateTime.now().day}';
      if (_isDedupBlocked(dedupMap, key)) continue;

      // ─ Geofence check ─────────────────────────────────────────────────
      if (userPos != null && gauge.latitude != null && gauge.longitude != null) {
        final radiusKm = sub?.radiusKm ?? 50.0;
        if (radiusKm > 0) {
          final distM = Geolocator.distanceBetween(
            userPos.latitude, userPos.longitude,
            gauge.latitude!, gauge.longitude!,
          );
          if (distM > radiusKm * 1000) continue;
        }
      }

      // ─ Fire notification ─────────────────────────────────────────────────
      await _fireNotification(gauge);
      _markDedup(dedupMap, key);
    }

    await _saveDedup(prefs, dedupMap);
  }

  Future<Position?> _getUserPosition() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _fireNotification(FloodData gauge) async {
    final id = gauge.stationId.hashCode.abs() % 100000;
    await _notif.show(
      id,
      '🚨 ${gauge.city} — ${gauge.riskLevel.toUpperCase()}',
      'Level: ${gauge.currentLevel.toStringAsFixed(2)} m '
      '(danger: ${gauge.dangerLevel.toStringAsFixed(2)} m)',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'flood_alerts', 'Flood Alerts',
          channelDescription: 'Critical flood level alerts',
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
    );
  }

  // ── Dedup helpers ────────────────────────────────────────────────────────
  Map<String, int> _loadDedup(SharedPreferences prefs) {
    final raw = prefs.getString(_kDedupKey);
    if (raw == null) return {};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k, v as int));
    } catch (_) {
      return {};
    }
  }

  bool _isDedupBlocked(Map<String, int> map, String key) {
    final ts = map[key];
    if (ts == null) return false;
    final fired = DateTime.fromMillisecondsSinceEpoch(ts);
    return DateTime.now().difference(fired) < _kDedupWindow;
  }

  void _markDedup(Map<String, int> map, String key) {
    map[key] = DateTime.now().millisecondsSinceEpoch;
    // Prune entries older than 24h to keep prefs small
    map.removeWhere((_, ts) {
      final fired = DateTime.fromMillisecondsSinceEpoch(ts);
      return DateTime.now().difference(fired) > const Duration(hours: 24);
    });
  }

  Future<void> _saveDedup(
      SharedPreferences prefs, Map<String, int> map) async {
    await prefs.setString(_kDedupKey, jsonEncode(map));
  }
}
