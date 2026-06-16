// lib/services/real_time_river_service.dart
//
// OpsFlood — Real-Time River Data Service  v2.1
//
// v2.1 (15 Jun 2026):
//   Read mc['hfl'] from monitoredCities when available.
//   Fall back to dangerLevel * 1.10 only when 'hfl' is absent (legacy).
//   This ensures RiverPulseCard ThresholdBar uses the correct Highest Flood
//   Level (e.g. Birpur 76.02 m) rather than a computed over-estimate.
//
// v2.0: AppConstants.monitoredCities → IndiaGeodata.monitoredCities fix.

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../constants.dart';
import '../models/river_station.dart';
import 'live_fetch_engine.dart';
import 'wrd_bihar_service.dart';

// ── Result model ─────────────────────────────────────────────────────────────
class LiveRiverResult {
  final RiverStation station;
  final String       source;
  final double       confidence;
  final String?      mlRiskLevel;
  final double?      mlFloodProb;
  final bool         isStale;
  final String?      rawTimestamp;

  const LiveRiverResult({
    required this.station,
    required this.source,
    required this.confidence,
    this.mlRiskLevel,
    this.mlFloodProb,
    this.isStale = false,
    this.rawTimestamp,
  });
}

void _log(String msg) {
  if (kDebugMode) debugPrint('[RTRS] $msg');
}

// ── Service ───────────────────────────────────────────────────────────────────
class RealTimeRiverService extends ChangeNotifier {
  RealTimeRiverService();

  final WrdBiharService _wrd = WrdBiharService.instance;
  final LiveFetchEngine _lfe = LiveFetchEngine();

  List<LiveRiverResult> _lastResults = [];
  List<LiveRiverResult> get lastResults => _lastResults;

  // ── Public: fetch all monitored cities ───────────────────────────────────
  Future<List<LiveRiverResult>> fetchAll() async {
    final results = <LiveRiverResult>[];

    await _wrd.fetch();

    if (_lfe.liveLevels.isEmpty) {
      try { await _lfe.refreshData(); } catch (_) {}
    }

    final futures = IndiaGeodata.monitoredCities.map((mc) {
      final city  = mc['city']  as String;
      final state = mc['state'] as String;
      final river = mc['river'] as String;
      final wl    = _fp(mc['warning_level']);
      final dl    = _fp(mc['danger_level']);
      // v2.1: use static hfl when provided; fall back to dl*1.10 otherwise.
      final hfl   = mc.containsKey('hfl')
          ? _fp(mc['hfl'])
          : (dl > 0 ? dl * 1.10 : wl * 1.25);
      return _fetchCity(
        city: city, state: state, river: river,
        warningLevel: wl, dangerLevel: dl, staticHfl: hfl,
      );
    });
    results.addAll(await Future.wait(futures));

    final live = results.where((r) => r.source != 'NO_DATA').length;
    _log('fetchAll done: $live/${results.length} with live data');
    _lastResults = results;
    notifyListeners();
    return results;
  }

  // ── Public: fetch single city ────────────────────────────────────────────
  Future<LiveRiverResult> fetchCity({
    required String city,
    required String state,
    required String river,
  }) async {
    final mc = IndiaGeodata.monitoredCities.firstWhere(
      (m) => (m['city'] as String).toLowerCase() == city.toLowerCase(),
      orElse: () => <String, dynamic>{},
    );
    final dl  = _fp(mc['danger_level']);
    final wl  = _fp(mc['warning_level']);
    final hfl = mc.containsKey('hfl')
        ? _fp(mc['hfl'])
        : (dl > 0 ? dl * 1.10 : wl * 1.25);
    return _fetchCity(
      city: city, state: state, river: river,
      warningLevel: wl, dangerLevel: dl, staticHfl: hfl,
    );
  }

  // ── Public: force refresh ────────────────────────────────────────────────
  Future<List<LiveRiverResult>> refresh() async {
    await _wrd.fetch(forceRefresh: true);
    try { await _lfe.refreshData(); } catch (_) {}
    return fetchAll();
  }

  @override
  void dispose() {
    _lastResults = [];
    super.dispose();
  }

  // ── Per-city fetch ────────────────────────────────────────────────────────
  Future<LiveRiverResult> _fetchCity({
    required String city,
    required String state,
    required String river,
    required double warningLevel,
    required double dangerLevel,
    required double staticHfl,   // v2.1: explicit, never re-computed
  }) async {

    try {
      final wrdMatch = await _wrd.fetchBestMatch(city, river: river);
      if (wrdMatch != null && wrdMatch.currentLevel != null) {
        final lv = wrdMatch.currentLevel!;
        final dl = wrdMatch.dangerLevel  ?? dangerLevel;
        final wl = wrdMatch.warningLevel ?? warningLevel;
        // Use live hfl if provided by WRD; otherwise use staticHfl.
        final hl = wrdMatch.hfl ?? staticHfl;
        final risk = wrdMatch.riskLabel;
        _log('✓ $city | src=WRD_BIHAR | risk=$risk | level=${lv}m');
        return LiveRiverResult(
          station: RiverStation(
            city:         city,
            state:        state,
            river:        wrdMatch.river.isNotEmpty ? wrdMatch.river : river,
            station:      wrdMatch.site,
            current:      lv,
            warning:      wl,
            danger:       dl,
            hfl:          hl,
            flowRate:     null,
            trend:        wrdMatch.trend?.toUpperCase(),
            liveStatus:   risk,
            lastUpdated:  wrdMatch.fetchedAt.toIso8601String(),
            dataSource:   'WRD_BIHAR',
            isLive:       true,
          ),
          source:      'WRD_BIHAR',
          confidence:  0.95,
          mlRiskLevel: risk,
          mlFloodProb: _riskToProb(risk),
          rawTimestamp: wrdMatch.fetchedAt.toIso8601String(),
        );
      }
    } catch (e) {
      _log('WRD Bihar error for $city: $e');
    }

    try {
      final fd = _lfe.dataForCity(city);
      if (fd != null) {
        final lv   = fd.currentLevel ?? 0.0;
        final wlEf = fd.warningLevel > 0 ? fd.warningLevel : warningLevel;
        final dlEf = fd.dangerLevel  > 0 ? fd.dangerLevel  : dangerLevel;
        final risk = fd.riskLevel ?? 'LOW';
        _log('✓ $city | src=GLOFAS | risk=$risk | flow=${fd.flowRate} m³/s');
        return LiveRiverResult(
          station: RiverStation(
            city:         city,
            state:        state,
            river:        river,
            station:      '$city GloFAS',
            current:      lv,
            warning:      wlEf,
            danger:       dlEf,
            hfl:          staticHfl,   // always use the static value for GloFAS
            flowRate:     fd.flowRate,
            rainfallLastHour: fd.rainfall24h != null && fd.rainfall24h! > 0
                ? fd.rainfall24h! / 24 : null,
            trend:        _deriveTrend(lv, wlEf, dlEf),
            liveStatus:   risk,
            lastUpdated:  fd.lastUpdated.toIso8601String(),
            dataSource:   'GLOFAS',
            isLive:       true,
          ),
          source:      'GLOFAS',
          confidence:  0.75,
          mlRiskLevel: risk,
          mlFloodProb: _riskToProb(risk),
          isStale: DateTime.now().difference(fd.lastUpdated) >
                   const Duration(minutes: 30),
        );
      }
    } catch (e) {
      _log('GloFAS error for $city: $e');
    }

    _log('NO_DATA: $city');
    return LiveRiverResult(
      station: RiverStation(
        city: city, state: state, river: river,
        station:    '$city WRD Gauge',
        current:    0,
        warning:    warningLevel,
        danger:     dangerLevel,
        hfl:        staticHfl,
        dataSource: 'NO_DATA',
        isLive:     false,
      ),
      source:     'NO_DATA',
      confidence: 0.0,
    );
  }

  String _deriveTrend(double lv, double wl, double dl) {
    if (dl > 0 && lv >= dl * 0.97) return 'RISING';
    if (wl > 0 && lv >= wl)        return 'STEADY';
    if (wl > 0 && lv < wl * 0.80)  return 'FALLING';
    return 'STEADY';
  }

  double _riskToProb(String risk) {
    switch (risk.toUpperCase()) {
      case 'CRITICAL': return 0.92;
      case 'HIGH':     return 0.72;
      case 'MODERATE': return 0.48;
      default:         return 0.15;
    }
  }

  static double _fp(dynamic v) =>
      v == null ? 0.0 : (double.tryParse(v.toString().trim()) ?? 0.0);
}
