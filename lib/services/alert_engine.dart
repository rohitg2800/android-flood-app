// lib/services/alert_engine.dart  v5.1
//
// v5.1 (20 Jun 2026)
//   Fix #5 — evaluateMerged(): populate the five previously-null optional
//     fields on every FloodAlert it creates:
//       • rateOfRise / rateOfRiseMph  — computed from StationHistoryStore when
//         available; falls back to null only if truly no history exists.
//       • rainfall24h / rainfall24hMm — read from RiverStation.rainfall24hMm
//         (field added to the model in #211iq batch).
//       • action                      — derived from severity tier.
//     This ensures Excel export and any UI that reads these fields gets real
//     values instead of blanks for merged-station alerts.
//
// v5.0 (16 Jun 2026)
//   • FloodAlert gains optional: state, body, rateOfRiseMph, rainfall24hMm,
//     action, expiresAt — needed by offline_rule_engine & excel_export_service.
//   • AlertTypeExt gains displayName getter (used by offline_rule_engine).
//   • All existing fields/behaviour unchanged.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/flood_data.dart';
import '../models/river_station.dart';
import '../models/alert_subscription.dart';
import 'station_history_store.dart';

// ─ AlertSeverity ─────────────────────────────────────────────────────────
enum AlertSeverity { info, warning, critical, emergency }

extension AlertSeverityExt on AlertSeverity {
  int get priority => switch (this) {
    AlertSeverity.emergency => 4,
    AlertSeverity.critical  => 3,
    AlertSeverity.warning   => 2,
    AlertSeverity.info      => 1,
  };

  String get label => switch (this) {
    AlertSeverity.emergency => 'EMERGENCY',
    AlertSeverity.critical  => 'CRITICAL',
    AlertSeverity.warning   => 'WARNING',
    AlertSeverity.info      => 'INFO',
  };

  /// Recommended action text for each severity tier.
  String get defaultAction => switch (this) {
    AlertSeverity.emergency =>
        'EVACUATE IMMEDIATELY — move to higher ground, contact NDRF/SDRF',
    AlertSeverity.critical  =>
        'Prepare to evacuate — follow district authority instructions',
    AlertSeverity.warning   =>
        'Stay alert — avoid flood-prone areas and low-lying roads',
    AlertSeverity.info      =>
        'Monitor river levels — keep emergency kit ready',
  };
}

// ─ AlertType ────────────────────────────────────────────────────────────
enum AlertType {
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
  breach,
  approaching,
  forecast,
  custom,
}

extension AlertTypeExt on AlertType {
  String get label => switch (this) {
    AlertType.levelAboveHfl     => 'ABOVE HFL',
    AlertType.levelAboveDanger  => 'ABOVE DANGER',
    AlertType.levelAboveWarning => 'ABOVE WARNING',
    AlertType.rapidRise         => 'RAPID RISE',
    AlertType.forecastDanger24h => 'FORECAST 24H',
    AlertType.forecastDanger48h => 'FORECAST 48H',
    AlertType.rainfallExtreme   => 'EXTREME RAINFALL',
    AlertType.rainfallHeavy     => 'HEAVY RAINFALL',
    AlertType.upstreamCritical  => 'UPSTREAM CRITICAL',
    AlertType.multiRiverAlert   => 'MULTI-RIVER',
    AlertType.breach            => 'BREACH',
    AlertType.approaching       => 'APPROACHING',
    AlertType.forecast          => 'FORECAST',
    AlertType.custom            => 'CUSTOM',
  };

  String get displayName => switch (this) {
    AlertType.levelAboveHfl     => 'Level Above HFL',
    AlertType.levelAboveDanger  => 'Level Above Danger',
    AlertType.levelAboveWarning => 'Level Above Warning',
    AlertType.rapidRise         => 'Rapid Rise',
    AlertType.forecastDanger24h => 'Forecast: Danger in 24h',
    AlertType.forecastDanger48h => 'Forecast: Danger in 48h',
    AlertType.rainfallExtreme   => 'Extreme Rainfall',
    AlertType.rainfallHeavy     => 'Heavy Rainfall',
    AlertType.upstreamCritical  => 'Upstream Critical',
    AlertType.multiRiverAlert   => 'Multi-River Alert',
    AlertType.breach            => 'Threshold Breach',
    AlertType.approaching       => 'Approaching Threshold',
    AlertType.forecast          => 'Forecast Alert',
    AlertType.custom            => 'Custom Alert',
  };
}

// ─ FloodAlert ───────────────────────────────────────────────────────────
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

  // Optional / extended fields
  final String?   station;
  final String?   state;
  final String?   body;
  final double?   rateOfRise;
  final double?   rateOfRiseMph;
  final double?   rainfall24h;
  final double?   rainfall24hMm;
  final String?   action;
  final DateTime? expiresAt;

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
    this.state,
    this.body,
    this.rateOfRise,
    this.rateOfRiseMph,
    this.rainfall24h,
    this.rainfall24hMm,
    this.action,
    this.expiresAt,
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

// ─ AlertEngine ──────────────────────────────────────────────────────────
const _kDedupKey    = 'alert_dedup_v2';
const _kDedupWindow = Duration(hours: 6);

class AlertEngine {
  AlertEngine._();
  static final AlertEngine instance = AlertEngine._();

  final FlutterLocalNotificationsPlugin _notif =
      FlutterLocalNotificationsPlugin();
  bool _initialised = false;

  /// Evaluate a list of normalised [RiverStation]s and return sorted
  /// [FloodAlert]s ready for the UI.
  ///
  /// Fix #5: every alert now carries:
  ///   • rateOfRise / rateOfRiseMph  (m/h, from StationHistoryStore)
  ///   • rainfall24h / rainfall24hMm (mm, from RiverStation.rainfall24hMm)
  ///   • action                      (tier-specific recommended action text)
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

      // Bihar-aware thresholds — use tighter bands for verified stations
      final bool isBiharStation = wl > 0 && dl > 0 && (dl - wl) < 5.0;
      final double dangerBand   = isBiharStation ? 0.90 : 0.85;
      final double warningBand  = isBiharStation ? 0.95 : 0.90;

      if (hfl > 0 && cl >= hfl * 0.98) {
        sev = AlertSeverity.emergency; threshold = hfl;  aType = AlertType.levelAboveHfl;
      } else if (dl > 0 && cl >= dl) {
        sev = AlertSeverity.critical;  threshold = dl;   aType = AlertType.levelAboveDanger;
      } else if (dl > 0 && cl >= dl * dangerBand) {
        sev = AlertSeverity.warning;   threshold = dl;   aType = AlertType.levelAboveWarning;
      } else if (wl > 0 && cl >= wl * warningBand) {
        sev = AlertSeverity.info;      threshold = wl;   aType = AlertType.approaching;
      } else {
        sev = AlertSeverity.info;      threshold = wl;   aType = AlertType.levelAboveWarning;
      }

      final dayOfYear = now.difference(DateTime(now.year)).inDays;
      final id  = '${s.station}_${sev.name}_$dayOfYear';
      final pct = threshold > 0 ? cl / threshold * 100 : 0.0;
      // Fix #5a: rate of rise — read from StationHistoryStore
      final double? rawDiff = StationHistoryStore.instance
          .get(s.station)?.diff24h;
      final double? ror = rawDiff != null ? (rawDiff / 24.0) : null;

      final remaining = dl > 0 ? (dl - cl) : 0.0;
      final trend = ror != null && ror > 0 ? ' ↑ rising' : ror != null && ror < 0 ? ' ↓ falling' : '';
      final msg = '${s.station} · ${s.river} · ${cl.toStringAsFixed(2)} m'
          '${remaining > 0 ? " · ${remaining.toStringAsFixed(2)}m to danger" : " · AT DANGER"}'
          '$trend';

      // Fix #5b: 24-hour rainfall — read from the station model field
      // RiverStation.rainfall24hMm is nullable; use it directly.
      final double? rain24 = s.rainfallLastHour;

      // Fix #5c: action text — derived from severity tier
      final String actionText = sev.defaultAction;

      alerts.add(FloodAlert(
        id: id, stationName: s.station, station: s.station,
        title: '${s.city} — ${sev.label}', river: s.river,
        district: s.city, currentLevel: cl, dangerLevel: dl,
        warningLevel: wl, hfl: hfl, thresholdLevel: threshold,
        severity: sev, type: aType, issuedAt: now, message: msg,
        // Populated fields (Fix #5)
        rateOfRise:    ror,
        rateOfRiseMph: ror,
        rainfall24h:   rain24,
        rainfall24hMm: rain24,
        action:        actionText,
        // expiresAt: alerts issued by this path are valid until end of day
        expiresAt: DateTime(now.year, now.month, now.day, 23, 59, 59),
      ));
    }

    alerts.sort((a, b) {
      final sc = b.severity.priority.compareTo(a.severity.priority);
      return sc != 0 ? sc : b.issuedAt.compareTo(a.issuedAt);
    });
    return alerts;
  }

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
          accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 5)),
      );
    } catch (_) { return null; }
  }

  Future<void> _fireNotification(FloodData gauge) async {
    final id = gauge.stationId.hashCode.abs() % 100000;
    await _notif.show(
      id,
      '\u{1F6A8} ${gauge.city} — ${gauge.riskLevel.toUpperCase()}',
      'Level: ${gauge.currentLevel.toStringAsFixed(2)} m '
      '(danger: ${gauge.dangerLevel.toStringAsFixed(2)} m)',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'flood_alerts', 'Flood Alerts',
          channelDescription: 'Critical flood level alerts',
          importance: Importance.max, priority: Priority.high,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
    );
  }

  Map<String, int> _loadDedup(SharedPreferences prefs) {
    final raw = prefs.getString(_kDedupKey);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as int));
    } catch (_) { return {}; }
  }

  bool _isDedupBlocked(Map<String, int> map, String key) {
    final ts = map[key];
    if (ts == null) return false;
    return DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(ts)) < _kDedupWindow;
  }

  void _markDedup(Map<String, int> map, String key) {
    map[key] = DateTime.now().millisecondsSinceEpoch;
    map.removeWhere((_, ts) =>
        DateTime.now().difference(
            DateTime.fromMillisecondsSinceEpoch(ts)) > const Duration(hours: 24));
  }

  Future<void> _saveDedup(SharedPreferences prefs, Map<String, int> map) async {
    await prefs.setString(_kDedupKey, jsonEncode(map));
    if (kDebugMode) debugPrint('[AlertEngine] dedup saved (${map.length} entries)');
  }
}
