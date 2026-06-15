// lib/services/alert_engine.dart  v3.0
//
// v3.0 (15 Jun 2026) — P0: add FloodAlert model + AlertSeverity + evaluateMerged
//
//   PROBLEM: FloodAlert, AlertSeverity, AlertSeverityExt, AlertType, AlertTypeExt,
//   and AlertEngine.evaluateMerged() were referenced/exported by
//   alerts_provider.dart and alert_provider.dart but were never defined anywhere.
//   The app compiled (dynamic analysis missed it) but crashed at runtime the
//   moment alertsProvider was first read.
//
//   FIX:
//     • FloodAlert — immutable value class; all fields typed (no dynamic).
//       thresholdLevel = the effective level that triggered this alert
//       (may be warningLevel, dangerLevel, or customThreshold).
//     • AlertSeverity + .priority extension for deterministic sort order.
//     • AlertType enum (BREACH, APPROACHING, FORECAST, CUSTOM).
//     • AlertEngine.evaluateMerged(List<RiverStation>) — synchronous,
//       Riverpod-Provider-safe. Produces one FloodAlert per breaching station.
//       Sort: severity.priority DESC then issuedAt DESC (same as alert_provider).
//     • Async evaluate() (push-notification path) retained unchanged from v2.0.

library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/flood_data.dart';
import '../models/river_station.dart';
import '../models/alert_subscription.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AlertSeverity
// ─────────────────────────────────────────────────────────────────────────────
enum AlertSeverity { info, warning, critical, emergency }

extension AlertSeverityExt on AlertSeverity {
  /// Higher = shown first in sorted lists.
  int get priority {
    switch (this) {
      case AlertSeverity.emergency: return 4;
      case AlertSeverity.critical:  return 3;
      case AlertSeverity.warning:   return 2;
      case AlertSeverity.info:      return 1;
    }
  }

  String get label {
    switch (this) {
      case AlertSeverity.emergency: return 'EMERGENCY';
      case AlertSeverity.critical:  return 'CRITICAL';
      case AlertSeverity.warning:   return 'WARNING';
      case AlertSeverity.info:      return 'INFO';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AlertType
// ─────────────────────────────────────────────────────────────────────────────
enum AlertType { breach, approaching, forecast, custom }

extension AlertTypeExt on AlertType {
  String get label {
    switch (this) {
      case AlertType.breach:      return 'BREACH';
      case AlertType.approaching: return 'APPROACHING';
      case AlertType.forecast:    return 'FORECAST';
      case AlertType.custom:      return 'CUSTOM';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FloodAlert  — immutable value class (no dynamic fields)
// ─────────────────────────────────────────────────────────────────────────────
class FloodAlert {
  final String        id;             // stationName_severity_dayOfYear
  final String        stationName;    // e.g. "Birpur (CWC)"
  final String        title;          // e.g. "Birpur — CRITICAL"
  final String        river;          // e.g. "Kosi"
  final String        district;       // e.g. "Supaul"
  final double        currentLevel;   // current gauge reading (m)
  final double        dangerLevel;    // CWC danger level (m)
  final double        warningLevel;   // CWC warning level (m)
  final double        hfl;            // highest flood level (m)
  /// The threshold that was breached to generate this alert.
  /// Could be warningLevel, dangerLevel, or a custom subscription threshold.
  final double        thresholdLevel;
  final AlertSeverity severity;
  final AlertType     type;
  final DateTime      issuedAt;
  final String        message;

  const FloodAlert({
    required this.id,
    required this.stationName,
    required this.title,
    required this.river,
    required this.district,
    required this.currentLevel,
    required this.dangerLevel,
    required this.warningLevel,
    required this.hfl,
    required this.thresholdLevel,
    required this.severity,
    required this.type,
    required this.issuedAt,
    required this.message,
  });

  /// Convenience: % of danger level (0.0–2.0+)
  double get pctOfDanger => dangerLevel > 0 ? currentLevel / dangerLevel : 0.0;

  /// Convenience: % of the effective threshold (used for progress bar)
  double get pctOfThreshold =>
      thresholdLevel > 0 ? (currentLevel / thresholdLevel).clamp(0.0, 2.0) : 0.0;

  @override
  bool operator ==(Object other) =>
      other is FloodAlert && other.id == id && other.severity == severity;

  @override
  int get hashCode => Object.hash(id, severity);
}

// ─────────────────────────────────────────────────────────────────────────────
// AlertEngine
// ─────────────────────────────────────────────────────────────────────────────
const _kDedupKey    = 'alert_dedup_v2';
const _kDedupWindow = Duration(hours: 6);

class AlertEngine {
  AlertEngine._();
  static final AlertEngine instance = AlertEngine._();

  final FlutterLocalNotificationsPlugin _notif =
      FlutterLocalNotificationsPlugin();
  bool _initialised = false;

  // ── evaluateMerged ─────────────────────────────────────────────────────────
  //
  // Synchronous, Riverpod-Provider-safe.
  // Produces one FloodAlert per station that is at or above warningLevel.
  // Severity tiers:
  //   >= hfl * 0.98            → emergency
  //   >= dangerLevel           → critical
  //   >= dangerLevel * 0.85    → warning  (approaching danger)
  //   >= warningLevel          → info
  //
  // Returns list sorted by severity.priority DESC then issuedAt DESC.
  List<FloodAlert> evaluateMerged(List<RiverStation> stations) {
    final now    = DateTime.now();
    final alerts = <FloodAlert>[];

    for (final s in stations) {
      final cl  = s.current;
      final wl  = s.warning;
      final dl  = s.danger;
      final hfl = s.hfl;

      // Only alert if at or above warning level
      if (wl <= 0 || cl < wl) continue;

      // Determine severity + effective threshold
      final AlertSeverity sev;
      final double        threshold;
      final AlertType     type;

      if (hfl > 0 && cl >= hfl * 0.98) {
        sev       = AlertSeverity.emergency;
        threshold = hfl;
        type      = AlertType.breach;
      } else if (dl > 0 && cl >= dl) {
        sev       = AlertSeverity.critical;
        threshold = dl;
        type      = AlertType.breach;
      } else if (dl > 0 && cl >= dl * 0.85) {
        sev       = AlertSeverity.warning;
        threshold = dl;
        type      = AlertType.approaching;
      } else {
        sev       = AlertSeverity.info;
        threshold = wl;
        type      = AlertType.approaching;
      }

      final dayOfYear = now.difference(DateTime(now.year)).inDays;
      final id        = '${s.station}_${sev.name}_$dayOfYear';

      final pct    = threshold > 0 ? cl / threshold * 100 : 0.0;
      final dlStr  = dl > 0 ? dl.toStringAsFixed(2) : '—';
      final message = '${s.station} · ${s.river} · '
          '${cl.toStringAsFixed(2)} m '
          '(${pct.toStringAsFixed(0)}% of ${sev == AlertSeverity.info ? "WL" : "DL"} $dlStr m)';

      alerts.add(FloodAlert(
        id:             id,
        stationName:    s.station,
        title:          '${s.city} — ${sev.label}',
        river:          s.river,
        district:       s.city,   // RiverStation.city is the district/city name
        currentLevel:   cl,
        dangerLevel:    dl,
        warningLevel:   wl,
        hfl:            hfl,
        thresholdLevel: threshold,
        severity:       sev,
        type:           type,
        issuedAt:       now,
        message:        message,
      ));
    }

    alerts.sort((a, b) {
      final sc = b.severity.priority.compareTo(a.severity.priority);
      return sc != 0 ? sc : b.issuedAt.compareTo(a.issuedAt);
    });

    return alerts;
  }

  // ── async evaluate (push-notification path, unchanged from v2.0) ───────────
  Future<void> init() async {
    if (_initialised) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings();
    await _notif.initialize(
        const InitializationSettings(android: android, iOS: ios));
    _initialised = true;
  }

  Future<void> evaluate(
    List<FloodData>         gauges,
    List<AlertSubscription> subscriptions,
  ) async {
    await init();
    Position? userPos = await _getUserPosition();
    final prefs       = await SharedPreferences.getInstance();
    final dedupMap    = _loadDedup(prefs);

    for (final gauge in gauges) {
      final sub = subscriptions
          .where((s) => s.stationId == gauge.stationId)
          .firstOrNull;

      double threshold;
      if (sub?.customThresholdLevel != null) {
        threshold = sub!.customThresholdLevel!;
      } else {
        threshold = sub != null
            ? (gauge.warningLevel ?? gauge.dangerLevel)
            : gauge.dangerLevel;
      }

      if (gauge.currentLevel < threshold) continue;

      if (sub != null && sub.notifyOnBreachOnly) {
        if (!(gauge.willBreachDanger ?? false)) continue;
      }

      final key = '${gauge.stationId}_${gauge.riskLevel}_${DateTime.now().day}';
      if (_isDedupBlocked(dedupMap, key)) continue;

      if (userPos != null &&
          gauge.latitude  != null &&
          gauge.longitude != null) {
        final radiusKm = sub?.radiusKm ?? 50.0;
        if (radiusKm > 0) {
          final distM = Geolocator.distanceBetween(
            userPos.latitude,  userPos.longitude,
            gauge.latitude!,   gauge.longitude!,
          );
          if (distM > radiusKm * 1000) continue;
        }
      }

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
          accuracy:  LocationAccuracy.low,
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
      '\u{1F6A8} ${gauge.city} \u2014 ${gauge.riskLevel.toUpperCase()}',
      'Level: ${gauge.currentLevel.toStringAsFixed(2)} m '
      '(danger: ${gauge.dangerLevel.toStringAsFixed(2)} m)',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'flood_alerts', 'Flood Alerts',
          channelDescription: 'Critical flood level alerts',
          importance:    Importance.max,
          priority:      Priority.high,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
            presentAlert: true, presentSound: true),
      ),
    );
  }

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
    return DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(ts)) <
        _kDedupWindow;
  }

  void _markDedup(Map<String, int> map, String key) {
    map[key] = DateTime.now().millisecondsSinceEpoch;
    map.removeWhere((_, ts) =>
        DateTime.now().difference(
                DateTime.fromMillisecondsSinceEpoch(ts)) >
            const Duration(hours: 24));
  }

  Future<void> _saveDedup(
      SharedPreferences prefs, Map<String, int> map) async {
    await prefs.setString(_kDedupKey, jsonEncode(map));
    if (kDebugMode) debugPrint('[AlertEngine] dedup saved (${map.length} entries)');
  }
}
