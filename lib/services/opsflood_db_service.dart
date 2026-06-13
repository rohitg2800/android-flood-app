// lib/services/opsflood_db_service.dart
// OpsFlood — Database Service v2.2
// Fix: AppConfig ep* are getters, not consts — changed all `const path =` to `final path =`
library;

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'local_cache_service.dart';
import 'ops_client.dart';

String _str(dynamic v) => (v?.toString() ?? '').trim();
double _dbl(dynamic v) {
  if (v == null) return 0.0;
  if (v is num)  return v.toDouble();
  return double.tryParse(v.toString().trim()) ?? 0.0;
}
double? _dblOpt(dynamic v) => v == null ? null : _dbl(v);
DateTime _dt(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is Timestamp) return v.toDate();
  if (v is DateTime)  return v;
  return DateTime.tryParse(v.toString()) ?? DateTime.now();
}

class _CacheResult {
  final String? value;
  final bool isStale;
  const _CacheResult(this.value) : isStale = false;
}

class DbStation {
  final String city, state, river, cwcStationId;
  final double lat, lon, warningLevel, dangerLevel, hfl;
  const DbStation({
    required this.city, required this.state, required this.river,
    required this.lat, required this.lon, required this.warningLevel,
    required this.dangerLevel, required this.hfl, required this.cwcStationId,
  });
  factory DbStation.fromMap(Map<String, dynamic> m) => DbStation(
    city:         _str(m['city'] ?? m['name'] ?? ''),
    state:        _str(m['state'] ?? ''),
    river:        _str(m['river'] ?? ''),
    lat:          _dbl(m['lat'] ?? m['latitude'] ?? 0),
    lon:          _dbl(m['lon'] ?? m['longitude'] ?? 0),
    warningLevel: _dbl(m['warning_level'] ?? m['warning'] ?? 0),
    dangerLevel:  _dbl(m['danger_level']  ?? m['danger']  ?? 0),
    hfl:          _dbl(m['hfl'] ?? 0),
    cwcStationId: _str(m['cwc_station_id'] ?? m['station_id'] ?? ''),
  );
  Map<String, dynamic> toMap() => {
    'city': city, 'state': state, 'river': river, 'lat': lat, 'lon': lon,
    'warning_level': warningLevel, 'danger_level': dangerLevel,
    'hfl': hfl, 'cwc_station_id': cwcStationId,
  };
}

class DbReading {
  final String city, source;
  final double level;
  final double? discharge, rainfall;
  final DateTime timestamp;
  final bool isStale;
  const DbReading({
    required this.city, required this.level, this.discharge, this.rainfall,
    required this.source, required this.timestamp, this.isStale = false,
  });
  factory DbReading.fromMap(Map<String, dynamic> m) => DbReading(
    city:      _str(m['city'] ?? ''),
    level:     _dbl(m['level'] ?? m['water_level'] ?? m['gauge'] ?? 0),
    discharge: _dblOpt(m['discharge'] ?? m['flow_rate']),
    rainfall:  _dblOpt(m['rainfall'] ?? m['rainfall_last_hour']),
    source:    _str(m['source'] ?? 'UNKNOWN'),
    timestamp: _dt(m['timestamp'] ?? m['observed_at']),
    isStale:   m['is_stale'] == true,
  );
  Map<String, dynamic> toFirestore() => {
    'city': city, 'level': level, 'discharge': discharge,
    'rainfall': rainfall, 'source': source,
    'timestamp': Timestamp.fromDate(timestamp), 'is_stale': isStale,
  };
}

class DbAlert {
  final String city, state, river, level, trend;
  final double currentValue, threshold;
  final DateTime timestamp;
  final bool isNew;
  const DbAlert({
    required this.city, required this.state, required this.river,
    required this.level, required this.currentValue, required this.threshold,
    required this.trend, required this.timestamp, required this.isNew,
  });
  factory DbAlert.fromMap(Map<String, dynamic> m) => DbAlert(
    city:         _str(m['city'] ?? m['city_name'] ?? ''),
    state:        _str(m['state'] ?? ''),
    river:        _str(m['river'] ?? ''),
    level:        _str(m['level'] ?? m['alert_level'] ?? 'WARNING'),
    currentValue: _dbl(m['current_value'] ?? m['discharge'] ?? 0),
    threshold:    _dbl(m['threshold'] ?? m['danger_level'] ?? 0),
    trend:        _str(m['trend'] ?? 'STEADY'),
    timestamp:    _dt(m['timestamp'] ?? m['detected_at']),
    isNew:        m['is_new'] == true,
  );
  Map<String, dynamic> toFirestore() => {
    'city': city, 'state': state, 'river': river, 'level': level,
    'current_value': currentValue, 'threshold': threshold, 'trend': trend,
    'timestamp': Timestamp.fromDate(timestamp), 'is_new': isNew,
  };
}

class DbPrediction {
  final String city, riskLevel, forecastHorizon;
  final double floodProbability, confidence;
  final DateTime generatedAt;
  const DbPrediction({
    required this.city, required this.floodProbability, required this.riskLevel,
    required this.forecastHorizon, required this.confidence, required this.generatedAt,
  });
  factory DbPrediction.fromMap(Map<String, dynamic> m) => DbPrediction(
    city:             _str(m['city'] ?? ''),
    floodProbability: _dbl(m['flood_probability'] ?? m['prob'] ?? 0),
    riskLevel:        _str(m['risk_level'] ?? 'SAFE'),
    forecastHorizon:  _str(m['forecast_horizon'] ?? '24h'),
    confidence:       _dbl(m['confidence'] ?? 0),
    generatedAt:      _dt(m['generated_at'] ?? m['timestamp']),
  );
  Map<String, dynamic> toFirestore() => {
    'city': city, 'flood_probability': floodProbability, 'risk_level': riskLevel,
    'forecast_horizon': forecastHorizon, 'confidence': confidence,
    'generated_at': Timestamp.fromDate(generatedAt),
  };
}

class DbResult<T> {
  final List<T> data;
  final bool fromCache, isStale;
  final String? error;
  const DbResult({required this.data, this.fromCache = false, this.isStale = false, this.error});
  bool get isOk => error == null;
}

class OpsFloodDbService {
  OpsFloodDbService._();
  static final OpsFloodDbService instance = OpsFloodDbService._();

  final _client = OpsClient.instance;
  final _cache  = LocalCacheService.instance;

  FirebaseFirestore? get _fs {
    try { return FirebaseFirestore.instance; } catch (_) { return null; }
  }

  static final String _prefix =
      const String.fromEnvironment('DB_COLLECTION_PREFIX', defaultValue: '');

  String _col(String name) =>
      _prefix.isEmpty ? name : '${_prefix}_$name';

  Future<_CacheResult> _readCache(String key) async {
    final value = _cache.getString(key);
    return _CacheResult(value);
  }

  // ── STATIONS ───────────────────────────────────────────────────────────────
  Future<DbResult<DbStation>> getStations() async {
    final path = AppConfig.epCwcStations;
    final raw  = await _client.get(path);
    if (_isOk(raw)) {
      final list   = _asList(raw);
      final result = list.map(DbStation.fromMap).toList();
      await _cache.setString(path, jsonEncode(list));
      _mirrorStations(result);
      return DbResult(data: result);
    }
    final cached = await _readCache(path);
    if (cached.value != null) {
      final list = (jsonDecode(cached.value!) as List).cast<Map<String, dynamic>>();
      return DbResult(data: list.map(DbStation.fromMap).toList(), fromCache: true, isStale: cached.isStale);
    }
    final fs = _fs;
    if (fs != null) {
      try {
        final snap = await fs.collection(_col('station_registry')).limit(200).get();
        final result = snap.docs.map((d) => DbStation.fromMap(d.data())).toList();
        if (result.isNotEmpty) return DbResult(data: result, fromCache: true, isStale: true);
      } catch (e) { _log('Firestore station fallback: $e'); }
    }
    return DbResult(data: const [], error: raw['error']?.toString());
  }

  // ── LIVE READINGS ──────────────────────────────────────────────────────────
  Future<DbResult<DbReading>> getAllReadings() async {
    final path = AppConfig.epLiveTelemetry;
    final raw  = await _client.get(path);
    if (_isOk(raw)) {
      final list   = _asList(raw);
      final result = list.map(DbReading.fromMap).toList();
      await _cache.setString(path, jsonEncode(list));
      _mirrorReadings(result);
      return DbResult(data: result);
    }
    final cached = await _readCache(path);
    if (cached.value != null) {
      final list = (jsonDecode(cached.value!) as List).cast<Map<String, dynamic>>();
      return DbResult(data: list.map(DbReading.fromMap).toList(), fromCache: true, isStale: cached.isStale);
    }
    return DbResult(data: const [], error: raw['error']?.toString());
  }

  Future<DbResult<DbReading>> getCityReadings(String city) async {
    final path = AppConfig.epLiveTelemetry;
    final cacheKey = '$path?city=${Uri.encodeComponent(city)}';
    final raw  = await _client.get(cacheKey);
    if (_isOk(raw)) {
      final list   = _asList(raw);
      final result = list.map(DbReading.fromMap).toList();
      await _cache.setString(cacheKey, jsonEncode(list));
      _mirrorReadings(result);
      return DbResult(data: result);
    }
    final cached = await _readCache(cacheKey);
    if (cached.value != null) {
      final list = (jsonDecode(cached.value!) as List).cast<Map<String, dynamic>>();
      return DbResult(data: list.map(DbReading.fromMap).toList(), fromCache: true, isStale: cached.isStale);
    }
    return DbResult(data: const [], error: raw['error']?.toString());
  }

  // ── CRITICAL ALERTS ────────────────────────────────────────────────────────
  Future<DbResult<DbAlert>> getCriticalAlerts() async {
    final path = AppConfig.epCriticalAlerts;
    final raw  = await _client.get(path);
    if (_isOk(raw)) {
      final list   = _asList(raw);
      final result = list.map(DbAlert.fromMap).toList();
      await _cache.setString(path, jsonEncode(list));
      _mirrorAlerts(result);
      return DbResult(data: result);
    }
    final cached = await _readCache(path);
    if (cached.value != null) {
      final list = (jsonDecode(cached.value!) as List).cast<Map<String, dynamic>>();
      return DbResult(data: list.map(DbAlert.fromMap).toList(), fromCache: true, isStale: cached.isStale);
    }
    return DbResult(data: const [], error: raw['error']?.toString());
  }

  // ── PREDICTIONS ────────────────────────────────────────────────────────────
  Future<DbResult<DbPrediction>> getPredictions({String? city}) async {
    final path = AppConfig.epPredict;
    final Map<String, dynamic> body = {if (city != null) 'city': city};
    final raw = await _client.post(path, body);
    if (_isOk(raw)) {
      final obj = raw.containsKey('data') && raw['data'] is Map
          ? raw['data'] as Map<String, dynamic> : raw;
      final result = DbPrediction.fromMap({...obj, if (city != null) 'city': city});
      if (city != null) {
        await _cache.setString('$path?city=${Uri.encodeComponent(city)}', jsonEncode([obj]));
      }
      _mirrorPrediction(result);
      return DbResult(data: [result]);
    }
    return DbResult(data: const [], error: raw['error']?.toString());
  }

  // ── Admin helpers ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> fetchPipelineManifest() async {
    final raw = await _client.get(AppConfig.epPipelineManifest);
    return _isOk(raw) ? raw : {};
  }

  Future<Map<String, dynamic>> fetchStateSeverity() async {
    final path = AppConfig.epStateSeverity;
    final raw  = await _client.get(path);
    if (_isOk(raw)) {
      await _cache.setString(path, jsonEncode(raw));
      return raw;
    }
    final cached = await _readCache(path);
    if (cached.value != null) return jsonDecode(cached.value!) as Map<String, dynamic>;
    return {};
  }

  // ── Firestore mirror helpers ───────────────────────────────────────────────
  void _mirrorStations(List<DbStation> stations) {
    final fs = _fs; if (fs == null) return;
    final col = fs.collection(_col('station_registry'));
    for (final s in stations) {
      if (s.city.isEmpty) continue;
      col.doc(s.city.toLowerCase().replaceAll(' ', '_'))
          .set(s.toMap(), SetOptions(merge: true))
          .catchError((e) => _log('Firestore station write: $e'));
    }
  }

  void _mirrorReadings(List<DbReading> readings) {
    final fs = _fs; if (fs == null) return;
    final col = fs.collection(_col('flood_readings'));
    for (final r in readings) {
      if (r.city.isEmpty || r.isStale) continue;
      final docId = '${r.city.toLowerCase().replaceAll(' ', '_')}_'
          '${r.timestamp.toUtc().toIso8601String().replaceAll(':', '').replaceAll('.', '_').substring(0, 15)}';
      col.doc(docId).set(r.toFirestore(), SetOptions(merge: true))
          .catchError((e) => _log('Firestore reading write: $e'));
    }
  }

  void _mirrorAlerts(List<DbAlert> alerts) {
    final fs = _fs; if (fs == null) return;
    final col = fs.collection(_col('alert_events'));
    for (final a in alerts) {
      if (a.city.isEmpty) continue;
      final docId = '${a.city.toLowerCase().replaceAll(' ', '_')}_${a.timestamp.millisecondsSinceEpoch}';
      col.doc(docId).set(a.toFirestore(), SetOptions(merge: true))
          .catchError((e) => _log('Firestore alert write: $e'));
    }
  }

  void _mirrorPrediction(DbPrediction p) {
    final fs = _fs; if (fs == null) return;
    final col = fs.collection(_col('predictions'));
    final docId = '${p.city.toLowerCase().replaceAll(' ', '_')}_${p.generatedAt.toUtc().toIso8601String().substring(0, 10)}';
    col.doc(docId).set(p.toFirestore(), SetOptions(merge: true))
        .catchError((e) => _log('Firestore prediction write: $e'));
  }

  bool _isOk(Map<String, dynamic> raw) =>
      raw['status'] != 'error' && raw['error'] == null;

  List<Map<String, dynamic>> _asList(Map<String, dynamic> raw) {
    final d = raw['data'] ?? raw['results'] ?? raw['stations'] ?? raw;
    if (d is List) return d.whereType<Map<String, dynamic>>().toList();
    if (d is Map<String, dynamic>) return [d];
    return [];
  }

  void _log(String msg) => debugPrint('[OpsFloodDb] $msg');
}
