// lib/services/active_alert_controller.dart  v2.1
//
// v2.1 (15 Jun 2026) — remove DataFetchSnapshot wrapper in push().
//   push(List<StationReading>) now calls _processReadings() directly so
//   there is no List<StationReading> → List<FloodData> type conflict.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'data_fetch_engine.dart';   // StationReading

// ── Severity enum (ordered low→high for comparisons) ─────────────────────────
enum AlertSeverity { normal, rising, danger, critical, extreme }

extension AlertSeverityX on AlertSeverity {
  bool operator >(AlertSeverity other)  => index > other.index;
  bool operator >=(AlertSeverity other) => index >= other.index;
}

// ── AlertItem ─────────────────────────────────────────────────────────────────
class AlertItem {
  final String        stationKey;
  final String        stationName;
  final String        river;
  final String        district;
  final AlertSeverity severity;
  final String        message;
  final String?       subMessage;
  final double?       rateOfRiseMph;
  final double        currentLevel;
  final double        dangerLevel;
  final double        hfl;
  final bool          aboveHfl;
  final String        source;
  final bool          isLive;
  final DateTime      firstSeenAt;
  final DateTime      lastSeenAt;

  const AlertItem({
    required this.stationKey,
    required this.stationName,
    required this.river,
    required this.district,
    required this.severity,
    required this.message,
    required this.subMessage,
    required this.rateOfRiseMph,
    required this.currentLevel,
    required this.dangerLevel,
    required this.hfl,
    required this.aboveHfl,
    required this.source,
    required this.isLive,
    required this.firstSeenAt,
    required this.lastSeenAt,
  });

  AlertItem copyWithTime(DateTime lastSeen) => AlertItem(
    stationKey:    stationKey,
    stationName:   stationName,
    river:         river,
    district:      district,
    severity:      severity,
    message:       message,
    subMessage:    subMessage,
    rateOfRiseMph: rateOfRiseMph,
    currentLevel:  currentLevel,
    dangerLevel:   dangerLevel,
    hfl:           hfl,
    aboveHfl:      aboveHfl,
    source:        source,
    isLive:        isLive,
    firstSeenAt:   firstSeenAt,
    lastSeenAt:    lastSeen,
  );
}

// ── ActiveAlertController ─────────────────────────────────────────────────────
class ActiveAlertController {
  ActiveAlertController._();
  static final instance = ActiveAlertController._();

  static const _kMaxAlerts      = 8;
  static const _kSuppressWindow = Duration(minutes: 30);
  static const _kClearWindow    = Duration(minutes: 15);
  static const _kRorThreshold   = 0.3;    // m/h
  static const _kRainThreshold  = 10.0;   // mm/24h

  final _activeMap   = <String, AlertItem>{};
  final _normalSince = <String, DateTime>{};
  bool _started = false;

  final _ctrl = StreamController<List<AlertItem>>.broadcast();

  Stream<List<AlertItem>> get stream => _ctrl.stream;
  List<AlertItem>         get alerts => _sortedAlerts();

  // ── lifecycle ─────────────────────────────────────────────────────────────────
  void start() {
    if (_started) return;
    _started = true;
    debugPrint('[AlertCtrl v2.1] started — waiting for mergedStations push()');
  }

  void stop() {
    _started = false;
    debugPrint('[AlertCtrl v2.1] stopped');
  }

  // ── push() — entry-point called by alerts_parent_bridge_provider ─────────────
  // Processes StationReading list directly; no DataFetchSnapshot wrapper needed.
  void push(List<StationReading> stations) {
    if (stations.isEmpty) return;
    _processReadings(stations);
  }

  // ── core processing ───────────────────────────────────────────────────────────
  void _processReadings(List<StationReading> readings) {
    final now = DateTime.now();

    for (final s in readings) {
      // Rule 1: SEED source never alerts
      if (s.source == 'SEED') continue;

      final key      = _norm(s.stationName);
      final severity = _deriveSeverity(s);

      if (severity == AlertSeverity.normal) {
        _normalSince.putIfAbsent(key, () => now);
        final sinceNormal = now.difference(_normalSince[key]!);
        if (sinceNormal >= _kClearWindow) {
          _activeMap.remove(key);
          _normalSince.remove(key);
        }
        continue;
      }

      _normalSince.remove(key);

      final existing   = _activeMap[key];
      final isSameTier = existing != null && existing.severity == severity;
      final isExpired  = existing == null ||
          now.difference(existing.lastSeenAt) >= _kSuppressWindow;
      final escalated  = existing != null && severity > existing.severity;

      if (isSameTier && !isExpired && !escalated) {
        _activeMap[key] = existing.copyWithTime(now);
        continue;
      }

      _activeMap[key] = _buildAlert(s, severity, now,
          firstSeen: existing?.firstSeenAt ?? now);
    }

    _emit();
  }

  void _emit() {
    if (!_ctrl.isClosed) _ctrl.add(_sortedAlerts());
  }

  List<AlertItem> _sortedAlerts() {
    final all = _activeMap.values.toList()
      ..sort((a, b) {
        final sc = b.severity.index.compareTo(a.severity.index);
        if (sc != 0) return sc;
        final ap = a.dangerLevel > 0 ? a.currentLevel / a.dangerLevel : 0.0;
        final bp = b.dangerLevel > 0 ? b.currentLevel / b.dangerLevel : 0.0;
        return bp.compareTo(ap);
      });
    return all.take(_kMaxAlerts).toList();
  }

  // ── severity derivation ───────────────────────────────────────────────────────
  AlertSeverity _deriveSeverity(StationReading s) {
    if (!s.isLive) return AlertSeverity.normal;
    if (s.currentLevel >= s.hfl)          return AlertSeverity.extreme;
    if (s.currentLevel >= s.dangerLevel)  return AlertSeverity.critical;
    if (s.currentLevel >= s.warningLevel) return AlertSeverity.danger;
    final ror  = s.rateOfRiseMph ?? 0.0;
    final rain = s.rainfall24hMm ?? 0.0;
    if (ror >= _kRorThreshold && rain >= _kRainThreshold) return AlertSeverity.rising;
    return AlertSeverity.normal;
  }

  // ── alert item builder ────────────────────────────────────────────────────────
  AlertItem _buildAlert(
    StationReading s,
    AlertSeverity  severity,
    DateTime       now, {
    required DateTime firstSeen,
  }) {
    final tierLabel = switch (severity) {
      AlertSeverity.extreme  => '🚨 ABOVE HFL',
      AlertSeverity.critical => '🔴 CRITICAL',
      AlertSeverity.danger   => '🟠 DANGER',
      AlertSeverity.rising   => '⚡ RAPID RISE',
      AlertSeverity.normal   => 'NORMAL',
    };
    final message = '$tierLabel — ${s.stationName} (${s.river})';
    final aboveDl = s.currentLevel - s.dangerLevel;

    final sub = switch (severity) {
      AlertSeverity.extreme  =>
          '${s.currentLevel.toStringAsFixed(2)} m — '
          '${(s.currentLevel - s.hfl).abs().toStringAsFixed(2)} m above HFL',
      AlertSeverity.critical =>
          '${s.currentLevel.toStringAsFixed(2)} m — '
          '+${aboveDl.toStringAsFixed(2)} m above danger (${s.dangerLevel.toStringAsFixed(2)} m)',
      AlertSeverity.danger   =>
          '${s.currentLevel.toStringAsFixed(2)} m — '
          'DL ${s.dangerLevel.toStringAsFixed(2)} m · WL ${s.warningLevel.toStringAsFixed(2)} m',
      AlertSeverity.rising   =>
          'Rising at ${(s.rateOfRiseMph ?? 0).toStringAsFixed(2)} m/h · '
          '${(s.rainfall24hMm ?? 0).toStringAsFixed(0)} mm rain/24h',
      AlertSeverity.normal   => '',
    };

    return AlertItem(
      stationKey:    _norm(s.stationName),
      stationName:   s.stationName,
      river:         s.river,
      district:      s.district,
      severity:      severity,
      message:       message,
      subMessage:    sub.isEmpty ? null : sub,
      rateOfRiseMph: s.rateOfRiseMph,
      currentLevel:  s.currentLevel,
      dangerLevel:   s.dangerLevel,
      hfl:           s.hfl,
      aboveHfl:      s.currentLevel >= s.hfl,
      source:        s.source,
      isLive:        s.isLive,
      firstSeenAt:   firstSeen,
      lastSeenAt:    now,
    );
  }

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ' ').trim();
}
