// lib/services/alert_engine.dart  v4.0
//
// v4.0 (16 Jun 2026)
//   • AlertType expanded: 10 service-facing constants added.
//     Old 4 (breach/approaching/forecast/custom) kept as aliases so
//     evaluateMerged() code compiles unchanged.
//   • FloodAlert gets optional station/rateOfRise/rainfall24h fields so
//     alert_share_service, fcm_templates, excel_export_service compile.
//   • AlertTypeExt.label covers all 14 values.
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
// AlertType  — 10 service-facing constants + 4 legacy aliases
// ─────────────────────────────────────────────────────────────────────────────
enum AlertType {
  // ── Service-facing (used by alert_share_service, fcm_templates, etc.) ──
  levelAboveHfl,
  levelAboveDanger,
  levelAboveWarning,
  rapidRise,
  forecastDanger24h,
  forecastDanger48h,
  rainfallExtreme,
  rainfallHeavy,
  upstreamCritical,
  multiRiverAlert,
  // ── Legacy (used by evaluateMerged internally) ──
  breach,
  approaching,
  forecast,
  custom,
}

extension AlertTypeExt on AlertType {
  String get label => switch (this) {
    AlertType.levelAboveHfl      => 'ABOVE HFL',
    AlertType.levelAboveDanger   => 'ABOVE DANGER',
    AlertType.levelAboveWarning  => 'ABOVE WARNING',
    AlertType.rapidRise          => 'RAPID RISE',
    AlertType.forecastDanger24h  => 'FORECAST 24H',
    AlertType.forecastDanger48h  => 'FORECAST 48H',
    AlertType.rainfallExtreme    => 'EXTREME RAINFALL',
    AlertType.rainfallHeavy      => 'HEAVY RAINFALL',
    AlertType.upstreamCritical   => 'UPSTREAM CRITICAL',
    AlertType.multiRiverAlert    => 'MULTI-RIVER',
    AlertType.breach             => 'BREACH',
    AlertType.approaching        => 'APPROACHING',
    AlertType.forecast           => 'FORECAST',
    AlertType.custom             => 'CUSTOM',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// FloodAlert  — immutable value class
// ─────────────────────────────────────────────────────────────────────────────
class FloodAlert {
  final String        id;
  final String        stationName;
  final String        title;
  final String        river;
  final String        district;
  final double        currentLevel;
  final double        dangerLevel;
  final double        warningLevel;
  final double        hfl;
  final double        thresholdLevel;
  final AlertSeverity severity;
  final AlertType     type;
  final DateTime      issuedAt;
  final String        message;

  // Optional fields used by alert_share_service / fcm_templates /
  // excel_export_service
  final String?   station;      // alias for stationName (some callers use this)
  final double?   rateOfRise;   // m/h
  final double?   rainfall24h;  // mm/24h

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
    this.station,
    this.rateOfRise,
    this.rainfall24h,
  });

  double get pctOfDanger    => dangerLevel    > 0 ? currentLevel / dangerLevel    : 0.0;
  double get pctOfThreshold => thresholdLevel > 0
      ? (currentLevel / thresholdLevel).clamp(0.0, 2.0) : 0.0;

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
  List<FloodAlert> evaluateMerged(List<RiverStation> stations) {
    final now    = DateTime.now();
    final alerts = <FloodAlert>[];

    for (final s in stations) {
      final cl  = s.current;
      final wl  = s.warning;
      final dl  = s.danger;
      final hfl = s.hfl;

      if (wl <= 0 || cl < wl) continue;

      final AlertSeverity sev;
      final double        threshold;
      final AlertType     aType;

      if (hfl > 0 && cl >= hfl * 0.98) {
        sev       = AlertSeverity.emergency;
        threshold = hfl;
        aType     = AlertType.levelAboveHfl;
      } else if (dl > 0 && cl >= dl) {
        sev       = AlertSeverity.critical;
        threshold = dl;
        aType     = AlertType.levelAboveDanger;
      } else if (dl > 0 && cl >= dl * 0.85) {
        sev       = AlertSeverity.warning;
        threshold = dl;
        aType     = AlertType.levelAboveWarning;
      } else {
        sev       = AlertSeverity.info;
        threshold = wl;
        aType     = AlertType.levelAboveWarning;
      }

      final dayOfYear = now.difference(DateTime(now.year)).inDays;
      final id        = '${s.station}_${sev.name}_$dayOfYear';

      final pct     = threshold > 0 ? cl / threshold * 100 : 0.0;
      final dlStr   = dl > 0 ? dl.toStringAsFixed(2) : '—';
      final msg     = '${s.station} · ${s.river} · '
          '${cl.toStringAsFixed(2)} m '
          '(${pct.toStringAsFixed(0)}% of '
          '${sev == AlertSeverity.info ? "WL" : "DL"} $dlStr m)';

      alerts.add(FloodAlert(
        id:             id,
        stationName:    s.station,
        station:        s.station,
        title:          '${s.city} — ${sev.label}',
        river:          s.river,
        district:       s.city,
        currentLevel:   cl,
        dangerLevel:    dl,
        warningLevel:   wl,
        hfl:            hfl,
        thresholdLevel: threshold,
        severity:       sev,
        type:           aType,
        issuedAt:       now,
        message:        msg,
      ));
    }

    alerts.sort((a, b) {
      final sc = b.severity.priority.compareTo(a.severity.priority);
      return sc != 0 ? sc : b.issuedAt.compareTo(a.issuedAt);
    });

    return alerts;
  }

  // ── async evaluate ─────────────────────────────────────────────────────────
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
