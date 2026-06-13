// lib/services/live_fetch_engine.dart  (v4.1 — TrendCard wired)
//
// v4.0 → v4.1 changes:
//   • StationTrendStore.instance.append() called at end of _fetchAllCities()
//     for every city that has a non-zero currentLevel in _cache.
//   • trendForCity() now delegates to StationTrendStore.instance.get(city)
//     instead of returning const [].
//   All other logic is unchanged from v4.0.

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
  static const int    _threshold   = 5;
  static const Duration _halfOpenAfter = Duration(seconds: 30);

  int       _failures  = 0;
  bool      _open      = false;
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
    _open     = false;
    _openedAt = null;
  }

  void recordFailure() {
    _failures++;
    if (_failures >= _threshold) {
      _open     = true;
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
  T?        _value;
  DateTime? _fetchedAt;
  String?   _etag;

  VersionedDataCache({required this.ttl});

  bool get isStale =>
      _fetchedAt == null ||
      DateTime.now().difference(_fetchedAt!) >= ttl;

  T? get value => _value;
  String? get etag => _etag;

  void set(T value, {String? etag}) {
    _value     = value;
    _fetchedAt = DateTime.now();
    _etag      = etag;
  }

  void invalidate() {
    _fetchedAt = null;
    _value     = null;
    _etag      = null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SourceHealth
// ─────────────────────────────────────────────────────────────────────────────
class SourceHealth {
  final bool      healthy;
  final int?      latencyMs;
  final DateTime? lastSuccessAt;
  final String?   lastError;

  const SourceHealth({
    required this.healthy,
    this.latencyMs,
    this.lastSuccessAt,
    this.lastError,
  });

  const SourceHealth.unknown()
      : healthy       = false,
        latencyMs     = null,
        lastSuccessAt = null,
        lastError     = null;

  SourceHealth copyWith({
    bool?     healthy,
    int?      latencyMs,
    DateTime? lastSuccessAt,
    String?   lastError,
  }) =>
      SourceHealth(
        healthy:       healthy       ?? this.healthy,
        latencyMs:     latencyMs     ?? this.latencyMs,
        lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
        lastError:     lastError     ?? this.lastError,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// LiveCityData
// ─────────────────────────────────────────────────────────────────────────────
class LiveCityData {
  final double?   currentLevel;
  final double    warningLevel;
  final double    dangerLevel;
  final double?   flowRate;
  final double?   rainfall24h;
  final String?   riskLevel;
  final DateTime  lastUpdated;

  const LiveCityData({
    this.currentLevel,
    required this.warningLevel,
    required this.dangerLevel,
    this.flowRate,
    this.rainfall24h,
    this.riskLevel,
    required this.lastUpdated,
  });

  @override
  String toString() =>
      'LiveCityData(flow=$flowRate m\u00b3/s, risk=$riskLevel, '
      'rain=${rainfall24h}mm, level=$currentLevel m)';

  LiveCityData copyWith({
    double?   currentLevel,
    double?   warningLevel,
    double?   dangerLevel,
    double?   flowRate,
    double?   rainfall24h,
    String?   riskLevel,
    DateTime? lastUpdated,
  }) =>
      LiveCityData(
        currentLevel: currentLevel ?? this.currentLevel,
        warningLevel: warningLevel ?? this.warningLevel,
        dangerLevel:  dangerLevel  ?? this.dangerLevel,
        flowRate:     flowRate     ?? this.flowRate,
        rainfall24h:  rainfall24h  ?? this.rainfall24h,
        riskLevel:    riskLevel    ?? this.riskLevel,
        lastUpdated:  lastUpdated  ?? this.lastUpdated,
      );

  FloodData toFloodData(String city, String state,
      {String? riverName, String district = ''}) {
    final level  = currentLevel ?? 0.0;
    final capPct = dangerLevel > 0
        ? (level / dangerLevel * 100).clamp(0.0, 150.0)
        : 0.0;
    return FloodData(
      city:                city,
      district:            district,
      state:               state,
      riverName:           riverName,
      currentLevel:        level,
      warningLevel:        warningLevel,
      dangerLevel:         dangerLevel,
      riskLevel:           riskLevel ?? 'LOW',
      status:              'LIVE',
      effectiveRainfallMm: rainfall24h ?? 0.0,
      flowRate:            flowRate,
      lastUpdated:         lastUpdated,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LiveFetchEngine  (v4.1)
// ─────────────────────────────────────────────────────────────────────────────
class LiveFetchEngine {
  static const _cacheTtl     = Duration(minutes: 5);
  static const _pollInterval = Duration(seconds: 30);

  static final List<Map<String, dynamic>> _allCities =
      List.unmodifiable(IndiaGeodata.monitoredCities);

  final _cbWrd     = _CircuitBreaker();
  final _cbGlofas  = _CircuitBreaker();
  final _cbRain    = _CircuitBreaker();

  final _wrdCache    = VersionedDataCache<List<WrdStation>>(ttl: const Duration(minutes: 5));
  final _glofasCache = VersionedDataCache<List<Map<String, dynamic>>>(ttl: const Duration(minutes: 5));
  final _rainCache   = VersionedDataCache<List<Map<String, dynamic>>>(ttl: const Duration(minutes: 5));

  final Map<String, LiveCityData> _cache = {};
  DateTime?  _lastFetch;
  Timer?     _pollTimer;
  bool       _isLoading    = false;
  bool       _isOnline     = true;
  bool       _isWakingUp   = false;
  bool       _isUsingCache = false;
  String?    _error;
  int        _queuedOffline = 0;
  int        _retryCount    = 0;
  int        _wakeAttempts  = 0;

  int _wrdLiveCount = 0;
  int _wrdDiskCount = 0;

  SourceHealth _backendHealth = const SourceHealth.unknown();
  SourceHealth _glofasHealth  = const SourceHealth.unknown();
  SourceHealth _imdHealth     = const SourceHealth.unknown();
  SourceHealth _wrdHealth     = const SourceHealth.unknown();

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
  bool      get isLoading           => _isLoading;
  bool      get isOnline            => _isOnline;
  bool      get isUsingFallback     => !_isOnline && _cache.isNotEmpty;
  bool      get isWakingUp          => _isWakingUp;
  bool      get isUsingCache        => _isUsingCache;
  DateTime? get lastFetchTime       => _lastFetch;
  String?   get error               => _error;
  int       get queuedOfflineCycles => _queuedOffline;
  int       get debugRetryCount     => _retryCount;
  int       get debugWakeAttempts   => _wakeAttempts;

  int get wrdLiveCount  => _wrdLiveCount;
  int get wrdDiskCount  => _wrdDiskCount;
  int get wrdTotalCount => _wrdLiveCount + _wrdDiskCount;

  // —— Source health getters —————————————————————————————————————————————————
  SourceHealth get backendHealth => _backendHealth;
  SourceHealth get glofasHealth  => _glofasHealth;
  SourceHealth get imdHealth     => _imdHealth;
  SourceHealth get wrdHealth     => _wrdHealth;
  SourceHealth get cwcHealth     => _cwcHealth;

  bool get backendHealthy => _backendHealth.healthy;
  bool get glofasHealthy  => _glofasHealth.healthy;
  bool get imdHealthy     => _imdHealth.healthy;
  bool get wrdHealthy     => _wrdHealth.healthy;
  bool get cwcHealthy     => _cwcHealth.healthy;

  int? get backendLatencyMs => _backendHealth.latencyMs;
  int? get glofasLatencyMs  => _glofasHealth.latencyMs;
  int? get imdLatencyMs     => _imdHealth.latencyMs;
  int? get wrdLatencyMs     => _wrdHealth.latencyMs;
  int? get cwcLatencyMs     => _cwcHealth.latencyMs;

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
        mc['city']    as String,
        mc['state']   as String,
        riverName: mc['river']    as String?,
        district: (mc['district'] as String?) ?? '',
      );
    }).toList();
  }

  List<dynamic> get activeCriticalAlerts => _buildCriticalAlerts();
  List<dynamic> get criticalAlerts       => _buildCriticalAlerts();
  int           get criticalCount        => _buildCriticalAlerts().length;

  List<dynamic> get cwcStations    => liveFloodData;
  bool          get hasCwcLiveData => _cache.isNotEmpty;

  MultiLocationMonitoring get monitoringData => MultiLocationMonitoring(
    locations:   liveFloodData,
    lastUpdated: _lastFetch,
  );

  List<dynamic> get imdAlerts         => const [];
  List<dynamic> get ndmaAdvisories    => const [];
  List<dynamic> get emergencyContacts => const [];

  Map<String, dynamic> get debugLevelsRaw => {
    for (final e in _cache.entries) e.key: e.value.toString()
  };
  Map<String, dynamic> get debugCwcRaw => {
    'totalCities': _allCities.length,
    'wrdLive':     _wrdLiveCount,
    'wrdDisk':     _wrdDiskCount,
    'cacheSize':   _cache.length,
    'backend':     BackendApiService.instance.baseUrl,
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
      mc['city']    as String,
      mc['state']   as String,
      riverName: mc['river']    as String?,
      district: (mc['district'] as String?) ?? '',
    );
  }

  List<dynamic> imdAlertsForState(String state)         => const [];
  List<dynamic> ndmaAdvisoriesForState(String state)    => const [];
  List<dynamic> emergencyContactsForState(String state) => const [];
  List<dynamic> trendForCity(String city)               =>
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
      _isOnline      = true;
      _isUsingCache  = false;
      _error         = null;
      _queuedOffline = 0;
    } catch (e) {
      _isOnline = false;
      _error    = e.toString();
      _retryCount++;
      if (_cache.isNotEmpty) _isUsingCache = true;
      _log('refreshData error: $e');
    } finally {
      _isLoading  = false;
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

    final lats     = allCities.map((c) => (c['lat']  as num).toDouble()).toList();
    final lons     = allCities.map((c) => (c['lon']  as num).toDouble()).toList();
    final cityKeys = allCities.map((c) => (c['city'] as String).toLowerCase().trim()).toList();

    // 1. WRD Bihar gauge readings
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
          final isLive = s.source.contains('LIVE') || s.source.contains('BACKEND');
          if (isLive) _wrdLiveCount++; else _wrdDiskCount++;
          wrdByKey[s.site.toLowerCase().trim()]     = s;
          wrdByKey[s.district.toLowerCase().trim()] = s;
        }
        _cbWrd.recordSuccess();
        _wrdHealth = SourceHealth(
          healthy:       stations.isNotEmpty,
          latencyMs:     DateTime.now().difference(wrdStart).inMilliseconds,
          lastSuccessAt: _wrdLiveCount > 0 ? DateTime.now() : _wrdHealth.lastSuccessAt,
          lastError:     _wrdLiveCount > 0
              ? null
              : stations.isNotEmpty
                  ? 'WRD disk-cache (${_wrdDiskCount} stations)'
                  : 'WRD returned 0 stations',
        );
        _log('WRD: ${stations.length} stations (live=$_wrdLiveCount disk=$_wrdDiskCount)');
      } catch (e) {
        _cbWrd.recordFailure();
        _wrdHealth = SourceHealth(
          healthy:       false,
          latencyMs:     DateTime.now().difference(wrdStart).inMilliseconds,
          lastSuccessAt: _wrdHealth.lastSuccessAt,
          lastError:     e.toString(),
        );
        _log('WRD fetch failed: $e');
      }
    } else {
      _log('WRD circuit-breaker OPEN — skipping');
    }

    // 2. GloFAS
    var dischargeMap = <String, double?>{};
    var meanMap      = <String, double?>{};
    final glofasStart = DateTime.now();

    if (!_cbGlofas.isOpen) {
      try {
        List<Map<String, dynamic>> rows;
        if (_glofasCache.isStale) {
          rows = await SharedFetchCoordinator.instance.dedupe(
            'glofas_fetch',
            () => BackendApiService.instance.fetchGloFAS(
              lats: lats, lons: lons, cityKeys: cityKeys,
            ),
          );
          _glofasCache.set(rows);
        } else {
          rows = _glofasCache.value!;
        }
        for (final r in rows) {
          final key = (r['city'] as String? ?? '').toLowerCase().trim();
          dischargeMap[key] = (r['discharge']      as num?)?.toDouble();
          meanMap[key]      = (r['discharge_mean'] as num?)?.toDouble();
        }
        _cbGlofas.recordSuccess();
        _glofasHealth = SourceHealth(
          healthy:       true,
          latencyMs:     DateTime.now().difference(glofasStart).inMilliseconds,
          lastSuccessAt: DateTime.now(),
        );
      } catch (e) {
        _cbGlofas.recordFailure();
        _glofasHealth = SourceHealth(
          healthy:       false,
          latencyMs:     DateTime.now().difference(glofasStart).inMilliseconds,
          lastSuccessAt: _glofasHealth.lastSuccessAt,
          lastError:     e.toString(),
        );
        _log('GloFAS fetch failed: $e');
      }
    } else {
      _log('GloFAS circuit-breaker OPEN — skipping');
    }

    // 3. Rainfall
    var rainMap = <String, double?>{};
    final imdStart = DateTime.now();

    if (!_cbRain.isOpen) {
      try {
        List<Map<String, dynamic>> rows;
        if (_rainCache.isStale) {
          rows = await SharedFetchCoordinator.instance.dedupe(
            'rain_fetch',
            () => BackendApiService.instance.fetchRainfall(
              lats: lats, lons: lons, cityKeys: cityKeys,
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
          healthy:       true,
          latencyMs:     DateTime.now().difference(imdStart).inMilliseconds,
          lastSuccessAt: DateTime.now(),
        );
      } catch (e) {
        _cbRain.recordFailure();
        _imdHealth = SourceHealth(
          healthy:       false,
          latencyMs:     DateTime.now().difference(imdStart).inMilliseconds,
          lastSuccessAt: _imdHealth.lastSuccessAt,
          lastError:     e.toString(),
        );
        _log('Rainfall fetch failed: $e');
      }
    } else {
      _log('Rainfall circuit-breaker OPEN — skipping');
    }

    // 4. Assemble cache
    final now = DateTime.now();
    for (int i = 0; i < allCities.length; i++) {
      final mc       = allCities[i];
      final cityName = mc['city']           as String;
      final dl       = (mc['danger_level']  as num).toDouble();
      final wl       = (mc['warning_level'] as num).toDouble();
      final key      = cityName.toLowerCase().trim();

      final discharge = dischargeMap[key];
      final mean      = meanMap[key];
      final rain      = rainMap[key];
      final risk      = _deriveGlofasRisk(discharge, mean);
      final estLevel  = (discharge != null && mean != null && mean > 0 && dl > 0)
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

      _cache[key] = LiveCityData(
        currentLevel: wrd?.currentLevel ?? estLevel,
        warningLevel: (wrd?.warningLevel != null && wrd!.warningLevel! > 0)
            ? wrd.warningLevel! : wl,
        dangerLevel:  (wrd?.dangerLevel != null && wrd!.dangerLevel! > 0)
            ? wrd.dangerLevel!  : dl,
        flowRate:     discharge,
        rainfall24h:  rain,
        riskLevel:    _mergeRisk(wrd?.riskLabel, risk),
        lastUpdated:  now,
      );

      // v4.1 — feed trend store with every non-zero reading
      final lvl = _cache[key]!.currentLevel;
      if (lvl != null && lvl > 0) {
        StationTrendStore.instance.append(key, lvl, now);
      }
    }

    _lastFetch = now;
    _log('v4.1 cache updated — ${_cache.length} stations across all states '
        '(wrd=${_wrdHealth.healthy} [live=$_wrdLiveCount disk=$_wrdDiskCount], '
        'glofas=${_glofasHealth.healthy}, '
        'rainfall=${_imdHealth.healthy})');
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
      'CRITICAL': 5, 'HIGH': 4, 'SEVERE': 4,
      'MODERATE': 3, 'LOW': 2, 'PRE-MONSOON': 1, 'NA': 0,
    };
    if (wrd == null && glofas == null) return null;
    if (wrd    == null) return glofas;
    if (glofas == null) return wrd;
    final ws = severity[wrd.toUpperCase()]    ?? 0;
    final gs = severity[glofas.toUpperCase()] ?? 0;
    final winner = ws >= gs ? wrd : glofas;
    return winner == 'HIGH' ? 'SEVERE' : winner;
  }

  List<Map<String, dynamic>> _buildCriticalAlerts() {
    return _cache.entries
        .where((e) =>
            e.value.riskLevel == 'CRITICAL' ||
            e.value.riskLevel == 'SEVERE')
        .map((e) => {
              'city':      e.key,
              'riskLevel': e.value.riskLevel,
              'level':     e.value.currentLevel,
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
    if (kDebugMode) debugPrint('[LiveFetchEngine v4.1] $msg');
  }
}