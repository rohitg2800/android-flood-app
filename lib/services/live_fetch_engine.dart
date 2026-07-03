// lib/services/live_fetch_engine.dart  (v4.2 — river severity wired)
//
// v4.1 → v4.2 changes:
//   • LiveCityData: add predictedSeverity, riskScore, confidencePercent,
//     willBreachDanger, peakLevel72h fields + updated copyWith
//   • toFloodData() passes all 5 new fields to FloodData
//   • _fetchAllCities(): after WRD+GloFAS+rain assembly, calls
//     GET /api/live-levels (with_severity=true) once for ALL cities;
//     merges ML fields (predicted_severity, risk_score, etc.) per city.
//   • _buildCriticalAlerts(): enriched with ML severity fields.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../constants/india_geodata.dart';
import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import 'backend_api_service.dart';
import 'station_trend_store.dart';
import 'wrd_bihar_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CircuitBreaker
// ─────────────────────────────────────────────────────────────────────────────
class _CircuitBreaker {
  static const int _threshold = 5;
  static const Duration _halfOpenAfter = Duration(seconds: 30);

  int _failures = 0;
  bool _open = false;
  DateTime? _openedAt;

  bool get isOpen {
    if (!_open) return false;
    if (_openedAt != null &&
        DateTime.now().difference(_openedAt!) >= _halfOpenAfter) {
      _open = false;
      _failures = 0;
      return false;
    }
    return true;
  }

  void recordSuccess() {
    _failures = 0;
    _open = false;
    _openedAt = null;
  }

  void recordFailure() {
    _failures++;
    if (_failures >= _threshold) {
      _open = true;
      _openedAt = DateTime.now();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SharedFetchCoordinator
// ─────────────────────────────────────────────────────────────────────────────
class SharedFetchCoordinator {
  SharedFetchCoordinator._();
  static final SharedFetchCoordinator instance = SharedFetchCoordinator._();

  final Map<String, Future<dynamic>> _inflight = {};

  Future<T> dedupe<T>(String key, Future<T> Function() work) {
    if (_inflight.containsKey(key)) {
      return _inflight[key]! as Future<T>;
    }
    final f = work().whenComplete(() => _inflight.remove(key));
    _inflight[key] = f;
    return f;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VersionedDataCache
// ─────────────────────────────────────────────────────────────────────────────
class VersionedDataCache<T> {
  final Duration ttl;
  T? _value;
  DateTime? _fetchedAt;
  String? _etag;

  VersionedDataCache({required this.ttl});

  bool get isStale =>
      _fetchedAt == null || DateTime.now().difference(_fetchedAt!) >= ttl;

  T? get value => _value;
  String? get etag => _etag;

  void set(T value, {String? etag}) {
    _value = value;
    _fetchedAt = DateTime.now();
    _etag = etag;
  }

  void invalidate() {
    _fetchedAt = null;
    _value = null;
    _etag = null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SourceHealth
// ─────────────────────────────────────────────────────────────────────────────
class SourceHealth {
  final bool healthy;
  final int? latencyMs;
  final DateTime? lastSuccessAt;
  final String? lastError;

  const SourceHealth({
    required this.healthy,
    this.latencyMs,
    this.lastSuccessAt,
    this.lastError,
  });

  const SourceHealth.unknown()
      : healthy = false,
        latencyMs = null,
        lastSuccessAt = null,
        lastError = null;

  SourceHealth copyWith({
    bool? healthy,
    int? latencyMs,
    DateTime? lastSuccessAt,
    String? lastError,
  }) =>
      SourceHealth(
        healthy: healthy ?? this.healthy,
        latencyMs: latencyMs ?? this.latencyMs,
        lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
        lastError: lastError ?? this.lastError,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// LiveCityData  (v4.2)
// ─────────────────────────────────────────────────────────────────────────────
class LiveCityData {
  final double? currentLevel;
  final double warningLevel;
  final double dangerLevel;
  final double? flowRate;
  final double? rainfall24h;
  final String? riskLevel;
  final DateTime lastUpdated;

  // v4.2 ML fields
  final String? predictedSeverity;
  final int? riskScore;
  final double? confidencePercent;
  final bool? willBreachDanger;
  final double? peakLevel72h;

  const LiveCityData({
    this.currentLevel,
    required this.warningLevel,
    required this.dangerLevel,
    this.flowRate,
    this.rainfall24h,
    this.riskLevel,
    required this.lastUpdated,
    // v4.2
    this.predictedSeverity,
    this.riskScore,
    this.confidencePercent,
    this.willBreachDanger,
    this.peakLevel72h,
  });

  @override
  String toString() =>
      'LiveCityData(flow=$flowRate m\u00b3/s, risk=$riskLevel, '
      'severity=$predictedSeverity, score=$riskScore, '
      'rain=${rainfall24h}mm, level=$currentLevel m)';

  LiveCityData copyWith({
    double? currentLevel,
    double? warningLevel,
    double? dangerLevel,
    double? flowRate,
    double? rainfall24h,
    String? riskLevel,
    DateTime? lastUpdated,
    String? predictedSeverity,
    int? riskScore,
    double? confidencePercent,
    bool? willBreachDanger,
    double? peakLevel72h,
  }) =>
      LiveCityData(
        currentLevel: currentLevel ?? this.currentLevel,
        warningLevel: warningLevel ?? this.warningLevel,
        dangerLevel: dangerLevel ?? this.dangerLevel,
        flowRate: flowRate ?? this.flowRate,
        rainfall24h: rainfall24h ?? this.rainfall24h,
        riskLevel: riskLevel ?? this.riskLevel,
        lastUpdated: lastUpdated ?? this.lastUpdated,
        predictedSeverity: predictedSeverity ?? this.predictedSeverity,
        riskScore: riskScore ?? this.riskScore,
        confidencePercent: confidencePercent ?? this.confidencePercent,
        willBreachDanger: willBreachDanger ?? this.willBreachDanger,
        peakLevel72h: peakLevel72h ?? this.peakLevel72h,
      );

  FloodData toFloodData(String city, String state,
      {String? riverName, String district = ''}) {
    final level = currentLevel ?? 0.0;
    return FloodData(
      city: city,
      district: district,
      state: state,
      riverName: riverName,
      currentLevel: level,
      warningLevel: warningLevel,
      dangerLevel: dangerLevel,
      flowRate: flowRate,
      imdRainfallMm: rainfall24h,
      lastUpdated: lastUpdated,
      stationId: '',
      stationName: city,
      river: riverName ?? '',
      // v4.2 ML fields
      predictedSeverity: predictedSeverity,
      riskScore: riskScore,
      confidencePercent: confidencePercent,
      willBreachDanger: willBreachDanger,
      peakLevel72h: peakLevel72h,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LiveFetchEngine  (v4.2)
// ─────────────────────────────────────────────────────────────────────────────
class LiveFetchEngine {
  static const _cacheTtl = Duration(minutes: 5);
  static const _pollInterval = Duration(seconds: 30);

  static final List<Map<String, dynamic>> _allCities =
      List.unmodifiable(IndiaGeodata.monitoredCities);

  final _cbWrd = _CircuitBreaker();
  final _cbGlofas = _CircuitBreaker();
  final _cbRain = _CircuitBreaker();
  final _cbSev = _CircuitBreaker(); // circuit-breaker for severity endpoint

  final _wrdCache =
      VersionedDataCache<List<WrdStation>>(ttl: const Duration(minutes: 5));
  final _glofasCache = VersionedDataCache<List<Map<String, dynamic>>>(
      ttl: const Duration(minutes: 5));
  final _rainCache = VersionedDataCache<List<Map<String, dynamic>>>(
      ttl: const Duration(minutes: 5));
  final _sevCache = VersionedDataCache<Map<String, Map<String, dynamic>>>(
      ttl: const Duration(minutes: 5));

  final Map<String, LiveCityData> _cache = {};
  DateTime? _lastFetch;
  Timer? _pollTimer;
  bool _isLoading = false;
  bool _isOnline = true;
  bool _isWakingUp = false;
  bool _isUsingCache = false;
  String? _error;
  int _queuedOffline = 0;
  int _retryCount = 0;
  final int _wakeAttempts = 0;

  int _wrdLiveCount = 0;
  int _wrdDiskCount = 0;

  final SourceHealth _backendHealth = const SourceHealth.unknown();
  SourceHealth _glofasHealth = const SourceHealth.unknown();
  SourceHealth _imdHealth = const SourceHealth.unknown();
  SourceHealth _wrdHealth = const SourceHealth.unknown();
  SourceHealth _sevHealth = const SourceHealth.unknown();

  SourceHealth get _cwcHealth => _wrdHealth;

  void Function()? onStateChanged;

  // —— Lifecycle ——————————————————————————————————————————————————————————————
  Future<void> startPolling() async {
    if (_pollTimer != null) return;
    await refreshData();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _timerTick());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  // —— Status getters ————————————————————————————————————————————————————————
  bool get isLoading => _isLoading;
  bool get isOnline => _isOnline;
  bool get isUsingFallback => !_isOnline && _cache.isNotEmpty;
  bool get isWakingUp => _isWakingUp;
  bool get isUsingCache => _isUsingCache;
  DateTime? get lastFetchTime => _lastFetch;
  String? get error => _error;
  int get queuedOfflineCycles => _queuedOffline;
  int get debugRetryCount => _retryCount;
  int get debugWakeAttempts => _wakeAttempts;

  int get wrdLiveCount => _wrdLiveCount;
  int get wrdDiskCount => _wrdDiskCount;
  int get wrdTotalCount => _wrdLiveCount + _wrdDiskCount;

  // —— Source health getters —————————————————————————————————————————————————
  SourceHealth get backendHealth => _backendHealth;
  SourceHealth get glofasHealth => _glofasHealth;
  SourceHealth get imdHealth => _imdHealth;
  SourceHealth get wrdHealth => _wrdHealth;
  SourceHealth get cwcHealth => _cwcHealth;
  SourceHealth get severityHealth => _sevHealth;

  bool get backendHealthy => _backendHealth.healthy;
  bool get glofasHealthy => _glofasHealth.healthy;
  bool get imdHealthy => _imdHealth.healthy;
  bool get wrdHealthy => _wrdHealth.healthy;
  bool get cwcHealthy => _cwcHealth.healthy;
  bool get severityHealthy => _sevHealth.healthy;

  int? get backendLatencyMs => _backendHealth.latencyMs;
  int? get glofasLatencyMs => _glofasHealth.latencyMs;
  int? get imdLatencyMs => _imdHealth.latencyMs;
  int? get wrdLatencyMs => _wrdHealth.latencyMs;
  int? get cwcLatencyMs => _cwcHealth.latencyMs;
  int? get severityLatencyMs => _sevHealth.latencyMs;

  // —— Data getters ——————————————————————————————————————————————————————————
  List<LiveCityData?> get liveLevels => _cache.values.toList();

  List<FloodData> get liveFloodData {
    return _cache.entries.map((e) {
      final city = e.key;
      final data = e.value;
      final mc = _allCities.firstWhere(
        (c) => (c['city'] as String).toLowerCase() == city,
        orElse: () => {'city': city, 'district': '', 'state': 'Unknown'},
      );
      return data.toFloodData(
        mc['city'] as String,
        mc['state'] as String,
        riverName: mc['river'] as String?,
        district: (mc['district'] as String?) ?? '',
      );
    }).toList();
  }

  List<dynamic> get activeCriticalAlerts => _buildCriticalAlerts();
  List<dynamic> get criticalAlerts => _buildCriticalAlerts();
  int get criticalCount => _buildCriticalAlerts().length;

  List<dynamic> get cwcStations => liveFloodData;
  bool get hasCwcLiveData => _cache.isNotEmpty;

  MultiLocationMonitoring get monitoringData => MultiLocationMonitoring(
        locations: liveFloodData,
        lastUpdated: _lastFetch,
      );

  List<dynamic> get imdAlerts => const [];
  List<dynamic> get ndmaAdvisories => const [];
  List<dynamic> get emergencyContacts => const [];

  Map<String, dynamic> get debugLevelsRaw =>
      {for (final e in _cache.entries) e.key: e.value.toString()};
  Map<String, dynamic> get debugCwcRaw => {
        'totalCities': _allCities.length,
        'wrdLive': _wrdLiveCount,
        'wrdDisk': _wrdDiskCount,
        'cacheSize': _cache.length,
        'backend': BackendApiService.instance.baseUrl,
      };

  // —— Per-city helpers ——————————————————————————————————————————————————————
  LiveCityData? dataForCity(String city) {
    _maybeBackgroundRefresh();
    return _cache[city.toLowerCase().trim()];
  }

  FloodData? floodDataForCity(String city) {
    final d = dataForCity(city);
    if (d == null) return null;
    final mc = _allCities.firstWhere(
      (c) => (c['city'] as String).toLowerCase() == city.toLowerCase(),
      orElse: () => {'city': city, 'district': '', 'state': 'Unknown'},
    );
    return d.toFloodData(
      mc['city'] as String,
      mc['state'] as String,
      riverName: mc['river'] as String?,
      district: (mc['district'] as String?) ?? '',
    );
  }

  List<dynamic> imdAlertsForState(String state) => const [];
  List<dynamic> ndmaAdvisoriesForState(String state) => const [];
  List<dynamic> emergencyContactsForState(String state) => const [];
  List<dynamic> trendForCity(String city) =>
      StationTrendStore.instance.get(city);

  // —— Refresh ———————————————————————————————————————————————————————————————
  Future<void> refreshData() async {
    _isLoading = true;
    _notify();
    try {
      await SharedFetchCoordinator.instance.dedupe(
        'live_fetch_engine_all',
        _fetchAllCities,
      );
      _isOnline = true;
      _isUsingCache = false;
      _error = null;
      _queuedOffline = 0;
    } catch (e) {
      _isOnline = false;
      _error = e.toString();
      _retryCount++;
      if (_cache.isNotEmpty) _isUsingCache = true;
      _log('refreshData error: $e');
    } finally {
      _isLoading = false;
      _isWakingUp = false;
      _notify();
    }
  }

  Future<void> _timerTick() async {
    if (_isLoading) return;
    if (!_isOnline) _queuedOffline++;
    await refreshData();
  }

  // —— Core fetch ————————————————————————————————————————————————————————————
  Future<void> _fetchAllCities() async {
    final allCities = _allCities;
    if (allCities.isEmpty) return;

    final lats = allCities.map((c) => (c['lat'] as num).toDouble()).toList();
    final lons = allCities.map((c) => (c['lon'] as num).toDouble()).toList();
    final cityKeys = allCities
        .map((c) => (c['city'] as String).toLowerCase().trim())
        .toList();

    // 1. WRD Bihar
    final wrdStart = DateTime.now();
    Map<String, WrdStation> wrdByKey = {};
    _wrdLiveCount = 0;
    _wrdDiskCount = 0;

    if (!_cbWrd.isOpen) {
      try {
        List<WrdStation> stations;
        if (_wrdCache.isStale) {
          stations = await SharedFetchCoordinator.instance.dedupe(
            'wrd_fetch',
            () => WrdBiharService.instance.fetch(),
          );
          _wrdCache.set(stations);
        } else {
          stations = _wrdCache.value!;
        }
        for (final s in stations) {
          final isLive =
              s.source.contains('LIVE') || s.source.contains('BACKEND');
          if (isLive)
            _wrdLiveCount++;
          else
            _wrdDiskCount++;
          wrdByKey[s.site.toLowerCase().trim()] = s;
          wrdByKey[s.district.toLowerCase().trim()] = s;
        }
        _cbWrd.recordSuccess();
        _wrdHealth = SourceHealth(
          healthy: stations.isNotEmpty,
          latencyMs: DateTime.now().difference(wrdStart).inMilliseconds,
          lastSuccessAt:
              _wrdLiveCount > 0 ? DateTime.now() : _wrdHealth.lastSuccessAt,
          lastError: _wrdLiveCount > 0
              ? null
              : stations.isNotEmpty
                  ? 'WRD disk-cache ($_wrdDiskCount stations)'
                  : 'WRD returned 0 stations',
        );
        _log(
            'WRD: ${stations.length} stations (live=$_wrdLiveCount disk=$_wrdDiskCount)');
      } catch (e) {
        _cbWrd.recordFailure();
        _wrdHealth = SourceHealth(
          healthy: false,
          latencyMs: DateTime.now().difference(wrdStart).inMilliseconds,
          lastSuccessAt: _wrdHealth.lastSuccessAt,
          lastError: e.toString(),
        );
        _log('WRD fetch failed: $e');
      }
    }

    // 2+3. GloFAS + Rainfall — run in parallel to halve latency
    var dischargeMap = <String, double?>{};
    var meanMap = <String, double?>{};
    var rainMap = <String, double?>{};
    final parallelStart = DateTime.now();

    await Future.wait([
      // ── GloFAS ──────────────────────────────────────────────────────────
      () async {
        if (_cbGlofas.isOpen) return;
        final t0 = DateTime.now();
        try {
          List<Map<String, dynamic>> rows;
          if (_glofasCache.isStale) {
            rows = await SharedFetchCoordinator.instance.dedupe(
              'glofas_fetch',
              () => BackendApiService.instance.fetchGloFAS(
                lats: lats,
                lons: lons,
                cityKeys: cityKeys,
              ),
            );
            _glofasCache.set(rows);
          } else {
            rows = _glofasCache.value!;
          }
          for (final r in rows) {
            final key = (r['city'] as String? ?? '').toLowerCase().trim();
            dischargeMap[key] = (r['discharge'] as num?)?.toDouble();
            meanMap[key] = (r['discharge_mean'] as num?)?.toDouble();
          }
          _cbGlofas.recordSuccess();
          _glofasHealth = SourceHealth(
            healthy: true,
            latencyMs: DateTime.now().difference(t0).inMilliseconds,
            lastSuccessAt: DateTime.now(),
          );
        } catch (e) {
          _cbGlofas.recordFailure();
          _glofasHealth = SourceHealth(
            healthy: false,
            latencyMs: DateTime.now().difference(t0).inMilliseconds,
            lastSuccessAt: _glofasHealth.lastSuccessAt,
            lastError: e.toString(),
          );
          _log('GloFAS fetch failed: $e');
        }
      }(),
      // ── Rainfall ────────────────────────────────────────────────────────
      () async {
        if (_cbRain.isOpen) return;
        final t0 = DateTime.now();
        try {
          List<Map<String, dynamic>> rows;
          if (_rainCache.isStale) {
            rows = await SharedFetchCoordinator.instance.dedupe(
              'rain_fetch',
              () => BackendApiService.instance.fetchRainfall(
                lats: lats,
                lons: lons,
                cityKeys: cityKeys,
              ),
            );
            _rainCache.set(rows);
          } else {
            rows = _rainCache.value!;
          }
          for (final r in rows) {
            final key = (r['city'] as String? ?? '').toLowerCase().trim();
            rainMap[key] = (r['rainfall24h'] as num?)?.toDouble();
          }
          _cbRain.recordSuccess();
          _imdHealth = SourceHealth(
            healthy: true,
            latencyMs: DateTime.now().difference(t0).inMilliseconds,
            lastSuccessAt: DateTime.now(),
          );
        } catch (e) {
          _cbRain.recordFailure();
          _imdHealth = SourceHealth(
            healthy: false,
            latencyMs: DateTime.now().difference(t0).inMilliseconds,
            lastSuccessAt: _imdHealth.lastSuccessAt,
            lastError: e.toString(),
          );
          _log('Rainfall fetch failed: $e');
        }
      }(),
    ]);
    _log(
        'GloFAS+Rainfall parallel: ${DateTime.now().difference(parallelStart).inMilliseconds}ms');

    // 4. Severity (GET /api/live-levels?with_severity=true)
    //    Returns backend ML predictions per city; merged into cache below.
    final sevStart = DateTime.now();
    Map<String, Map<String, dynamic>> sevByKey = {};

    if (!_cbSev.isOpen) {
      try {
        List<Map<String, dynamic>> sevRows;
        if (_sevCache.isStale) {
          sevRows = await SharedFetchCoordinator.instance.dedupe(
            'live_levels_sev',
            () => BackendApiService.instance.fetchLiveLevelsWithSeverity(),
          );
          // Build key map: normalised city name → record
          final Map<String, Map<String, dynamic>> built = {};
          for (final r in sevRows) {
            final k = (r['city'] as String? ?? '').toLowerCase().trim();
            if (k.isNotEmpty) built[k] = r;
          }
          _sevCache.set(built);
        }
        sevByKey = _sevCache.value ?? {};
        _cbSev.recordSuccess();
        _sevHealth = SourceHealth(
          healthy: true,
          latencyMs: DateTime.now().difference(sevStart).inMilliseconds,
          lastSuccessAt: DateTime.now(),
        );
        _log('Severity: ${sevByKey.length} cities enriched');
      } catch (e) {
        _cbSev.recordFailure();
        _sevHealth = SourceHealth(
          healthy: false,
          latencyMs: DateTime.now().difference(sevStart).inMilliseconds,
          lastSuccessAt: _sevHealth.lastSuccessAt,
          lastError: e.toString(),
        );
        _log('Severity fetch failed (non-fatal): $e');
      }
    }

    // 5. Assemble cache
    final now = DateTime.now();
    for (int i = 0; i < allCities.length; i++) {
      final mc = allCities[i];
      final cityName = mc['city'] as String;
      final dl = (mc['danger_level'] as num).toDouble();
      final wl = (mc['warning_level'] as num).toDouble();
      final key = cityName.toLowerCase().trim();

      final discharge = dischargeMap[key];
      final mean = meanMap[key];
      final rain = rainMap[key];
      final risk = _deriveGlofasRisk(discharge, mean);
      final estLevel = (discharge != null && mean != null && mean > 0 && dl > 0)
          ? (discharge / mean) * dl * 0.85
          : null;

      WrdStation? wrd = wrdByKey[key];
      if (wrd == null) {
        for (final word in key.split(RegExp(r'\s+'))) {
          if (word.length < 4) continue;
          wrd = wrdByKey[word];
          if (wrd != null) break;
          for (final s in (WrdBiharService.instance.cachedStations ?? [])) {
            if (s.site.toLowerCase().contains(word) ||
                s.district.toLowerCase().contains(word)) {
              wrd = s;
              break;
            }
          }
          if (wrd != null) break;
        }
      }

      // Merge ML severity fields from /api/live-levels
      final sev = sevByKey[key];
      final predictedSeverity = sev?['predicted_severity'] as String?;
      final riskScore = (sev?['risk_score'] as num?)?.toInt();
      final confidencePercent =
          (sev?['confidence_percent'] as num?)?.toDouble();
      final willBreachDanger = sev?['will_breach_danger'] as bool?;
      final peakLevel72h = (sev?['peak_level_72h'] as num?)?.toDouble();

      _cache[key] = LiveCityData(
        currentLevel: wrd?.currentLevel ?? estLevel,
        warningLevel: (wrd?.warningLevel != null && wrd!.warningLevel! > 0)
            ? wrd.warningLevel!
            : wl,
        dangerLevel: (wrd?.dangerLevel != null && wrd!.dangerLevel! > 0)
            ? wrd.dangerLevel!
            : dl,
        flowRate: discharge,
        rainfall24h: rain,
        riskLevel: _mergeRisk(wrd?.riskLabel, risk),
        lastUpdated: now,
        // v4.2 ML
        predictedSeverity: predictedSeverity,
        riskScore: riskScore,
        confidencePercent: confidencePercent,
        willBreachDanger: willBreachDanger,
        peakLevel72h: peakLevel72h,
      );

      // v4.1 trend store
      final lvl = _cache[key]!.currentLevel;
      if (lvl != null && lvl > 0) {
        StationTrendStore.instance.append(key, lvl, now);
      }
    }

    _lastFetch = now;
    _log('v4.2 cache updated — ${_cache.length} stations '
        '(wrd=${_wrdHealth.healthy} [live=$_wrdLiveCount disk=$_wrdDiskCount], '
        'glofas=${_glofasHealth.healthy}, '
        'rainfall=${_imdHealth.healthy}, '
        'severity=${_sevHealth.healthy})');
    _notify();
  }

  // —— Risk helpers ——————————————————————————————————————————————————————————
  String? _deriveGlofasRisk(double? discharge, double? mean) {
    if (discharge == null || mean == null || mean <= 0) return null;
    final ratio = discharge / mean;
    if (ratio >= 2.0) return 'CRITICAL';
    if (ratio >= 1.5) return 'SEVERE';
    if (ratio >= 1.0) return 'MODERATE';
    return 'LOW';
  }

  String? _mergeRisk(String? wrd, String? glofas) {
    const severity = {
      'CRITICAL': 5,
      'HIGH': 4,
      'SEVERE': 4,
      'MODERATE': 3,
      'LOW': 2,
      'PRE-MONSOON': 1,
      'NA': 0,
    };
    if (wrd == null && glofas == null) return null;
    if (wrd == null) return glofas;
    if (glofas == null) return wrd;
    final ws = severity[wrd.toUpperCase()] ?? 0;
    final gs = severity[glofas.toUpperCase()] ?? 0;
    final winner = ws >= gs ? wrd : glofas;
    return winner == 'HIGH' ? 'SEVERE' : winner;
  }

  List<Map<String, dynamic>> _buildCriticalAlerts() {
    return _cache.entries
        .where((e) =>
            e.value.riskLevel == 'CRITICAL' ||
            e.value.riskLevel == 'SEVERE' ||
            e.value.predictedSeverity == 'CRITICAL' ||
            e.value.predictedSeverity == 'SEVERE')
        .map((e) => {
              'city': e.key,
              'riskLevel': e.value.riskLevel,
              'level': e.value.currentLevel,
              // v4.2 ML fields
              'predictedSeverity': e.value.predictedSeverity,
              'riskScore': e.value.riskScore,
              'confidencePercent': e.value.confidencePercent,
              'willBreachDanger': e.value.willBreachDanger,
              'peakLevel72h': e.value.peakLevel72h,
            })
        .toList();
  }

  void _maybeBackgroundRefresh() {
    if (_lastFetch == null ||
        DateTime.now().difference(_lastFetch!) > _cacheTtl) {
      refreshData().catchError((Object e) => _log('bg refresh error: $e'));
    }
  }

  void _notify() => onStateChanged?.call();
  void _log(String msg) {
    if (kDebugMode) debugPrint('[LiveFetchEngine v4.2] $msg');
  }
}
