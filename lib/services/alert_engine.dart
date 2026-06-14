// lib/services/alert_engine.dart  v1.3
//
// v1.3 — UX: stable alert IDs + preserved issuedAt
//
//   PROBLEM: every call to _runPipeline stamped `issuedAt: now` on every
//   alert.  On each data-poll cycle the AlertProvider received "new" objects
//   with updated timestamps, triggering notifyListeners() and causing the
//   alerts list to flicker/rebuild continuously even when nothing changed.
//
//   FIX:
//   1. AlertEngine keeps an internal _issued cache: Map<alertId, DateTime>.
//      First time an alert fires it records the wall-clock time.  On every
//      subsequent re-evaluation the SAME issuedAt is used, so the FloodAlert
//      object is semantically identical to the previous one.
//   2. expiresAt is anchored to the cached issuedAt — an alert that has been
//      active for 2 h will expire correctly rather than having its TTL reset.
//   3. clearIssuedCache() lets tests and the admin screen flush state.

library;

import '../models/river_station.dart';
import 'data_fetch_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AlertSeverity
// ─────────────────────────────────────────────────────────────────────────────
enum AlertSeverity { info, warning, critical, emergency }

extension AlertSeverityExt on AlertSeverity {
  String get label {
    switch (this) {
      case AlertSeverity.info:      return 'INFO';
      case AlertSeverity.warning:   return 'WARNING';
      case AlertSeverity.critical:  return 'CRITICAL';
      case AlertSeverity.emergency: return 'EMERGENCY';
    }
  }
  int get priority {
    switch (this) {
      case AlertSeverity.info:      return 0;
      case AlertSeverity.warning:   return 1;
      case AlertSeverity.critical:  return 2;
      case AlertSeverity.emergency: return 3;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AlertType
// ─────────────────────────────────────────────────────────────────────────────
enum AlertType {
  levelAboveWarning,
  levelAboveDanger,
  levelAboveHfl,
  rapidRise,
  forecastDanger24h,
  forecastDanger48h,
  rainfallExtreme,
  rainfallHeavy,
  upstreamCritical,
  multiRiverAlert,
}

extension AlertTypeExt on AlertType {
  String get displayName {
    switch (this) {
      case AlertType.levelAboveWarning:  return 'Above Warning Level';
      case AlertType.levelAboveDanger:   return 'Above Danger Level';
      case AlertType.levelAboveHfl:      return 'Above HFL (All-Time High)';
      case AlertType.rapidRise:          return 'Rapid Rise Alert';
      case AlertType.forecastDanger24h:  return 'Forecast: Danger in 24h';
      case AlertType.forecastDanger48h:  return 'Forecast: Danger in 48h';
      case AlertType.rainfallExtreme:    return 'Extreme Rainfall';
      case AlertType.rainfallHeavy:      return 'Heavy Rainfall';
      case AlertType.upstreamCritical:   return 'Upstream Critical';
      case AlertType.multiRiverAlert:    return 'Multi-River Flood Alert';
    }
  }

  String get label => displayName;

  String get icon {
    switch (this) {
      case AlertType.levelAboveWarning:  return '⚠️';
      case AlertType.levelAboveDanger:   return '🚨';
      case AlertType.levelAboveHfl:      return '🔴';
      case AlertType.rapidRise:          return '📈';
      case AlertType.forecastDanger24h:  return '⏱️';
      case AlertType.forecastDanger48h:  return '🗓️';
      case AlertType.rainfallExtreme:    return '🌧️';
      case AlertType.rainfallHeavy:      return '🌨️';
      case AlertType.upstreamCritical:   return '⬆️';
      case AlertType.multiRiverAlert:    return '🌊';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FloodAlert
// ─────────────────────────────────────────────────────────────────────────────
class FloodAlert {
  final String        id;
  final AlertType     type;
  final AlertSeverity severity;
  final String        title;
  final String        body;
  final String        stationName;
  final String        river;
  final String        district;
  final String        state;
  final double        currentLevel;
  final double        thresholdLevel;
  final double?       rateOfRiseMph;
  final double?       rainfall24hMm;
  final String        action;
  final DateTime      issuedAt;
  final DateTime?     expiresAt;

  const FloodAlert({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.body,
    required this.stationName,
    required this.river,
    required this.district,
    required this.state,
    required this.currentLevel,
    required this.thresholdLevel,
    this.rateOfRiseMph,
    this.rainfall24hMm,
    required this.action,
    required this.issuedAt,
    this.expiresAt,
  });

  String get station      => stationName;
  double? get rateOfRise  => rateOfRiseMph;
  double? get rainfall24h => rainfall24hMm;
  bool   get isOffline    => false;

  bool get isExpired {
    final exp = expiresAt;
    return exp != null && DateTime.now().isAfter(exp);
  }

  double get exceedancePct =>
      thresholdLevel > 0
          ? ((currentLevel - thresholdLevel) / thresholdLevel * 100)
          : 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// AlertEngine  v1.3
// ─────────────────────────────────────────────────────────────────────────────
class AlertEngine {
  AlertEngine._();
  static final instance = AlertEngine._();

  // v1.3: stable issued-at cache — keyed by alert ID.
  // Once an alert fires for the first time, its wall-clock issuedAt is stored
  // here and reused on every subsequent evaluation.  This prevents the
  // FloodAlert objects from changing on every data-poll cycle.
  final Map<String, DateTime> _issued = {};

  /// Returns the stable issuedAt for [id], recording [now] on first call.
  DateTime _issuedAt(String id, DateTime now) =>
      _issued.putIfAbsent(id, () => now);

  /// Purges IDs that have not been seen in [maxAge] (default 24 h).
  /// Call periodically (e.g. from a timer in the provider) to prevent
  /// unbounded growth of the cache.
  void pruneIssuedCache({Duration maxAge = const Duration(hours: 24)}) {
    final cutoff = DateTime.now().subtract(maxAge);
    _issued.removeWhere((_, ts) => ts.isBefore(cutoff));
  }

  /// Full reset — useful for tests and the admin debug screen.
  void clearIssuedCache() => _issued.clear();

  // ── Entry-points ─────────────────────────────────────────────────────────

  List<FloodAlert> evaluateMerged(List<RiverStation> stations) {
    final now      = DateTime.now();
    final readings = stations.map(_riverStationToReading).toList();
    return _runPipeline(readings, now);
  }

  List<FloodAlert> evaluate(DataFetchSnapshot snapshot) {
    if (snapshot.isLoading) return const [];
    return _runPipeline(snapshot.stations, snapshot.fetchedAt);
  }

  // ── Shared pipeline ───────────────────────────────────────────────────────
  List<FloodAlert> _runPipeline(
      List<StationReading> readings, DateTime now) {
    final alerts = <FloodAlert>[];

    for (final s in readings) {
      alerts.addAll(_evaluateStation(s, now));
    }
    alerts.addAll(_evaluateBasin(readings, now));

    // Deduplicate by ID; prefer higher severity.
    final Map<String, FloodAlert> deduped = {};
    for (final a in alerts) {
      final existing = deduped[a.id];
      if (existing == null ||
          a.severity.priority > existing.severity.priority) {
        deduped[a.id] = a;
      }
    }

    // Prune cache of very old IDs (keep memory bounded).
    pruneIssuedCache();

    return deduped.values
        .where((a) => !a.isExpired)
        .toList()
      ..sort((a, b) {
        final sc = b.severity.priority.compareTo(a.severity.priority);
        if (sc != 0) return sc;
        return b.issuedAt.compareTo(a.issuedAt);
      });
  }

  // ── RiverStation → StationReading shim ───────────────────────────────────
  static StationReading _riverStationToReading(RiverStation s) {
    final district = (s.city.isNotEmpty && s.city != s.station)
        ? s.city
        : s.river;
    return StationReading(
      stationName:  s.station,
      river:        s.river,
      district:     district,
      state:        s.state,
      lat:          s.lat  ?? 0.0,
      lon:          s.lon  ?? 0.0,
      currentLevel: s.current,
      warningLevel: s.warning,
      dangerLevel:  s.danger,
      hfl:          s.hfl,
      progressPct:  s.progressPct * 100,
      riskLabel:    s.riskLabel,
      source:       s.dataSource ?? 'MERGED',
      isLive:       s.isLive,
      fetchedAt:    DateTime.now(),
    );
  }

  List<FloodAlert> _evaluateStation(StationReading s, DateTime now) {
    final alerts = <FloodAlert>[];
    final id     = s.stationName.toLowerCase().replaceAll(' ', '_');

    if (s.isAboveHfl) {
      final aid = '$id.hfl';
      final ts  = _issuedAt(aid, now); // v1.3: stable timestamp
      alerts.add(FloodAlert(
        id: aid, type: AlertType.levelAboveHfl,
        severity: AlertSeverity.emergency,
        title: '${s.stationName}: NEW HFL',
        body: '${s.stationName} on ${s.river} has reached '
              '${s.currentLevel.toStringAsFixed(2)} m — '
              'above the all-time HFL of ${s.hfl.toStringAsFixed(2)} m.',
        stationName: s.stationName, river: s.river,
        district: s.district, state: s.state,
        currentLevel: s.currentLevel, thresholdLevel: s.hfl,
        action: 'EVACUATE immediately. Breach possible. Alert SDRF and district admin.',
        issuedAt: ts, expiresAt: ts.add(const Duration(hours: 12)),
      ));
    } else if (s.isAboveDanger) {
      final aid = '$id.danger';
      final ts  = _issuedAt(aid, now);
      alerts.add(FloodAlert(
        id: aid, type: AlertType.levelAboveDanger,
        severity: AlertSeverity.emergency,
        title: '${s.stationName}: DANGER LEVEL BREACHED',
        body: '${s.stationName} on ${s.river} at '
              '${s.currentLevel.toStringAsFixed(2)} m '
              '(danger: ${s.dangerLevel.toStringAsFixed(2)} m). '
              '${(s.currentLevel - s.dangerLevel).toStringAsFixed(2)} m above danger.',
        stationName: s.stationName, river: s.river,
        district: s.district, state: s.state,
        currentLevel: s.currentLevel, thresholdLevel: s.dangerLevel,
        action: 'Issue Red Alert. Initiate evacuation in low-lying areas. Deploy NDRF/SDRF.',
        issuedAt: ts, expiresAt: ts.add(const Duration(hours: 6)),
      ));
    } else if (s.isAboveWarning) {
      final aid = '$id.warning';
      final ts  = _issuedAt(aid, now);
      alerts.add(FloodAlert(
        id: aid, type: AlertType.levelAboveWarning,
        severity: AlertSeverity.critical,
        title: '${s.stationName}: Above Warning Level',
        body: '${s.stationName} on ${s.river} at '
              '${s.currentLevel.toStringAsFixed(2)} m '
              '(warning: ${s.warningLevel.toStringAsFixed(2)} m). '
              'Approaching danger level.',
        stationName: s.stationName, river: s.river,
        district: s.district, state: s.state,
        currentLevel: s.currentLevel, thresholdLevel: s.warningLevel,
        action: 'Issue Yellow Alert. Monitor closely. Prepare evacuation plans.',
        issuedAt: ts, expiresAt: ts.add(const Duration(hours: 4)),
      ));
    }

    final ror = s.rateOfRiseMph;
    if (ror != null && ror >= 0.15) {
      final isCrit = ror >= 0.30;
      final aid    = '$id.rapid_rise';
      final ts     = _issuedAt(aid, now);
      alerts.add(FloodAlert(
        id: aid, type: AlertType.rapidRise,
        severity: isCrit ? AlertSeverity.critical : AlertSeverity.warning,
        title: '${s.stationName}: Rapid Rise (${ror.toStringAsFixed(2)} m/h)',
        body: '${s.stationName} on ${s.river} is rising at '
              '${ror.toStringAsFixed(2)} m/h. '
              '${isCrit ? "Flash flood risk is HIGH." : "Elevated flood risk."}',
        stationName: s.stationName, river: s.river,
        district: s.district, state: s.state,
        currentLevel: s.currentLevel, thresholdLevel: s.warningLevel,
        rateOfRiseMph: ror,
        action: isCrit
            ? 'Warn communities downstream. Close riverfront areas.'
            : 'Alert downstream districts. Monitor every 15 min.',
        issuedAt: ts, expiresAt: ts.add(const Duration(hours: 3)),
      ));
    }

    final f24 = s.forecastLevel24h;
    if (f24 != null && f24 >= s.dangerLevel && !s.isAboveDanger) {
      final aid = '$id.forecast24';
      final ts  = _issuedAt(aid, now);
      alerts.add(FloodAlert(
        id: aid, type: AlertType.forecastDanger24h,
        severity: AlertSeverity.critical,
        title: '${s.stationName}: Danger Expected in 24h',
        body: '${s.stationName} on ${s.river} forecast to reach '
              '${f24.toStringAsFixed(2)} m '
              '(danger: ${s.dangerLevel.toStringAsFixed(2)} m) within 24 hours.',
        stationName: s.stationName, river: s.river,
        district: s.district, state: s.state,
        currentLevel: s.currentLevel, thresholdLevel: s.dangerLevel,
        action: 'Pre-position boats. Notify village-level disaster committees.',
        issuedAt: ts, expiresAt: ts.add(const Duration(hours: 24)),
      ));
    }

    final f48 = s.forecastLevel48h;
    if (f48 != null && f48 >= s.dangerLevel &&
        (f24 == null || f24 < s.dangerLevel)) {
      final aid = '$id.forecast48';
      final ts  = _issuedAt(aid, now);
      alerts.add(FloodAlert(
        id: aid, type: AlertType.forecastDanger48h,
        severity: AlertSeverity.warning,
        title: '${s.stationName}: Danger Possible in 48h',
        body: '${s.stationName} on ${s.river} may reach danger level within 48 h '
              '(forecast: ${f48.toStringAsFixed(2)} m).',
        stationName: s.stationName, river: s.river,
        district: s.district, state: s.state,
        currentLevel: s.currentLevel, thresholdLevel: s.dangerLevel,
        action: 'Review embankment status. Alert district administration.',
        issuedAt: ts, expiresAt: ts.add(const Duration(hours: 48)),
      ));
    }

    final rain = s.rainfall24hMm;
    if (rain != null) {
      if (rain >= 100) {
        final aid = '$id.rain_extreme';
        final ts  = _issuedAt(aid, now);
        alerts.add(FloodAlert(
          id: aid, type: AlertType.rainfallExtreme,
          severity: AlertSeverity.critical,
          title: '${s.district}: Extreme Rainfall (${rain.toStringAsFixed(0)} mm)',
          body: 'Extreme rainfall of ${rain.toStringAsFixed(0)} mm recorded '
                'near ${s.district} in past 24 h. IMD Red Alert threshold exceeded.',
          stationName: s.stationName, river: s.river,
          district: s.district, state: s.state,
          currentLevel: s.currentLevel, thresholdLevel: 100.0,
          rainfall24hMm: rain,
          action: 'Mobilise rescue teams. Close low-lying settlements.',
          issuedAt: ts, expiresAt: ts.add(const Duration(hours: 6)),
        ));
      } else if (rain >= 64.5) {
        final aid = '$id.rain_heavy';
        final ts  = _issuedAt(aid, now);
        alerts.add(FloodAlert(
          id: aid, type: AlertType.rainfallHeavy,
          severity: AlertSeverity.warning,
          title: '${s.district}: Heavy Rainfall (${rain.toStringAsFixed(0)} mm)',
          body: 'Heavy rainfall of ${rain.toStringAsFixed(0)} mm in past 24 h '
                'near ${s.district}. IMD Heavy Rain threshold exceeded.',
          stationName: s.stationName, river: s.river,
          district: s.district, state: s.state,
          currentLevel: s.currentLevel, thresholdLevel: 64.5,
          rainfall24hMm: rain,
          action: 'Alert block-level officials. Monitor river rise closely.',
          issuedAt: ts, expiresAt: ts.add(const Duration(hours: 6)),
        ));
      }
    }

    return alerts;
  }

  List<FloodAlert> _evaluateBasin(
      List<StationReading> stations, DateTime now) {
    final alerts = <FloodAlert>[];

    final riverGroups = <String, List<StationReading>>{};
    for (final s in stations) {
      riverGroups.putIfAbsent(s.river, () => []).add(s);
    }
    riverGroups.forEach((river, slist) {
      final dangerStns = slist.where((s) => s.isAboveDanger).toList();
      if (dangerStns.length >= 2) {
        final aid = '${river.toLowerCase().replaceAll(' ', '_')}.upstream_critical';
        final ts  = _issuedAt(aid, now);
        alerts.add(FloodAlert(
          id: aid,
          type: AlertType.upstreamCritical,
          severity: AlertSeverity.emergency,
          title: '$river: Multi-Station Danger',
          body: '${dangerStns.length} stations on $river are above danger level: '
                '${dangerStns.map((s) => s.stationName).join(", ")}. '
                'Downstream breach risk is HIGH.',
          stationName: dangerStns.first.stationName, river: river,
          district: dangerStns.first.district,
          state: dangerStns.first.state,
          currentLevel: dangerStns
              .map((s) => s.currentLevel)
              .reduce((a, b) => a > b ? a : b),
          thresholdLevel: dangerStns.first.dangerLevel,
          action:
              'Breach likely. Mobilise NDRF. Evacuate all riverside settlements.',
          issuedAt: ts,
          expiresAt: ts.add(const Duration(hours: 8)),
        ));
      }
    });

    final warnRivers = riverGroups.keys
        .where((r) => riverGroups[r]!.any((s) => s.isAboveWarning))
        .toList();
    if (warnRivers.length >= 3) {
      const aid = 'bihar.multi_river';
      final ts  = _issuedAt(aid, now);
      alerts.add(FloodAlert(
        id: aid, type: AlertType.multiRiverAlert,
        severity: AlertSeverity.critical,
        title: 'Multi-River Flood Alert (${warnRivers.length} Rivers)',
        body: '${warnRivers.length} rivers are above warning level: '
              '${warnRivers.join(", ")}. '
              'State-wide flood situation developing.',
        stationName: 'State-Wide', river: warnRivers.join(" / "),
        district: 'Multiple Districts', state: 'Bihar',
        currentLevel: 0, thresholdLevel: 0,
        action:
            'Activate State Emergency Operations Centre. Issue state-wide flood alert.',
        issuedAt: ts,
        expiresAt: ts.add(const Duration(hours: 12)),
      ));
    }

    return alerts;
  }
}
