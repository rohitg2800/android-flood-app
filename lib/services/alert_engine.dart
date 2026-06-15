// lib/services/alert_engine.dart  Step 3.3
// Upgraded alert engine:
//   • Deduplication via SharedPreferences hash (skip re-alert within 6h)
//   • Geofence check: only alert if user is within subscription's radius
//   • Custom threshold: honour subscription.customThresholdMetres if set
//   • breachOnlyMode: skip if predicted24h < threshold

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/flood_data.dart';
import '../models/alert_subscription.dart';

const _kDedupeKey  = 'alert_dedup_v1';
const _kDedupeHours = 6;

class AlertEngine {
  AlertEngine._();
  static final AlertEngine instance = AlertEngine._();

  final _notif = FlutterLocalNotificationsPlugin();
  bool _initialised = false;

  // ── Init ────────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialised) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings();
    await _notif.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialised = true;
  }

  // ── Main evaluation loop ────────────────────────────────────────────────
  /// Called with the latest gauge list + user's subscriptions.
  /// Fires a local notification for each subscription that:
  ///   1. Is not deduped within 6h
  ///   2. User is within the subscription radius  (or GPS unavailable)
  ///   3. Current level exceeds the subscription threshold (or danger level)
  ///   4. If breachOnlyMode — predicted24h must also exceed threshold
  Future<void> evaluate({
    required List<FloodData>           gauges,
    required List<AlertSubscription>   subscriptions,
    Position?                          userPosition,
  }) async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    final dedup = _loadDedup(prefs);

    for (final sub in subscriptions) {
      final gauge = gauges.where(
          (g) => g.stationId == sub.stationId).firstOrNull;
      if (gauge == null) continue;

      final threshold = sub.customThresholdMetres ?? gauge.dangerLevel;

      // ── (1) Threshold check
      if (gauge.currentLevel < threshold) continue;

      // ── (2) Breach-only mode
      if (sub.breachOnlyMode) {
        final peak24 = gauge.peakLevel72h ?? gauge.currentLevel;
        if (peak24 < threshold) continue;
      }

      // ── (3) Geofence check (skip if GPS unavailable — default fire)
      if (userPosition != null) {
        final dist = _haversineKm(
          userPosition.latitude, userPosition.longitude,
          gauge.lat ?? 0,         gauge.lon ?? 0,
        );
        if (dist > sub.notifyRadiusKm) continue;
      }

      // ── (4) Deduplication
      final hashKey = '${sub.stationId}|${gauge.riskLevel}|${_dayKey()}';
      if (dedup.contains(hashKey)) continue;
      dedup.add(hashKey);

      // ── Fire notification
      await _fire(
        id:      sub.stationId.hashCode.abs() % 100000,
        title:   '🚨 ${sub.cityName} — ${gauge.riskLevel.toUpperCase()}',
        body:    '${gauge.riverName ?? "River"} at '
                 '${gauge.currentLevel.toStringAsFixed(2)} m '
                 '(threshold ${threshold.toStringAsFixed(2)} m)',
        payload: sub.stationId,
      );
    }

    await _saveDedup(prefs, dedup);
  }

  // ── Notification dispatch ─────────────────────────────────────────────────
  Future<void> _fire({
    required int    id,
    required String title,
    required String body,
    String?         payload,
  }) async {
    const android = AndroidNotificationDetails(
      'flood_alerts',
      'Flood Alerts',
      channelDescription: 'Real-time flood level alerts',
      importance: Importance.max,
      priority:   Priority.high,
      color:      Color(0xFFE53935),
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    await _notif.show(
      id, title, body,
      const NotificationDetails(android: android, iOS: ios),
      payload: payload,
    );
  }

  // ── Dedup helpers ───────────────────────────────────────────────────────
  Set<String> _loadDedup(SharedPreferences prefs) {
    final raw = prefs.getString(_kDedupeKey);
    if (raw == null) return {};
    try {
      final List<dynamic> list = jsonDecode(raw);
      // Purge entries older than _kDedupeHours hours
      final now    = DateTime.now();
      final cutoff = now.subtract(const Duration(hours: _kDedupeHours));
      return list
          .cast<String>()
          .where((entry) {
            final parts = entry.split('|');
            if (parts.length < 3) return false;
            final day = parts.last;
            try {
              final dt = DateTime.parse(day);
              return dt.isAfter(cutoff);
            } catch (_) {
              return false;
            }
          })
          .toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveDedup(
      SharedPreferences prefs, Set<String> dedup) async {
    await prefs.setString(_kDedupeKey, jsonEncode(dedup.toList()));
  }

  /// Key = ISO 8601 date+hour, giving 1h granularity buckets.
  String _dayKey() {
    final now = DateTime.now();
    return '${now.toIso8601String().substring(0, 13)}'; // "2026-06-15T11"
  }

  // ── Haversine distance ─────────────────────────────────────────────────────
  double _haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
    const R    = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a    = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _rad(double deg) => deg * pi / 180;
}
